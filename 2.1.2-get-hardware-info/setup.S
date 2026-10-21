# setup.S
#
# 这是由 bootsect.S 加载并跳转到的 setup 模块。
#
# 本模块负责：
#   1. 初始化 setup 模块的运行环境；
#   2. 显示 setup 已经启动的提示信息；
#   3. 获取光标位置、扩展内存、显示模式等硬件信息；
#   4. 获取 BIOS 硬盘参数表，并检查第二块硬盘是否存在。
#
# 本文件使用 GNU as 的 AT&T 汇编语法：
#   - 立即数前面使用 $，例如 $0x9000；
#   - 寄存器前面使用 %，例如 %ax；
#   - 指令的源操作数在前，目标操作数在后。

# 生成 16 位实模式代码，并进入代码段。
.code16
.text

# bootsect 将自身复制到 0x90000，setup 可以把采集到的硬件信息
# 保存到这一段的固定偏移处。
INITSEG = 0x9000

# 导出 setup 模块的入口符号。
# Makefile 链接 setup 时使用 -e _start_setup 指定该入口。
.globl _start_setup

_start_setup:
    # setup 模块通过远跳转进入，CS 已经指向 setup 所在的段。
    # 先让 DS、ES 指向 setup 所在的代码段，便于访问 setup_msg。
    movw %cs, %ax
    movw %ax, %ds
    movw %ax, %es

    # 清除方向标志，确保 movsb、stosb 等字符串指令执行后，
    # SI 和 DI 自动递增。原始代码隐含假设 DF=0，这里显式设置。
    cld

    # ------------------------------------------------------------------
    # 显示 setup 启动提示
    # ------------------------------------------------------------------

    # BIOS INT 10h / AH=13 要求 ES:BP 指向要显示的字符串。
    movw $setup_msg, %ax
    movw %ax, %bp

    # BIOS 视频服务：显示字符串。
    # AX=0x1301：字符串输出功能，输出后更新光标。
    # BX=0x000C：页号为 0，字符颜色为亮红色。
    # CX=16："setup is running" 一共 16 个字符。
    # DH=3、DL=0：从第 3 行、第 0 列开始显示。
    movw $0x1301, %ax
    movw $0x000c, %bx
    movw $16, %cx
    movb $3, %dh
    movb $0, %dl
    int $0x10

    # ------------------------------------------------------------------
    # 获取基础硬件信息
    # ------------------------------------------------------------------

    # 将 DS 切换到 INITSEG，使下面写入偏移 0、2、4... 的数据保存到
    # 物理地址 0x90000 附近，而不是覆盖 setup 模块自身的数据。
    movw $INITSEG, %ax
    movw %ax, %ds

    # BIOS INT 10h / AH=03：获取当前光标位置。
    movb $0x03, %ah   # 这里 AH=03h 表示读取光标位置。
    xor %bh, %bh   # 它的作用是：把 BH 寄存器清零。 异或  两个位不一样，结果为 1；两个位相同，结果为 0
    int $0x10
    movw %dx, (0)   # DH 保存行号，DL 保存列号，保存到段寄存器 DS 是默认的内存段寄存器之一同 %ds:(0)， (0)偏移地址为 0 的内存位置

  
    movb $0x88, %ah   # 把 0x88 放入 AH 寄存器，告诉 BIOS：我要调用 INT 15h 的 AH=88h 功能。用于查询 1 MB 以上的扩展内存容量
    int $0x15     # 如果调用成功，传统 BIOS 的 AH=88h 功能会在 AX 中返回扩展内存大小，单位是 KB
    movw %ax, (2)  # AX 中的 16 位数值写到当前 DS 段的偏移地址 2


    movb $0x0f, %ah # AH=0Fh 表示获取当前显示模式
    int $0x10   # 调用成功后，BIOS 返回的信息主要包括：AH=每行的字符列数，AL=当前显示模式号，BH=当前活动页号，BL=当前显示模式的颜色数
    movw %bx, (4)
    movw %ax, (6)

    # BIOS INT 10h / AH=12、BL=10h：获取 EGA/VGA 信息。
    # 保存返回的 AX、BX、CX 到 INITSEG:8、INITSEG:10、INITSEG:12。
    movb $0x12, %ah
    movb $0x10, %bl
    int $0x10
    movw %ax, (8)
    movw %bx, (10)
    movw %cx, (12)

    # ------------------------------------------------------------------
    # 获取硬盘参数表
    # ------------------------------------------------------------------

    # BIOS 中断向量表位于物理地址 0。
    # INT 41h 保存第一块硬盘（hd0）的参数表指针。
    movw $0x0000, %ax
    movw %ax, %ds
    ldsw (4 * 0x41), %si

    # 将 hd0 参数表复制到 INITSEG:0x0080，共 16 字节。
    movw $INITSEG, %ax
    movw %ax, %es
    movw $0x0080, %di
    movw $0x0010, %cx
    rep
    movsb

    # BIOS 中断向量表的 INT 46h 保存第二块硬盘（hd1）的参数表指针。
    ldsw (4 * 0x46), %si

    # 将 hd1 参数表复制到 INITSEG:0x0090，共 16 字节。
    movw $INITSEG, %ax
    movw %ax, %es
    movw $0x0090, %di
    movw $0x0010, %cx
    rep
    movsb

    # BIOS INT 13h / AH=15：检查第二块硬盘是否存在。
    # DL=0x81 表示第二块硬盘。
    movw $0x1500, %ax
    movb $0x81, %dl
    int $0x13
    jc no_disk1

    # AH=03 表示第二块硬盘存在，并且 BIOS 返回了驱动器参数。
    cmpb $3, %ah
    je is_disk1

