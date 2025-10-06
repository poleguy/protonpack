#include <stdio.h>
#include <stdlib.h>
#include "ftd3xx.h"

#define BUFFER_SIZE 4096

int main(void) {
    FT_STATUS status;
    FT_HANDLE handle;
    UCHAR buffer[BUFFER_SIZE];
    ULONG bytes_read = 0;

    // Initialize and open the first device
    status = FT_Create(0, FT_OPEN_BY_INDEX, &handle);
    if (status != FT_OK) {
        fprintf(stderr, "Failed to open FT600 device: %d\n", status);
        return EXIT_FAILURE;
    }

    printf("FT600 device opened.\n");

    // Set pipe timeouts
    status = FT_SetPipeTimeout(handle, 0x82, 5000); // IN pipe
    if (status != FT_OK) {
        fprintf(stderr, "Failed to set pipe timeout: %d\n", status);
        FT_Close(handle);
        return EXIT_FAILURE;
    }

    // Continuously read data
    while (1) {
        status = FT_ReadPipe(handle, 0x82, buffer, BUFFER_SIZE, &bytes_read, NULL);
        if (status != FT_OK) {
            fprintf(stderr, "Read failed: %d\n", status);
            break;
        }

        if (bytes_read > 0)
            printf("Read %lu bytes\n", bytes_read);
    }

    FT_Close(handle);
    return EXIT_SUCCESS;
}
