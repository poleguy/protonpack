/*
 * FT600 Asynchronous Write/Read Loopback Test
 * - Uses proper endpoint IDs (0x02 OUT, 0x82 IN)
 * - Thread-safe buffer passing
 * - Graceful shutdown and cleanup
 * - Detects driver/connection errors cleanly
 * Handles timeouts and aborts cleanly.
 *  Patch for safer overlapped usage, correct pipe IDs, and coordinated shutdown.
 * - Use readPipeId/writePipeId variables (no 0x00)
 * - Track initialized overlapped slots and only release them
 * - Main performs abort once after detecting fatalError
 * - Threads don't call abort_pipes() themselves
 * - ov arrays allocated on heap (avoid big stack frames)
 * Writes to hdf5
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <unistd.h>
#include <time.h>
#include <hdf5.h>   // ADD THIS near top with other includes
#include "ftd3xx.h"

#define MULTI_ASYNC_BUFFER_SIZE    32768//16384 //32768 //1048576 //32768  // 8388608 //   
#define MULTI_ASYNC_NUM           32

typedef struct {
    FT_HANDLE ftHandle;
    UCHAR *buffer;
    volatile int *exitFlag;
    volatile int *fatalError;
    UCHAR pipeId; /* per-thread pipe id to use */
    FILE *fp;
} ThreadArgs;

/* single ftHandle - main will abort pipes when needed */
FT_HANDLE ftHandle;
UCHAR writePipeId = 0x02; // OUT endpoint
UCHAR readPipeId  = 0x82; // IN endpoint

static void do_abort_pipes_once()
{
    /* Caller must ensure this is called only once (e.g. from main) */
    FT_AbortPipe(ftHandle, writePipeId);
    FT_AbortPipe(ftHandle, readPipeId);
}

/* ---------- HDF5 helper code ---------- */

typedef struct {
    hid_t file_id;
    hid_t dataset_id;
    hid_t dataspace_id;
    hsize_t current_size;
    hsize_t chunk_size;
    hsize_t dims[1];
} HDF5Context;

static HDF5Context* hdf5_init(const char *filename, size_t chunk_bytes)
{
    HDF5Context *ctx = calloc(1, sizeof(HDF5Context));
    ctx->chunk_size = chunk_bytes;
    ctx->current_size = 0;
    ctx->dims[0] = 0;

    // Create file (truncate if exists)
    ctx->file_id = H5Fcreate(filename, H5F_ACC_TRUNC, H5P_DEFAULT, H5P_DEFAULT);
    if (ctx->file_id < 0) {
        fprintf(stderr, "HDF5: failed to create file\n");
        free(ctx);
        return NULL;
    }

    // Create unlimited 1D dataset of bytes (uint8)
    hsize_t maxdims[1] = { H5S_UNLIMITED };
    hsize_t chunkdims[1] = { chunk_bytes };

    ctx->dataspace_id = H5Screate_simple(1, ctx->dims, maxdims);
    hid_t plist_id = H5Pcreate(H5P_DATASET_CREATE);
    H5Pset_chunk(plist_id, 1, chunkdims);
    ctx->dataset_id = H5Dcreate(ctx->file_id, "usb_data",
                                H5T_NATIVE_UCHAR, ctx->dataspace_id,
                                H5P_DEFAULT, plist_id, H5P_DEFAULT);
    H5Pclose(plist_id);
    return ctx;
}

static int hdf5_append_chunk(HDF5Context *ctx, const void *data, size_t nbytes)
{
    if (!ctx) return -1;
    hsize_t new_size = ctx->current_size + nbytes;

    // Extend dataset
    H5Dset_extent(ctx->dataset_id, &new_size);

    // Select hyperslab (append at end)
    hid_t filespace = H5Dget_space(ctx->dataset_id);
    hsize_t start[1] = { ctx->current_size };
    hsize_t count[1] = { nbytes };
    H5Sselect_hyperslab(filespace, H5S_SELECT_SET, start, NULL, count, NULL);

    // Memory space
    hid_t memspace = H5Screate_simple(1, count, NULL);

    // Write
    H5Dwrite(ctx->dataset_id, H5T_NATIVE_UCHAR, memspace, filespace,
             H5P_DEFAULT, data);

    H5Sclose(memspace);
    H5Sclose(filespace);

    ctx->current_size = new_size;
    return 0;
}

