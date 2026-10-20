#include <stdio.h>

int main(void)
{
    int a = 10;
    int b = 20;

    __asm__ __volatile__(
        "add %2, %0"
        : "=r"(a)
        : "0"(a), "r"(b)
        : "cc"
    );

    printf("a = %d\n", a);
    return 0;
}