	.file	"example2.c"
	.text
	.section	.rodata
.LC0:
	.string	"a = %d\n"
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
	subq	$16, %rsp
	# 初始化 C 变量：a=10、b=20。
	movl	$10, -8(%rbp)
	movl	$20, -4(%rbp)
	# 将 a 和 b 装入寄存器，作为内联汇编的输入。
	movl	-8(%rbp), %eax
	movl	-4(%rbp), %edx
# GCC 生成的内联汇编开始：将 b 加到 a 上。
#APP
# 8 "example2.c" 1
	add %edx, %eax
# 0 "" 2
#NO_APP
	# 将内联汇编的输出结果保存回变量 a。
	movl	%eax, -8(%rbp)
	movl	-8(%rbp), %eax
	# 准备 printf 的格式字符串和参数。
	leaq	.LC0(%rip), %rdx
	movl	%eax, %esi
	movq	%rdx, %rdi
	movl	$0, %eax
	# 输出相加后的 a。
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