no_disk1:
    # 如果第二块硬盘不存在，将 INITSEG:0x0090 的 16 字节参数表清零。
    movw $INITSEG, %ax
    movw %ax, %es
    movw $0x0090, %di
    movw $0x0010, %cx
    movb $0x00, %al
    rep
    stosb

is_disk1:
    # 将前面保存到 INITSEG 的硬件信息显示出来。
    # 原始代码只负责采集和保存信息，不会自动在屏幕上显示。
    call show_hardware_info

    # 当前章节还没有下一阶段代码，先停在这里，避免继续执行数据区域。
    cli
halt_loop:
    hlt
    jmp halt_loop

# ----------------------------------------------------------------------
# 输出辅助函数
# ----------------------------------------------------------------------

# put_char：使用 BIOS INT 10h / AH=0Eh 输出一个字符。
#
# 输入：AL = 要输出的字符
# 说明：保存大部分寄存器，避免 BIOS 调用影响外层代码的状态。
put_char:
    pushw %ax
    pushw %bx
    pushw %cx
    pushw %dx
    pushw %si
    pushw %di
    pushw %bp
    pushw %ds
    pushw %es

    movb $0x0e, %ah       # BIOS 电传打字输出功能
    movb $0x00, %bh       # 显示页 0
    movb $0x07, %bl       # 灰色字符属性
    int $0x10

    popw %es
    popw %ds
    popw %bp
    popw %di
    popw %si
    popw %dx
    popw %cx
    popw %bx
    popw %ax
    ret

# print_string：输出 DS:SI 指向的 NUL 结尾字符串。
print_string:
    pushw %ax
    pushw %si

print_string_loop:
    lodsb
    testb %al, %al
    jz print_string_done
    call put_char
    jmp print_string_loop

print_string_done:
    popw %si
    popw %ax
    ret

# print_newline：输出回车和换行。
print_newline:
    movb $0x0d, %al
    call put_char
    movb $0x0a, %al
    call put_char
    ret

# print_hex_nibble：将 AL 的低 4 位转换为一个十六进制字符并输出。
print_hex_nibble:
    andb $0x0f, %al
    cmpb $0x0a, %al
    jb print_hex_nibble_digit
    addb $('A' - 10), %al
    jmp print_hex_nibble_output

