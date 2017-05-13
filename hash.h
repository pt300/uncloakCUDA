#ifndef UNCLOAKCUDA_HASH_H
#define UNCLOAKCUDA_HASH_H

#include <stdint.h>
#include "cliondoesnthandlecuda.h"

#define FNV1_32_INIT    0x811c9dc5UL

#define ROTATE32_LEFT(v) (v = (v << 1) | (v >> 31))
#define ROTATE32_LEFTN(v, n) (v = (v << (n % 32)) | (v >> (32 - n % 32)))

uint32_t fnv_hash_n(char *s, size_t n);

__device__ uint32_t fnv_hash(char *s);
__device__ uint32_t fnv_hash_streamone(uint32_t h, char s);
__device__ uint32_t fnv_hash_streamend(uint32_t h, char *s);


#endif //UNCLOAKCUDA_HASH_H