static void hdf5_close(HDF5Context *ctx)
{
    if (!ctx) return;
    H5Dclose(ctx->dataset_id);
    H5Sclose(ctx->dataspace_id);
    H5Fclose(ctx->file_id);
    free(ctx);
}
/* ---------- end HDF5 helper code ---------- */

static void* asyncRead(void *arg)
{
    ThreadArgs *args = (ThreadArgs *)arg;
    FT_HANDLE ft = args->ftHandle;
    UCHAR *buf = args->buffer;
    volatile int *exitReader = args->exitFlag;
    volatile int *fatalError = args->fatalError;
    UCHAR pipe = args->pipeId;
    FILE *fp = args->fp;

    FT_STATUS ftStatus = FT_OK;
    OVERLAPPED ov[MULTI_ASYNC_NUM] = {{0}};
    ULONG ulBytesRead[MULTI_ASYNC_NUM] = {0};
    size_t initialized = 0;
    ULONG ulBytesToRead = MULTI_ASYNC_BUFFER_SIZE;
    UCHAR expected[MULTI_ASYNC_BUFFER_SIZE];
    int received_ok = 0;

    printf("Starting asyncRead.\n");

    /* initialize only those we can */
    for (size_t j = 0; j < MULTI_ASYNC_NUM; j++) {
        ftStatus = FT_InitializeOverlapped(ft, &ov[j]);
        if (FT_FAILED(ftStatus)) {
            fprintf(stderr, "FT_InitializeOverlapped (read) failed at %zu: %d\n", j, ftStatus);
            /* stop initializing further entries; we'll release what we did initialize */
            *fatalError = 1;
            goto cleanup;
        }
        initialized++;
    }

    // measure time for bandwidth calculation
    clock_t begin = clock();
    
    while (!*exitReader && !*fatalError) {        
        //printf("while\n");
        for (size_t j = 0; j < MULTI_ASYNC_NUM && !*fatalError; j++) {
            /* fill buffer for this slot */
            memset(&buf[j * ulBytesToRead], (int)(0xAA + (j & 0xFF)), ulBytesToRead);
            // save a copy to check
            memset(&expected[0], (int)(0x5b + (j & 0xFF)), ulBytesToRead);
            ov[j].Internal = 0;
            ov[j].InternalHigh = 0;
            ulBytesRead[j] = 0;

            // undocumented, but in example
            //ftStatus = FT_SetStreamPipe(ft, FALSE, FALSE, 0x82, ulBytesToRead);
            ftStatus = FT_ReadPipeAsync(ft, 0x00,
                                        &buf[j * ulBytesToRead],
                                        ulBytesToRead,
                                        &ulBytesRead[j], &ov[j]);
            if (ftStatus != FT_IO_PENDING) {
                /* If device removed or pipe closed, mark fatal but keep cleanup sane */
                printf("[READ] FT_ReadPipeAsync failed: %d\n", ftStatus);
                *fatalError = 1;
                break;
            }

            if (*exitReader) {
                // this is an expected timeout if exit reader was set by the caller
                printf("[READ] Ending due to exit request before checking results.\n");
                break;
            }
            ftStatus = FT_GetOverlappedResult(ft, &ov[j],
                                              &ulBytesRead[j], TRUE);
            if (ftStatus == FT_TIMEOUT) {
                /* no data this time; try next */
                printf("[READ] Timeout waiting for data\n");
                continue;
            } else if (FT_FAILED(ftStatus)) {
                if (*exitReader) {
                    // this is an expected timeout if exit reader was set by the caller
                    printf("[READ] Ending due to exit request.\n");
                    break;
                }
                printf("[READ] GetOverlappedResult failed: %d\n", ftStatus);
                *fatalError = 1;
                break;
            } else {
                received_ok+=ulBytesRead[j];
            }

            /* Process data if needed (ulBytesRead[j]) */


            if (fp) {
                if (hdf5_append_chunk((HDF5Context*)fp, &buf[j * MULTI_ASYNC_BUFFER_SIZE], ulBytesRead[j]) < 0) {
                    fprintf(stderr, "Failed to write to HDF5 dataset\n");
                    *fatalError = 1;
                    break;
                }
            }


        }
    }

    // # https://stackoverflow.com/questions/5248915/execution-time-of-c-program
    clock_t end = clock();
    double time_spent = (double)(end - begin) / CLOCKS_PER_SEC;

cleanup:
    /* release only what was initialized */
    for (size_t j = 0; j < initialized; j++) {
        /* ensure any outstanding I/O for this overlapped is completed (non-blocking attempt) */
        FT_GetOverlappedResult(ft, &ov[j], &ulBytesRead[j], TRUE); /* wait to finish */
        FT_ReleaseOverlapped(ft, &ov[j]);
    }

    

    printf("received data: %d bytes\n", received_ok);
    printf("time spent : %f sec\n", time_spent);
    printf("rate : %f MBytes/sec\n", received_ok/time_spent/1000000);

    printf("Exiting %s\n", __FUNCTION__);
    return NULL;
}


