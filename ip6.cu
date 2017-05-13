#include <string.h>
#include <stdbool.h>

#include "hash.h"
#include "ip6.h"

#include "cliondoesnthandlecuda.h"

char htable[] = "def-----012345678abc"; //17  a==9
__device__ char dtable[] = "def-----012345678abc";

bool is_ip6(char *host) {
	int chars, doots;

	doots = 0;
	chars = 4;
	while(*host != '\0') {
		if(*host == ':') {
			chars = 4;
			doots++;
		}
		else if((*host >= 'a' && *host <= 'z') ||
				(*host >= '0' && *host <= '9')) {
			if(chars-- == 0) {
				return false;
			}
		}
		else {
			return false;
		}
		host++;
	}

	if(doots < 2) {
		return false;
	}

	return true;
}

size_t find_beginning_ip6(char *host) {
	size_t where;

	for(where = 0; host[where] != '\0' && host[where] < 'g'; where++);

	return where;
}

void ip6_from_hash(uint32_t hash, uint32_t disamb, char *host, size_t begins) {
	size_t i;
	int temp;

	for(i = begins; host[i] != '\0'; i++) {
		if(host[i] != ':') {
			temp = host[i] - 'g';
			temp -= hash % 20;

			if(temp < 0) {
				temp += 20;
			}

			if(temp == 17) {
				host[i] = disamb & 1 ? '9' : 'a';
				disamb >>= 1;
			}
			else {
				host[i] = htable[temp];
			}
			ROTATE32_LEFT(hash);
		}
	}
}

__global__ void
test_hash_ip6(uint32_t shift, unsigned int *ret_n, uint32_t *ret_arr, size_t begins, uint32_t start_hash, char *host) {
	uint32_t hash_tested, hash_string;
	uint32_t hash, disamb_max, disamb, cursor;
	size_t i;
	int temp;


	hash = hash_tested = shift + blockIdx.x * blockDim.x + threadIdx.x;
	hash_string = start_hash;
	disamb = 0;
	disamb_max = ~disamb;

	for(i = begins; host[i] != '\0'; i++) {
		if(host[i] != ':') {
			temp = host[i] - 'g';
			temp -= hash % 20;

			if(temp < 0) {
				temp += 20;
			}

			if(temp < 8 && temp > 2) {
				return;
			}

			if(temp == 17) {
				disamb_max <<= 1;
			}

			hash_string = fnv_hash_streamone(hash_string, dtable[temp]);
			ROTATE32_LEFT(hash);
		}
		else {
			hash_string = fnv_hash_streamone(hash_string, ':');
		}
	}

	if(hash_string == hash_tested) {
		atomicMin(ret_n, 128 * 2);
		i = atomicAdd(ret_n, 1);
		atomicMin(ret_n, 128 * 2);
		ret_arr[i * 2 + 0] = hash_string;
		ret_arr[i * 2 + 1] = disamb;
	}

	disamb_max = ~disamb_max;

	while(disamb++ != disamb_max) {
		for(i = begins, cursor = 1,
			hash = hash_tested, hash_string = start_hash; host[i] != '\0'; i++) {
			if(host[i] != ':') {
				temp = host[i] - 'g';
				temp -= hash % 20;

				if(temp < 0) {
					temp += 20;
				}

				if(temp == 17) {
					hash_string = fnv_hash_streamone(hash_string, (char) (disamb & cursor ? '9' : 'a'));
					cursor <<= 1;
				}
				else {
					hash_string = fnv_hash_streamone(hash_string, dtable[temp]);
				}
				ROTATE32_LEFT(hash);
			}
			else {
				hash_string = fnv_hash_streamone(hash_string, ':');
			}
		}

		if(hash_string == hash_tested) {
			atomicMin(ret_n, 128 * 2);
			i = atomicAdd(ret_n, 1);
			atomicMin(ret_n, 128 * 2);
			ret_arr[i * 2 + 0] = hash_string;
			ret_arr[i * 2 + 1] = disamb;
		}

	}

}