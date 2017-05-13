#ifndef UNCLOAKCUDA_IP6_H
#define UNCLOAKCUDA_IP6_H

#include <stdbool.h>

bool is_ip6(char *host);
size_t find_beginning_ip6(char *host);
void ip6_from_hash(uint32_t hash, uint32_t disamb, char *host, size_t begins);
__global__ void test_hash_ip6(uint32_t shift, unsigned int *ret_n, uint32_t *ret_arr, size_t begins, uint32_t start_hash, char *host);

#endif //UNCLOAKCUDA_IP6_H