static void *asyncWrite(void *arg) {
    ThreadArgs *args = (ThreadArgs *)arg;
    FT_HANDLE ft = args->ftHandle;
    UCHAR *buf = args->buffer;
    volatile int *exitWriter = args->exitFlag;
    volatile int *fatalError = args->fatalError;
    UCHAR pipe = args->pipeId;

    FT_STATUS ftStatus = FT_OK;
    OVERLAPPED ov[MULTI_ASYNC_NUM] = {{0}};
    ULONG ulBytesWritten[MULTI_ASYNC_NUM] = {0};
    size_t initialized = 0;
    ULONG ulBytesToWrite = MULTI_ASYNC_BUFFER_SIZE;
    printf("Starting %s\n", __FUNCTION__);



    memset(ov, 0, MULTI_ASYNC_NUM * sizeof(OVERLAPPED));

    for (size_t j = 0; j < MULTI_ASYNC_NUM; j++) {
        ftStatus = FT_InitializeOverlapped(ft, &ov[j]);
        if (FT_FAILED(ftStatus)) {
            fprintf(stderr, "FT_InitializeOverlapped (write) failed at %zu: %d\n", j, ftStatus);
            *fatalError = 1;
            goto cleanup;
        }
        initialized++;
    }

    while (!*exitWriter && !*fatalError) {
        for (size_t j = 0; j < initialized && !*fatalError && !*exitWriter; j++) {
            // printf's are probably going to slow this down insanely
            //printf("sending %x\n",(int)(0x55 + (j & 0xFF)));
            memset(&buf[j * ulBytesToWrite], (int)(0x55 + (j & 0xFF)), ulBytesToWrite);
            for (int k = 0; k < ulBytesToWrite;k+=16) {
                buf[j*ulBytesToWrite+k] = k & 0xff;
            }
            ov[j].Internal = 0;
            ov[j].InternalHigh = 0;        
            ulBytesWritten[j] = 0;

            // https://stackoverflow.com/questions/1157209/is-there-an-alternative-sleep-function-in-c-to-milliseconds
            struct timespec ts;
            ts.tv_sec = 0;
            ts.tv_nsec = 1 * 1000;
            // undocumented, but in example
            //ftStatus = FT_SetStreamPipe(ft, FALSE, FALSE, 0x02, ulBytesToWrite);
            //nanosleep(&ts, &ts); // crazy long sleep to get basic flow working
            ftStatus = FT_WritePipeAsync(ft, 0x00,
                                             &buf[j * ulBytesToWrite],
                                             ulBytesToWrite,
                                         &ulBytesWritten[j], &ov[j]);
            if (ftStatus != FT_IO_PENDING) {
                printf("[WRITE] FT_WritePipeAsync failed: %d\n", ftStatus);
                    *fatalError = 1;
                    break;
            }

            ftStatus = FT_GetOverlappedResult(ft, &ov[j],
                                              &ulBytesWritten[j], TRUE);
            if (ftStatus == FT_TIMEOUT) {
                if (*exitWriter) {
                    // this is an expected timeout if exit writer was set by the caller
                    printf("[WRITE] Ending due to exit request.\n");
                    break;
                }
                printf("[WRITE] Timeout waiting for write completion\n");
                continue; // not fatal
            } else if (FT_FAILED(ftStatus)) {
                printf("[WRITE] GetOverlappedResult failed: %d\n", ftStatus);
                *fatalError = 1;
                break;
            }
            }
        }

cleanup:
    for (size_t j = 0; j < initialized; j++) {
        FT_GetOverlappedResult(ft, &ov[j], &ulBytesWritten[j], TRUE);
        FT_ReleaseOverlapped(ft, &ov[j]);
    }

    printf("Exiting %s\n", __FUNCTION__);
    return NULL;
}

