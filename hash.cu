#include <stdint.h>
#include "hash.h"

#include "cliondoesnthandlecuda.h"

uint32_t fnv_hash_n(char *s, size_t n) {
	uint32_t h = FNV1_32_INIT;

	while(n--) {
		h ^= *s++;
		h += (h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24);
	}
	return h;
}

__device__ uint32_t fnv_hash(char *s) {
	uint32_t h = FNV1_32_INIT;

	while(*s) {
		h ^= *s++;
		h += (h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24);
	}
	return h;
}

__device__ uint32_t fnv_hash_streamone(uint32_t h, char s) {
	h ^= s;
	h += (h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24);

	return h;
}

__device__ uint32_t fnv_hash_streamend(uint32_t h, char *s) {
	while(*s) {
		h ^= *s++;
		h += (h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24);
	}
	return h;
}