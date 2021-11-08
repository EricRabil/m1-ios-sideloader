//
//  CSideloadKit2.c
//  CSideloadKit
//
//  Created by Eric Rabil on 11/7/21.
//
//  Derived from https://gist.github.com/jhftss/729aea25511439dc34f0fdfa158be9b6
//

#include "CSideloadKit.h"

#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <string.h>

#include <sys/mman.h>
#include <sys/fcntl.h>
#include <sys/stat.h>

#include <mach-o/swap.h>
#include <mach-o/dyld.h>

#define READ_MAGIC(data) *(uint32_t*)data
#define IS_FAT(magic) magic == FAT_MAGIC || magic == FAT_CIGAM
#define SHOULD_SWAP_BYTES(magic) magic == MH_CIGAM || magic == MH_CIGAM_64 || magic == FAT_CIGAM
#define PMOV(ptr, offset) (void*)((uintptr_t)ptr + offset)

static struct {
    struct build_version_command cmd;
    struct build_tool_version tool_ver;
} LC_SIMULATOR_COMMAND = { LC_BUILD_VERSION, 0x20, 6, 0xA0000, 0xE0500, 1, 3, 0x2610700};

static inline void read_macho(void* bytes, struct stat fileStat, cpu_type_t cpu_type, void** extractedMacho, off_t* extractedMachoSize) {
    if (IS_FAT(READ_MAGIC(bytes))) {
        bool swap = SHOULD_SWAP_BYTES(READ_MAGIC(bytes));
        struct fat_header* header = (struct fat_header*)bytes;
        
        if (swap) {
            swap_fat_header(header, NXHostByteOrder());
        }
        
        off_t arch_offset = (off_t) sizeof(struct fat_header);
        for (int i = 0; i < header->nfat_arch; i++) {
            struct fat_arch* arch = (struct fat_arch*)PMOV(bytes, arch_offset);
            
            if (swap) {
                swap_fat_arch(arch, 1, NXHostByteOrder());
            }
            
            off_t mach_header_offset = (off_t)arch->offset;
            arch_offset += sizeof(struct fat_arch);
            
            if (arch->cputype == cpu_type) {
                *extractedMacho = PMOV(bytes, mach_header_offset);
                *extractedMachoSize = arch->size;
            }
            
            if (swap) {
                swap_fat_arch(arch, 1, NXHostByteOrder());
            }
        }
        
        if (swap) {
            swap_fat_header(header, NXHostByteOrder());
        }
    } else {
        *extractedMacho = bytes;
        *extractedMachoSize = fileStat.st_size;
    }
}

#define DIE(message, code) ({ perror(message); exit_code = code; goto end; })
int convert(const char* machOPath) {
    int exit_code = 0;
    int fileDescriptor = 0;
    struct stat fileStat;
    void* base = NULL;
    
    void* locatedMacho = NULL;
    off_t locatedMachoSize = 0;
    
    fileDescriptor = open(machOPath, O_RDONLY);
    if (fileDescriptor < 0) {
        DIE("open", 1);
    }
    
    if (fstat(fileDescriptor, &fileStat) < 0) {
        DIE("fstat", 2);
    }
    
    base = mmap(NULL, fileStat.st_size, PROT_READ | PROT_WRITE, MAP_PRIVATE, fileDescriptor, 0);
    if (base == MAP_FAILED) {
        DIE("nmap", 3);
    }
    
    read_macho(base, fileStat, CPU_TYPE_ARM64, &locatedMacho, &locatedMachoSize);
    if (locatedMacho == NULL) {
        DIE("read_macho", 5);
    }
    
    struct mach_header_64 *header = (struct mach_header_64 *)(locatedMacho);
    bool swap = SHOULD_SWAP_BYTES(READ_MAGIC(locatedMacho));
    
    if (swap) {
        swap_mach_header_64(header, NXHostByteOrder());
    }
    
    off_t load_commands_offset = sizeof(struct mach_header_64);
    struct load_command* command = (struct load_command*)(locatedMacho + load_commands_offset);
    
    uint32_t removedSize = 0, sizeofcmds = 0, numOfRemoved = 0, cmdsize = 0;
    bool found_build_version_command = false, removed = false;
    
    for (int i = 0; i < header->ncmds; i++) {
        sizeofcmds += cmdsize;
        command = (struct load_command*)(locatedMacho + load_commands_offset);
        load_commands_offset += command->cmdsize;
        removed = false;
        
        switch (command->cmd) {
            case LC_ENCRYPTION_INFO:
            case LC_ENCRYPTION_INFO_64:
            case LC_VERSION_MIN_IPHONEOS:
                removed = true; // mark the load command as removed
                removedSize += command->cmdsize;
                numOfRemoved += 1;
                printf("remove load command[0x%x] at offset:0x%llx\n", command->cmd, (mach_vm_address_t)command-(mach_vm_address_t)header);
                break;
            case LC_BUILD_VERSION:
                memcpy(command, &LC_SIMULATOR_COMMAND, sizeof(LC_SIMULATOR_COMMAND));
                found_build_version_command = true;
                printf("patch build version command at offset:0x%llx\n", (mach_vm_address_t)command-(mach_vm_address_t)header);
                break;
        }
        
        cmdsize = command->cmdsize; // maybe overwrite, backup cmdsize
        if (removedSize && !removed) { // move forward with removedSize bytes.
            memcpy((char *)command-removedSize, command, cmdsize);
        }
    }
    
    if (!found_build_version_command) { // not found, then insert one
        memcpy((char *)command-removedSize, &LC_SIMULATOR_COMMAND, sizeof(LC_SIMULATOR_COMMAND));
        removedSize -= sizeof(LC_SIMULATOR_COMMAND);
        numOfRemoved -= 1;
    }
    
    header->ncmds -= numOfRemoved;
    header->sizeofcmds -= removedSize;
    
    if (swap) {
        swap_mach_header_64(header, NXHostByteOrder());
    }
    
end:
    if (base)
        munmap(base, fileStat.st_size);
    if (fileDescriptor)
        close(fileDescriptor);
    
    return exit_code;
}