/* Main: create handle, start threads, monitor fatalError, do single abort+close, free buffers */
int main(void)
{
    volatile int exitReader = 0, exitWriter = 0, fatalError = 0;
    FT_STATUS ftStatus = FT_Create((PVOID)"FTDI SuperSpeed-FIFO Bridge",
                                   FT_OPEN_BY_DESCRIPTION, &ftHandle);
    if (FT_FAILED(ftStatus)) {
        printf("FT_Create failed: %d\n", ftStatus);
        return EXIT_FAILURE;
    }

    /* Set pipe timeouts */
    FT_SetPipeTimeout(ftHandle, writePipeId, 1000);
    FT_SetPipeTimeout(ftHandle, readPipeId, 1000);

    UCHAR *readBuf = calloc(MULTI_ASYNC_NUM * MULTI_ASYNC_BUFFER_SIZE, sizeof(UCHAR));
    if (!readBuf) {
        fprintf(stderr, "Read buffer allocation failed\n");
        FT_Close(ftHandle);
        return 1;
    }
    UCHAR *writeBuf = calloc(MULTI_ASYNC_NUM * MULTI_ASYNC_BUFFER_SIZE, sizeof(UCHAR));
    if (!writeBuf) {
        fprintf(stderr, "Write buffer allocation failed\n");
        FT_Close(ftHandle);
        free(readBuf);
        return 1;
    }

    HDF5Context *h5ctx = hdf5_init("loopback_async.h5", MULTI_ASYNC_BUFFER_SIZE);
    if (!h5ctx) {
        fprintf(stderr, "Failed to create HDF5 file\n");
        FT_Close(ftHandle);
        return 1;
    }


    ThreadArgs readArgs = { ftHandle, readBuf, &exitReader, &fatalError, readPipeId, (FILE *)h5ctx };
    ThreadArgs writeArgs = { ftHandle, writeBuf, &exitWriter, &fatalError, writePipeId, (FILE *)h5ctx };

    pthread_t rthr, wthr;
    pthread_create(&rthr, NULL, asyncRead, &readArgs);
    pthread_create(&wthr, NULL, asyncWrite, &writeArgs);

    /* Monitor loop: stop if fatalError set */
    // Alternate: Run for x seconds or until error
    for (int i = 0; i < 20 && !fatalError; i++) {

        // Alternate: run indefinitely
        // for (int i = 0; !fatalError; i++) {

        printf("Main loop second %d\n", i);
        sleep(1);
    }

    /* Coordinated shutdown: tell threads to exit, then abort pipes once, then join */
    exitWriter = 1;
    printf("exiting writer\n");
    sleep(1); // keep reading to flush buffers
    exitReader = 1;

    /* It's important to abort pipes *after* telling threads to exit so pending I/O wakes */
    do_abort_pipes_once();

    pthread_join(rthr, NULL);
    pthread_join(wthr, NULL);

    hdf5_close(h5ctx);

    FT_Close(ftHandle);
    free(readBuf);
    free(writeBuf);

    printf("Closed device and exited cleanly.\n");
    return 0;
}

