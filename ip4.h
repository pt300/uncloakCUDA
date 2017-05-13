#ifndef UNCLOAKCUDA_IP4_H
#define UNCLOAKCUDA_IP4_H

#include <stdint.h>
#include <stdbool.h>
#include "cliondoesnthandlecuda.h"

bool is_ip4(char *host);
void ip4_from_hash(uint32_t hash, char *host, size_t begins);
size_t find_beginning_ip4(char *host);
__global__ void test_hash_ip4(uint32_t shift, unsigned int *ret_n, uint32_t *ret_arr, size_t begins,
							  uint32_t start_hash, char *host);
int get_n_size(char *host, int n);
int size_to_shift(int s);
int size_to_threads(int s);
__global__ void test_str_ip4(unsigned int *ret_n, uint32_t *ret_arr, uint32_t start_hash, size_t begins,
							 int n3_shift, int n4_shift, char *host);
#endif //UNCLOAKCUDA_IP4_H
