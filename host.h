#ifndef UNCLOAKCUDA_HOST_H
#define UNCLOAKCUDA_HOST_H

#include "cliondoesnthandlecuda.h"

__global__ void test_hash_host(uint32_t shift, unsigned int *ret_n, uint32_t *ret_arr, size_t letters, char *host);
bool is_valid_host(char *host);
size_t count_letters(char *host);
void host_from_hash(uint32_t hash, char *host);
void print_host_from_hash(uint32_t hash, char *host);

#endif //UNCLOAKCUDA_HOST_H
