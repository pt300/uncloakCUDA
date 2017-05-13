#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include "cliondoesnthandlecuda.h"

#define HOSTLEN 63

//the lazy way
#include "host.h"
#include "ip4.h"
#include "ip6.h"
#include "hash.h"

enum type {
	HOSTNAME,
	IP4,
	IP6
};

unsigned int handle_host(char *host, size_t len);
unsigned int handle_ip4(char *host, size_t len);
unsigned int handle_ip4_bf(char *host, size_t len);
unsigned int handle_ip6(char *host, size_t len);

int main(int argc, char **argv) {
	size_t len;
	char *host;
	unsigned int found;
	enum type wearedealingwith;

	int dev;
	struct cudaDeviceProp prop;

	/*
	 * Host/IP preparation stuff
	 */

	if(argc < 2) {
		fprintf(stderr, "Gib me a cloaked hostname or IP number. At most %i chars long\n", HOSTLEN);
		return EXIT_FAILURE;
	}

	if(strlen(argv[1]) > HOSTLEN || !argv[1][0]) {
		fprintf(stderr, "Size %li is fooken illegal.\n", strlen(argv[1]));
		return EXIT_FAILURE;
	}

	len = strlen(argv[1]);
	host = (char *) alloca(len + 1); //that pointer cast, fuck you nvidia
	strcpy(host, argv[1]);

	if(is_ip4(host)) {
		wearedealingwith = IP4;
		printf("IPv4 address detected\n");
	}
	else if(is_ip6(host)) {
		wearedealingwith = IP6;
		printf("IPv6 address detected\n");
	}
	else if(is_valid_host(host)) {
		wearedealingwith = HOSTNAME;
		printf("Regular host name detected\n");
	}
	else {
		printf("I have no idea what to do with this crap you gave me\n");
		return EXIT_FAILURE;
	}

	/*
	 * CUDA init stuff
	 */

	if(cudaGetDeviceCount(&dev) != cudaSuccess) {
		fprintf(stderr, "CUDA seems to be broken for you.\n"
				"One way to fix it is running _ONCE_ any program that uses CUDA as root (sudo).\n"
				"If that doesn't work for you, fix your drivers.\n");
		return EXIT_FAILURE;
	}

	printf("Available devices count: %i\n", dev);
	if(dev == 0) {
		puts("No devices found.\n");
		return EXIT_FAILURE;
	}
	while(dev--) {
		cudaGetDeviceProperties(&prop, dev);
		if(prop.name[0] == 'G' &&
		   prop.name[1] == 'e')
			printf("\tGay%s\n", prop.name + 2);
		else
			printf("\t%s\n", prop.name);
	}
	puts("");


	/*
	 * THE STUFF
	 */

	switch(wearedealingwith) {
		case HOSTNAME:
			found = handle_host(host, len);
			break;
		case IP4:
			found = handle_ip4_bf(host, len);
			break;
		case IP6:
			found = handle_ip6(host, len);
			break;
	}

	printf("\rFound %i matches. Exiting...\n", found);

	return EXIT_SUCCESS;
}

unsigned int handle_host(char *host, size_t len) {
	uint64_t done;
	uint32_t *dmatch_array, hhash;
	unsigned int *dmatches, matches, hmatches;
	char *dhost, *phost;
	size_t letters;
	int wrote;

	phost = (char *) alloca(len + 1);

	cudaMalloc((void **) &dmatches, sizeof *dmatches);
	cudaMalloc((void **) &dmatch_array, 128 * sizeof *dmatch_array);
	cudaMalloc((void **) &dhost, len + 1); //don't forget about null you dumbfuck

	cudaMemset(dmatches, 0, sizeof *dmatches);
	cudaMemcpy(dhost, host, len + 1, cudaMemcpyHostToDevice);

	done = 0;
	matches = 0;


	letters = count_letters(host);

	do {
		test_hash_host<<<1024, 1024>>>(done, dmatches, dmatch_array, letters, dhost);
		done += 1024 * 1024;

		cudaMemcpy((void *) &hmatches, dmatches, sizeof *dmatches, cudaMemcpyDeviceToHost);
		matches += hmatches;
		cudaMemset(dmatches, 0, sizeof *dmatches);
		while(hmatches--) {
			cudaMemcpy(&hhash, dmatch_array + hmatches * sizeof *dmatch_array, sizeof *dmatch_array,
					   cudaMemcpyDeviceToHost);
			printf("\r%*c\r", wrote, ' ');
			strcpy(phost, host);
			host_from_hash(hhash, phost);
			puts(phost);
		}
		wrote = printf("\r%f%%, %u match", (float) done * 100 / ((float) UINT32_MAX + 1), matches);
		fflush(stdout);
	} while(done < (uint64_t) UINT32_MAX + 1);

	printf("\r%*c\r", wrote, ' ');

	cudaFree(dmatches);
	cudaFree(dmatch_array);
	cudaFree(dhost);

	return matches;
}

