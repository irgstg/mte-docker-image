#include <stdio.h>
#include <stdlib.h>

int main()
{
	int *i = NULL;
	printf(" [+] Allocating...\n");
	i = (int *) malloc (sizeof(int) * 1);
	printf(" [+] Allocated, asigned %d...\n", i[0]);
	printf(" [+] Assigning to a restricted area - SIGSEGV on it\'s way...\n");
	i[20] = 0x00;
	printf(" [!] NO FAULT OCCURED...\n");
	return 0;
}
