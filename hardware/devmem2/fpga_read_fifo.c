/*
 * devmem2.c: Simple program to read/write from/to any location in memory.
 *
 *  Copyright (C) 2000, Jan-Derk Bakker (jdb@lartmaker.nl)
 *
 *
 * This software has been developed for the LART computing board
 * (http://www.lart.tudelft.nl/). The development has been sponsored by
 * the Mobile MultiMedia Communications (http://www.mmc.tudelft.nl/)
 * and Ubiquitous Communications (http://www.ubicom.tudelft.nl/)
 * projects.
 *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <signal.h>
#include <fcntl.h>
#include <ctype.h>
#include <termios.h>
#include <sys/types.h>
#include <sys/mman.h>
  
#define FATAL do { fprintf(stderr, "Error at line %d, file %s (%d) [%s]\n", \
  __LINE__, __FILE__, errno, strerror(errno)); exit(1); } while(0)
 
#define MAP_SIZE 4096UL
#define MAP_MASK (MAP_SIZE - 1)

int main(int argc, char **argv) {
    int fd;
    void *map_base, *virt_addr; 
	unsigned long read_result, writeval;
	unsigned long read_result_1;
	unsigned long read_result_2;
	unsigned long read_result_3;
	off_t word_target;
	off_t target;
	
	if(argc < 2) {
		fprintf(stderr, "\nUsage:\t%s { address }\n"
                "\taddress : memory word address to read\n\n",
                argv[0]);
		exit(1);
	}
    
	word_target = 4;
	target = 0x40000000+word_target*4;


    if((fd = open("/dev/mem", O_RDWR | O_SYNC)) == -1) FATAL;
    printf("/dev/mem opened.\n"); 
    fflush(stdout);
    
    /* Map one page */
    map_base = mmap(0, MAP_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, target & ~MAP_MASK);
    if(map_base == (void *) -1) FATAL;
    printf("Memory mapped at address %p.\n", map_base); 
    fflush(stdout);
    
    virt_addr = map_base + (target & MAP_MASK);
    read_result = *((unsigned long *) virt_addr);

    virt_addr = map_base + (target+1 & MAP_MASK);
    read_result_1 = *((unsigned long *) virt_addr);
    virt_addr = map_base + (target+2 & MAP_MASK);
    read_result_2 = *((unsigned long *) virt_addr);
    virt_addr = map_base + (target+3 & MAP_MASK);
    read_result_3 = *((unsigned long *) virt_addr);

    
    printf("Value at address 0x%lX (%p): 0x%lX\n", word_target, virt_addr, read_result); 
    printf("Value at address 0x%lX (%p): 0x%lX\n", word_target, virt_addr, read_result_1); 
    printf("Value at address 0x%lX (%p): 0x%lX\n", word_target, virt_addr, read_result_2); 
    printf("Value at address 0x%lX (%p): 0x%lX\n", word_target, virt_addr, read_result_3); 
    fflush(stdout);
	
	if(munmap(map_base, MAP_SIZE) == -1) FATAL;
    close(fd);
    return 0;
}