unsigned int handle_ip4(char *host, size_t len) {
	uint64_t done;
	uint32_t *dmatch_array, hhash, start_hash;
	unsigned int *dmatches, matches, hmatches;
	char *dhost, *phost;
	size_t beg;
	int wrote;

	phost = (char *) alloca(len + 1);

	cudaMalloc((void **) &dmatches, sizeof *dmatches);
	cudaMalloc((void **) &dmatch_array, 128 * sizeof *dmatch_array);
	cudaMalloc((void **) &dhost, len + 1);

	cudaMemset(dmatches, 0, sizeof *dmatches);
	cudaMemcpy(dhost, host, len + 1, cudaMemcpyHostToDevice);

	done = 0;
	matches = 0;
	wrote = 0;

	beg = find_beginning_ip4(host);
	start_hash = fnv_hash_n(host, beg);

	do {
		test_hash_ip4<<<1024, 1024>>>(done, dmatches, dmatch_array, beg, start_hash, dhost);
		done += 1024 * 1024;

		cudaMemcpy((void *) &hmatches, dmatches, sizeof *dmatches, cudaMemcpyDeviceToHost);
		matches += hmatches;
		cudaMemset(dmatches, 0, sizeof *dmatches);
		while(hmatches--) {
			cudaMemcpy(&hhash, dmatch_array + hmatches * sizeof *dmatch_array, sizeof *dmatch_array,
					   cudaMemcpyDeviceToHost);
			printf("\r%*c\r", wrote, ' ');
			strcpy(phost, host);
			ip4_from_hash(hhash, phost, beg);
			puts(phost);
		}
		wrote = printf("\r%f%%, %u match", (float) done * 100 / ((float) UINT32_MAX + 1), matches);
		fflush(stdout);
	} while(done < (uint64_t) UINT32_MAX + 1);

	printf("\r%*c\r", wrote, ' ');

	cudaFree(dmatches);
	cudaFree(dmatch_array);
	cudaFree(dhost);

	return matches;
}

unsigned int handle_ip4_bf(char *host, size_t len) {
	uint32_t *dmatch_array, hhash, start_hash;
	unsigned int *dmatches, matches, hmatches;
	char *dhost;
	size_t beg;
	int n3, n4, blocks, threads, shift_n3, shift_n4;

	cudaMalloc((void **) &dmatches, sizeof *dmatches);
	cudaMalloc((void **) &dmatch_array, 128 * sizeof *dmatch_array);
	cudaMalloc((void **) &dhost, len + 1);

	cudaMemset(dmatches, 0, sizeof *dmatches);
	cudaMemcpy(dhost, host, len + 1, cudaMemcpyHostToDevice);

	matches = 0;

	beg = find_beginning_ip4(host);
	start_hash = fnv_hash_n(host, beg);

	n3 = get_n_size(host, 3);
	n4 = get_n_size(host, 4);

	blocks = size_to_threads(n3);
	threads = size_to_threads(n4);
	shift_n3 = size_to_shift(n3);
	shift_n4 = size_to_shift(n4);

	test_str_ip4<<<blocks, threads>>>(dmatches, dmatch_array, start_hash, beg, shift_n3, shift_n4, dhost);

	cudaMemcpy((void *) &hmatches, dmatches, sizeof *dmatches, cudaMemcpyDeviceToHost);
	matches += hmatches;
	cudaMemset(dmatches, 0, sizeof *dmatches);
	while(hmatches--) {
		cudaMemcpy(&hhash, dmatch_array + hmatches * sizeof *dmatch_array, sizeof *dmatch_array,
				   cudaMemcpyDeviceToHost);
		printf("%.*s%hu.%hu\n", (int) beg, host, (hhash >> 8) & 0xFF, hhash & 0xFF);
	}

	cudaFree(dmatches);
	cudaFree(dmatch_array);
	cudaFree(dhost);

	return matches;
}

#pragma clang diagnostic push
#pragma ide diagnostic ignored "OCDFAInspection"

unsigned int handle_ip6(char *host, size_t len) {
	uint64_t done;
	uint32_t *dmatch_array, hhash, disamb, start_hash;
	unsigned int *dmatches, matches, hmatches;
	char *dhost, *phost;
	size_t beg;
	int wrote;

	phost = (char *) alloca(len + 1);

	cudaMalloc((void **) &dmatches, sizeof *dmatches);
	cudaMalloc((void **) &dmatch_array, 128 * 2 * sizeof *dmatch_array);
	cudaMalloc((void **) &dhost, len + 1);

	cudaMemset(dmatches, 0, sizeof *dmatches);
	cudaMemcpy(dhost, host, len + 1, cudaMemcpyHostToDevice);

	done = 0;
	matches = 0;
	wrote = 0;

	beg = find_beginning_ip6(host);
	start_hash = fnv_hash_n(host, beg);

	do {
		test_hash_ip6<<<1024, 1024>>>(done, dmatches, dmatch_array, beg, start_hash, dhost);
		done += 1024 * 1024;

		cudaMemcpy((void *) &hmatches, dmatches, sizeof *dmatches, cudaMemcpyDeviceToHost);
		matches += hmatches;
		cudaMemset(dmatches, 0, sizeof *dmatches);
		while(hmatches--) {
			cudaMemcpy(&hhash, dmatch_array + hmatches * sizeof *dmatch_array * 2, sizeof *dmatch_array,
					   cudaMemcpyDeviceToHost);
			cudaMemcpy(&disamb, dmatch_array + hmatches * sizeof *dmatch_array * 2 + 1, sizeof *dmatch_array,
					   cudaMemcpyDeviceToHost);
			printf("\r%*c\r", wrote, ' ');
			strcpy(phost, host);
			ip6_from_hash(hhash, disamb, phost, beg);
			puts(phost);
		}
		wrote = printf("\r%f%%, %u match", (float) done * 100 / ((float) UINT32_MAX + 1), matches);
		fflush(stdout);
	} while(done < (uint64_t) UINT32_MAX + 1);

	printf("\r%*c\r", wrote, ' ');

	cudaFree(dmatches);
	cudaFree(dmatch_array);
	cudaFree(dhost);

	return matches;
}

#pragma clang diagnostic pop