print_hex_nibble_digit:
    addb $'0', %al

print_hex_nibble_output:
    call put_char
    ret

# print_hex_byte：以两位十六进制形式输出 AL。
print_hex_byte:
    pushw %ax
    pushw %dx

    movb %al, %ah
    shrb $4, %al
    call print_hex_nibble

    movb %ah, %al
    call print_hex_nibble

    popw %dx
    popw %ax
    ret

# print_hex_word：以四位十六进制形式输出 AX。
print_hex_word:
    pushw %ax
    pushw %dx

    movw %ax, %dx
    movb %dh, %al
    call print_hex_byte
    movb %dl, %al
    call print_hex_byte

    popw %dx
    popw %ax
    ret

# print_hex_bytes：输出 ES:SI 指向的 CX 个字节，每个字节之间加空格。
print_hex_bytes:
    pushw %ax
    pushw %cx
    pushw %si

print_hex_bytes_loop:
    movb %es:(%si), %al
    call print_hex_byte
    movb $' ', %al
    call put_char
    incw %si
    loop print_hex_bytes_loop

    popw %si
    popw %cx
    popw %ax
    ret

# ----------------------------------------------------------------------
# 显示已经保存的硬件信息
# ----------------------------------------------------------------------

show_hardware_info:
    # 显示字符串位于 setup 模块自身，因此 DS 设为当前代码段。
    movw %cs, %ax
    movw %ax, %ds

    # 采集结果保存在 INITSEG，因此 ES 指向 INITSEG。
    movw $INITSEG, %ax
    movw %ax, %es

    # 启动提示使用 BIOS 字符串输出后，光标仍停在提示语末尾。
    # 先换行，避免第一条硬件信息紧跟在 "setup is running" 后面。
    call print_newline

    movw $msg_cursor, %si
    call print_string
    movw %es:0x0000, %ax
    call print_hex_word
    call print_newline

    movw $msg_memory, %si
    call print_string
    movw %es:0x0002, %ax
    call print_hex_word
    movw $msg_memory_unit, %si
    call print_string
    call print_newline

    movw $msg_video_bx, %si
    call print_string
    movw %es:0x0004, %ax
    call print_hex_word
    call print_newline

    movw $msg_video_ax, %si
    call print_string
    movw %es:0x0006, %ax
    call print_hex_word
    call print_newline

    movw $msg_ega_ax, %si
    call print_string
    movw %es:0x0008, %ax
    call print_hex_word
    call print_newline

    movw $msg_ega_bx, %si
    call print_string
    movw %es:0x000a, %ax
    call print_hex_word
    call print_newline

    movw $msg_ega_cx, %si
    call print_string
    movw %es:0x000c, %ax
    call print_hex_word
    call print_newline

    movw $msg_hd0, %si
    call print_string
    movw $0x0080, %si
    movw $0x0010, %cx
    call print_hex_bytes
    call print_newline

    movw $msg_hd1, %si
    call print_string
    movw $0x0090, %si
    movw $0x0010, %cx
    call print_hex_bytes
    call print_newline
    ret

# ----------------------------------------------------------------------
# 字符串数据
# ----------------------------------------------------------------------

# 字符串数据必须放在全部可执行代码之后，避免 CPU 把字符串当成指令执行。
setup_msg:
    .asciz "setup is running"

msg_cursor:
    .asciz "cursor: 0x"
msg_memory:
    .asciz "memory: 0x"
msg_memory_unit:
    .asciz " KB"
msg_video_bx:
    .asciz "video BX: 0x"
msg_video_ax:
    .asciz "video AX: 0x"
msg_ega_ax:
    .asciz "EGA AX: 0x"
msg_ega_bx:
    .asciz "EGA BX: 0x"
msg_ega_cx:
    .asciz "EGA CX: 0x"
msg_hd0:
    .asciz "hd0 params: "
msg_hd1:
    .asciz "hd1 params: "
