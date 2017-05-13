#include <string.h>
#include <ctype.h>

#include "hash.h" //this is the only way that makes it work?????
#include "host.h"

/*
 * 2 copies, one used to retrieve string from hash on host
 * other is for computations on device
 */

__device__ static const char *dtable_letters = "hijklmnopqrstuvwxyzabcdefg";
__device__ static const char *dtable_digits = "2345678901";
static const char *table_letters = "hijklmnopqrstuvwxyzabcdefg";
static const char *table_digits = "2345678901";

__global__ void test_hash_host(uint32_t shift, unsigned int *ret_n, uint32_t *ret_arr, size_t letters, char *host) {
	uint32_t hash_tested, hash_string;
	uint32_t hash_digits, hash_letters;
	size_t i;
	int temp;


	hash_digits = hash_letters = hash_tested = shift + blockIdx.x * blockDim.x + threadIdx.x;
	hash_string = FNV1_32_INIT;
	ROTATE32_LEFTN(hash_digits, letters);

	for(i = 0; host[i] != '\0' && host[i] != '.'; i++) {
		if(host[i] >= 'a' && host[i] <= 'z') {
			temp = host[i] - 'a';
			temp -= hash_letters % 26;
			if(temp < 0) {
				temp += 26;
			}
			hash_string = fnv_hash_streamone(hash_string, dtable_letters[temp]);
			ROTATE32_LEFT(hash_letters);
		}
		else if(host[i] >= '0' && host[i] <= '9') {
			temp = host[i] - '0';
			temp -= hash_digits % 10;
			if(temp < 0) {
				temp += 10;
			}
			hash_string = fnv_hash_streamone(hash_string, dtable_digits[temp]);
		}
		ROTATE32_LEFT(hash_digits);
	}
	if(host[i] == '.') {
		hash_string = fnv_hash_streamend(hash_string, host + i);
	}

	if(hash_string == hash_tested) {
		atomicMin(ret_n, 128);
		ret_arr[atomicAdd(ret_n, 1)] = hash_string;
	}
}

bool is_valid_host(char *host) {
	for(; *host != '\0'; host++) {
		if(!(isdigit(*host) || islower(*host) || *host == '-' || *host == '.')) {
			return false;
		}
	}

	return true;
}

size_t count_letters(char *host) {
	size_t chars;

	for(chars = 0; *host != '\0' && *host != '.'; host++) {
		if(islower(*host)) {
			chars++;
		}
	}

	return chars;
}

void host_from_hash(uint32_t hash, char *host) {
	size_t i;
	int temp;

	for(i = 0; host[i] != '\0' && host[i] != '.'; i++) {
		if(islower(host[i])) {
			temp = host[i] - 'a';
			temp -= hash % 26;
			if(temp < 0) {
				temp += 26;
			}
			//we just assume it uses 64bit values during calculations
			host[i] = table_letters[temp];
			ROTATE32_LEFT(hash);
		}
	}

	for(i = 0; host[i] != '\0' && host[i] != '.'; i++) {
		if(isdigit(host[i])) {
			temp = host[i] - '0';
			temp -= hash % 10;
			if(temp < 0) {
				temp += 10;
			}
			host[i] = table_digits[temp];
		}
		ROTATE32_LEFT(hash);
	}
}