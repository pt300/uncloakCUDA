#include <string.h>
#include <stdbool.h>
#include <stdio.h>
#include <alloca.h>

#include "hash.h"
#include "ip4.h"

#include "cliondoesnthandlecuda.h"

bool is_ip4(char *host) {
	int dots;

	dots = 0;
	while(*host != '\0') {
		if(*host == '.') {
			if(dots++ == 3) {
				return false;
			}
		}
		else if((*host >= 'g' && *host <= 'z' && dots < 2) ||
				(*host >= '0' && *host <= '9' && dots > 1)) {
			return false;
		}


		host++;
	}

	return true;
}

size_t find_beginning_ip4(char *host) {
	size_t where;
	int doot;

	for(where = 0, doot = 1; host[where] != '\0'; where++) {
		if(host[where] == '.') {
			if(doot == 1) {
				doot = 0;
			}
			else {
				return where + 1;
			}
		}
	}

	return 0;
}

void ip4_from_hash(uint32_t hash, char *host, size_t begins) {
	size_t i;
	int temp;

	for(i = begins; host[i] != '\0'; i++) {
		if(host[i] != '.') {
			temp = host[i] - 'g';
			temp -= hash % 20;
			if(temp < 0) {
				temp += 20;
			}
			temp -= 8;
			host[i] = (char) (temp + '0');
			ROTATE32_LEFT(hash);
		}
	}
}

__global__ void test_hash_ip4(uint32_t shift, unsigned int *ret_n, uint32_t *ret_arr, size_t begins,
							  uint32_t start_hash, char *host) {
	uint32_t hash_tested, hash_string;
	uint32_t hash;
	size_t i;
	int temp;


	hash = hash_tested = shift + blockIdx.x * blockDim.x + threadIdx.x;
	hash_string = start_hash;

	for(i = begins; host[i] != '\0'; i++) {
		if(host[i] != '.') {
			temp = host[i] - 'g';
			temp -= hash % 20;
			if(temp < 0) {
				temp += 20;
			}
			if(temp < 8 || temp > 17) {
				return;
			}
			//TODO: add check?
			//should be in range <8; 17>
			temp -= 8;
			hash_string = fnv_hash_streamone(hash_string, (char) (temp + '0'));
			ROTATE32_LEFT(hash);
		}
		else {
			hash_string = fnv_hash_streamone(hash_string, '.');
		}
	}

	if(hash_string == hash_tested) {
		atomicMin(ret_n, 128);
		ret_arr[atomicAdd(ret_n, 1)] = hash_string;
	}
}

int size_to_threads(int s) {
	return s == 3 ? 156 : s == 2 ? 89 : 10;
}

int size_to_shift(int s) {
	return s == 3 ? 100 : s == 2 ? 10 : 0;
}

int get_n_size(char *host, int n) {
	int sep, num;

	for(sep = num = 0; *host != '\0' && sep != n; host++) {

		if(*host == '.') {
			sep++;
		}
		else if(sep == n - 1) {
			num++;
		}
	}

	return num;
}

__global__ void test_str_ip4(unsigned int *ret_n, uint32_t *ret_arr, uint32_t start_hash, size_t begins,
							 int n3_shift, int n4_shift, char *host) {
	char fuckingarray[8], *ch;
	uint32_t hash;
	uint32_t n3, n4;
	size_t i;

	ch = fuckingarray;
	//sprintf(ch, "%hhu.%hhu", n3_shift + blockIdx.x, n4_shift + threadIdx.x);
	n3 = n3_shift + blockIdx.x;
	n4 = n4_shift + threadIdx.x;

	/*
	 * the evil part
	 */

	if(n3 >= 100) {
		*ch++ = (char) (n3 / 100 + '0');
		n3 %= 100;
		*ch++ = (char) (n3 / 10 + '0');
		n3 %= 10;
	}
	else if(n3 >= 10) {
		*ch++ = (char) (n3 / 10 + '0');
		n3 %= 10;
	}
	*ch++ = (char) (n3 + '0');
	*ch++ = '.';
	if(n4 >= 100) {
		*ch++ = (char) (n4 / 100 + '0');
		n4 %= 100;
		*ch++ = (char) (n4 / 10 + '0');
		n4 %= 10;
	}
	else if(n4 >= 10) {
		*ch++ = (char) (n4 / 10 + '0');
		n4 %= 10;
	}
	*ch++ = (char) (n4 + '0');
	*ch = '\0';

	n3 = (uint8_t) (n3_shift + blockIdx.x);
	n4 = (uint8_t) (n4_shift + threadIdx.x);


	hash = start_hash;
	hash = fnv_hash_streamend(hash, fuckingarray);

	for(i = begins, ch = fuckingarray; *ch != '\0'; i++, ch++) {
		if(host[i] != '.') {
			if((hash + *ch) % 20 != host[i] - 'g') {
				return;
			}
			ROTATE32_LEFT(hash);
		}
	}


	atomicMin(ret_n, 128);
	ret_arr[atomicAdd(ret_n, 1)] = (n3 << 8) | n4;
}