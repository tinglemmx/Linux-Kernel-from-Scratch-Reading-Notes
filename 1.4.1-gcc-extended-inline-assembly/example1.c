#include <stdio.h>

int main(void)
{
    int out1, out2;
    int in1 = 1, in2 = 2, in3 = 3;

    __asm__ __volatile__(
        "mov %[in1], %[out1]\n\t"
        "add %[in2], %[out1]\n\t"
        "mov %[in2], %[out2]\n\t"
        "add %[in3], %[out2]\n\t"
        : [out1] "=&r" (out1),
          [out2] "=&r" (out2)
        : [in1] "r" (in1),
          [in2] "r" (in2),
          [in3] "r" (in3)
        : "cc"
    );

    printf("out1 = %d, out2 = %d\n", out1, out2);
    return 0;
}