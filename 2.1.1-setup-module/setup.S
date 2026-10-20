# setup.S
#
# 这是被 bootsect.S 加载并跳转到的 setup 模块示例。
# 它运行在 16 位 x86 实模式下，当前功能是：
#   1. 使用当前代码段初始化 DS 和 ES；
#   2. 调用 BIOS 视频服务显示 "setup is running"。
#
# 本文件使用 GNU as 的 AT&T 汇编语法：立即数使用 $，寄存器使用 %。

# 生成 16 位代码，并进入代码段。
.code16
.text

# 导出 setup 模块的入口符号。
# Makefile 在链接 setup 时通过 -e _start_setup 指定该入口。
.globl _start_setup

_start_setup:
    # setup 模块通过远跳转进入，CS 已经指向 setup 所在的段。
    # 将当前代码段同步到 DS 和 ES，便于访问模块内的数据。
    movw %cs, %ax
    movw %ax, %ds
    movw %ax, %es

    # BIOS INT 10h / AH=13 要求 ES:BP 指向字符串。
    movw $setup_msg, %ax
    movw %ax, %bp

    # BIOS 视频服务：显示字符串。
    # AX=0x1301：字符串输出功能，输出后更新光标。
    # BX=0x000C：页号为 0，字符颜色为亮红色。
    # CX=16："setup is running" 一共 16 个字符。
    # DH=3、DL=0：从第 3 行、第 0 列开始显示。
    movw $0x1301, %ax
    movw $0x0c, %bx
    movw $16, %cx
    movb $3, %dh
    movb $0, %dl

    # 调用 BIOS 视频中断。
    int $0x10

    # 字符串数据本身，不包含结尾的 NUL 字节。
setup_msg:
    .ascii "setup is running"

# 注意：当前示例在 INT 10h 返回后没有 halt、死循环或跳转到下一阶段。
# 如果它作为完整启动流程的一部分使用，需要在这里继续执行后续逻辑，
# 或增加 cli/hlt、jmp 等停止/转移代码，避免 CPU 把字符串字节当成指令继续执行。
