/*
 * FT600 Asynchronous Write/Read Loopback Test
 * - Uses proper endpoint IDs (0x02 OUT, 0x82 IN)
 * - Thread-safe buffer passing
 * - Graceful shutdown and cleanup
 * - Detects driver/connection errors cleanly
 * Handles timeouts and aborts cleanly.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <unistd.h>
#include "ftd3xx.h"

#define MULTI_ASYNC_BUFFER_SIZE    32768 //1048576 //32768  // 8388608 //   
#define MULTI_ASYNC_NUM          128

typedef struct {
    FT_HANDLE ftHandle;
    UCHAR *buffer;
    volatile int *exitFlag;
    volatile int *fatalError;
} ThreadArgs;

pthread_t writeThread, readThread;

FT_HANDLE ftHandle;
UCHAR writePipeId = 0x02; // OUT endpoint
UCHAR readPipeId  = 0x82; // IN endpoint

static void abort_pipes(void) {
    FT_AbortPipe(ftHandle, writePipeId);
    FT_AbortPipe(ftHandle, readPipeId);
}

static void* asyncRead(void *arg)
{
    ThreadArgs *args = (ThreadArgs *)arg;
    FT_HANDLE ftHandle = args->ftHandle;
    UCHAR *buf = args->buffer;
    volatile int *exitReader = args->exitFlag;
    volatile int *fatalError = args->fatalError;

    FT_STATUS ftStatus = FT_OK;
    OVERLAPPED ov[MULTI_ASYNC_NUM] = {{0}};
    ULONG ulBytesRead[MULTI_ASYNC_NUM] = {0};
    ULONG ulBytesToRead = MULTI_ASYNC_BUFFER_SIZE;

    printf("Starting asyncRead.\n");
    printf("Starting %s\n", __FUNCTION__);

    // Initialize overlapped structures
    for (int j = 0; j < MULTI_ASYNC_NUM; j++) {
        ftStatus = FT_InitializeOverlapped(ftHandle, &ov[j]);
        if (FT_FAILED(ftStatus)) {
            printf("FT_InitializeOverlapped (read) failed! Status=%d\n", ftStatus);
            *fatalError = 1;
            return NULL;
        }
    }

    while (!*exitReader && !*fatalError) {
        for (int j = 0; j < MULTI_ASYNC_NUM && !*fatalError; j++) {
            memset(&buf[j * MULTI_ASYNC_BUFFER_SIZE], 0xAA + j, ulBytesToRead);
            ov[j].Internal = 0;
            ov[j].InternalHigh = 0;
            ulBytesRead[j] = 0;

            ftStatus = FT_ReadPipeAsync(ftHandle, 0x00,
                                        &buf[j * MULTI_ASYNC_BUFFER_SIZE],
                                        ulBytesToRead,
                                        &ulBytesRead[j], &ov[j]);
            if (ftStatus != FT_IO_PENDING) {
                printf("[READ] FT_ReadPipeAsync failed: %d\n", ftStatus);
                *fatalError = 1;
                break;
            }

            ftStatus = FT_GetOverlappedResult(ftHandle, &ov[j],
                                              &ulBytesRead[j], TRUE);
            if (ftStatus == FT_TIMEOUT) {
                printf("[READ] Timeout waiting for data\n");
                continue; // not fatal, just no data
            } else if (FT_FAILED(ftStatus)) {
                printf("[READ] GetOverlappedResult failed: %d\n", ftStatus);
                *fatalError = 1;
                break;
            }
        }
    }

    for (int j = 0; j < MULTI_ASYNC_NUM; j++) {
        FT_ReleaseOverlapped(ftHandle, &ov[j]);
    }

    printf("Exiting %s\n", __FUNCTION__);
    return NULL;
}

static void *asyncWrite(void *arg) {
    ThreadArgs *args = (ThreadArgs *)arg;
    FT_HANDLE ftHandle = args->ftHandle;
    UCHAR *buf = args->buffer;
    volatile int *exitWriter = args->exitFlag;
    volatile int *fatalError = args->fatalError;

    FT_STATUS ftStatus = FT_OK;
    OVERLAPPED ov[MULTI_ASYNC_NUM] = {{0}};
    ULONG ulBytesWritten[MULTI_ASYNC_NUM] = {0};
    ULONG ulBytesToWrite = MULTI_ASYNC_BUFFER_SIZE;

    printf("Starting %s\n", __FUNCTION__);

    for (int j = 0; j < MULTI_ASYNC_NUM; j++) {
        ftStatus = FT_InitializeOverlapped(ftHandle, &ov[j]);
        if (FT_FAILED(ftStatus)) {
            printf("FT_InitializeOverlapped (write) failed! Status=%d\n", ftStatus);
            *fatalError = 1;
            return NULL;
        }
    }

    while (!*exitWriter && !*fatalError) {
        for (int j = 0; j < MULTI_ASYNC_NUM && !*fatalError; j++) {
            memset(&buf[j * MULTI_ASYNC_BUFFER_SIZE], 0x55 + j, ulBytesToWrite);
            ov[j].Internal = 0;
            ov[j].InternalHigh = 0;
            ulBytesWritten[j] = 0;

            ftStatus = FT_WritePipeAsync(ftHandle, 0x00,
                                         &buf[j * MULTI_ASYNC_BUFFER_SIZE],
                                         ulBytesToWrite,
                                         &ulBytesWritten[j], &ov[j]);
            if (ftStatus != FT_IO_PENDING) {
                printf("[WRITE] FT_WritePipeAsync failed: %d\n", ftStatus);
                *fatalError = 1;
                break;
            }

            ftStatus = FT_GetOverlappedResult(ftHandle, &ov[j],
                                              &ulBytesWritten[j], TRUE);
            if (ftStatus == FT_TIMEOUT) {
                if(*exitWriter) {
                    // this is an expected timeout if exit writer was set by the caller
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

    abort_pipes();

    for (int j=0; j<MULTI_ASYNC_NUM; j++)
        FT_ReleaseOverlapped(ftHandle, &ov[j]);

    printf("Exiting %s\n", __FUNCTION__);
    return NULL;
}

int main(void)
{

    int exitReader = 0, exitWriter = 0, fatalError = 0;


    FT_STATUS ftStatus = FT_Create((PVOID)"FTDI SuperSpeed-FIFO Bridge",
                                   FT_OPEN_BY_DESCRIPTION, &ftHandle);
    if (FT_FAILED(ftStatus)) {
        printf("FT_Create failed: %d\n", ftStatus);
        return EXIT_FAILURE;
    }

    // Set 1s timeouts
    FT_SetPipeTimeout(ftHandle, writePipeId, 1000);
    FT_SetPipeTimeout(ftHandle, readPipeId, 1000);

    // Allocate read/write buffers once in main
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
        return 1;
    }

    ThreadArgs readArgs = { ftHandle, readBuf, &exitReader, &fatalError };
    ThreadArgs writeArgs = { ftHandle, writeBuf, &exitWriter, &fatalError };

    pthread_create(&readThread, NULL, asyncRead, &readArgs);
    pthread_create(&writeThread, NULL, asyncWrite, &writeArgs);

    // Run for x seconds or until error
    //for (int i = 0; i < 5 && !fatalError; i++) {

	// or, run until error
	for(int i = 0; !fatalError; i++) {		
        printf("Main loop second %d\n", i);
        sleep(1);
    }

    // Signal threads to exit
	// exit reader first so we don't see any errors
	// the final writes might be lost, but that's okay.
    exitReader = 1;


    // Run until an error or manual stop
    pthread_join(readThread, NULL);
    exitWriter = 1;
    pthread_join(writeThread, NULL);

    FT_Close(ftHandle);
    free(readBuf);
    free(writeBuf);

    printf("Closed device and exited cleanly.\n");
    return 0;
}

