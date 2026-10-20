	.file	"example1.c"
	.text
	.section	.rodata
.LC0:
	.string	"out1 = %d, out2 = %d\n"
	.text
	.globl	main
	.type	main, @function
main:
# main 函数的标准 x86-64 栈帧建立过程。
.LFB0:
	.cfi_startproc
	endbr64
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register 6
	subq	$32, %rsp
	# 初始化 C 变量：a=1、b=2、c=3。
	movl	$1, -20(%rbp)
	movl	$2, -16(%rbp)
	movl	$3, -12(%rbp)
	# 将 C 变量装入寄存器，作为内联汇编的输入操作数。
	movl	-20(%rbp), %ecx
	movl	-16(%rbp), %esi
	movl	-12(%rbp), %edi
# GCC 生成的内联汇编开始。
# 这里计算 out1 = a + b，out2 = b + c。
#APP
# 8 "example1.c" 1
	mov %ecx, %edx
	add %esi, %edx
	mov %esi, %eax
	add %edi, %eax
	
# 0 "" 2
#NO_APP
	# 将内联汇编写入输出寄存器的结果保存回 C 变量。
	movl	%edx, -8(%rbp)
	movl	%eax, -4(%rbp)
	movl	-4(%rbp), %edx
	movl	-8(%rbp), %eax
	# 准备 printf 的格式字符串和参数。
	leaq	.LC0(%rip), %rcx
	movl	%eax, %esi
	movq	%rcx, %rdi
	movl	$0, %eax
	# 调用 printf 输出 out1 和 out2。
	call	printf@PLT
	movl	$0, %eax
	# 恢复栈帧并返回 main。
	leave
	.cfi_def_cfa 7, 8
	ret
	.cfi_endproc
.LFE0:
	.size	main, .-main
	.ident	"GCC: (Ubuntu 15.2.0-16ubuntu1) 15.2.0"
	.section	.note.GNU-stack,"",@progbits
	.section	.note.gnu.property,"a"
	.align 8
	.long	1f - 0f
	.long	4f - 1f
	.long	5
0:
	.string	"GNU"
1:
	.align 8
	.long	0xc0000002
	.long	3f - 2f
2:
	.long	0x3
3:
	.align 8
4:
