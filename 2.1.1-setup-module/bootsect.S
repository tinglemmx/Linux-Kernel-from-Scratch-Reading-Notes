# bootsect.S
#
# 这是启动扇区代码，运行在 BIOS 加载的 16 位 x86 实模式环境中。
# 它负责：
#   1. 把自己从 0x7C00 复制到 0x90000；
#   2. 从磁盘加载后续的 setup 模块；
#   3. 显示加载提示；
#   4. 跳转到 setup 模块执行。
#
# 本文件使用 GNU as 的 AT&T 汇编语法：
#   - 立即数前面使用 $，例如 $0x7c0；
#   - 寄存器前面使用 %，例如 %ax；
#   - 指令的源操作数在前，目标操作数在后。

# setup 模块占用的扇区数。
# BIOS INT 13h 的 AH=02 读扇区服务会使用 AL 取得这个数量。
SETUPLEN = 4

# BIOS 通常把启动扇区加载到物理地址 0x7C00。
# 实模式物理地址 = 段地址 * 16 + 偏移地址，因此 0x7C0:0 对应 0x7C00。
BOOTSEG = 0x7c0

# 启动代码复制后的段地址：0x9000:0 = 0x90000。
INITSEG = 0x9000

# setup 模块的段地址：0x9020:0 = 0x90200。
# 启动扇区本身占用 0x9020 之前的 512 字节。
SETUPSEG = 0x9020

# 后续系统代码的预期加载段地址。
# 当前启动代码还没有使用这个常量。
SYSSEG = 0x1000

# SYSSIZE 需要由其他汇编参数或源文件提供。
# ENDSEG 在当前代码中没有实际使用，保留它是为了与早期 Linux 启动代码的布局对应。
ENDSEG = SYSSEG + SYSSIZE

ROOT_DEV  = 0x000


# 汇编指示符（Assembler Directives）给汇编器 看的 
.code16    # 告诉汇编器：按照 16 位代码模式生成指令编码。
.text      # 切换到代码节

# 导出入口符号，链接时使用 _start 作为启动入口。
.global _start
_start:
    # 远跳转同时设置 CS 和 IP，使代码统一从 BOOTSEG:start2 执行。
    jmpl $BOOTSEG, $start2

start2:  # 这里就是将启动扇区从 0x7C00 开始的512字节复制到 0x90000 的代码段。
    # 设置复制操作的源段：DS:SI 指向 BIOS 加载的原始启动扇区。
    movw $BOOTSEG, %ax
    movw %ax, %ds

    # 设置复制操作的目标段：ES:DI 指向 0x90000。
    movw $INITSEG, %ax
    movw %ax, %es

    # 设置重复次数：rep movsw 将执行 256 次。
    movw $256, %cx

    # 将源偏移 SI 和目标偏移 DI 都清零。
    subw %si, %si
    subw %di, %di

    # DS:SI -> ES:DI，使用 movsw 每次复制 2 字节。
    # CX=256，因此总共复制 256 * 2 = 512 字节，即整个启动扇区。
    # 这里默认方向标志 DF=0，使 SI 和 DI 在复制过程中递增。
    rep  #是重复执行前缀，意思是：只要计数器 CX 不为 0，就重复执行后面的字符串指令，并且每次执行后将 CX 减 1。
    movsw

    # 跳转到复制后的代码。
    # 后续代码将从 INITSEG:go，也就是物理地址 0x90000 附近继续执行。CS = 0x9000 IP = go 对应的偏移地址
    jmpl $INITSEG, $go

go:
    # 使用当前代码段初始化数据段和栈段。
    # 复制后的代码通过 CS=INITSEG 运行，因此 DS/ES/SS 也设为同一段。
    movw %cs, %ax
    movw %ax, %ds
    movw %ax, %es
    movw %ax, %ss

    # 设置栈顶偏移。实模式下栈向低地址增长。SP 是 Stack Pointer（栈指针）栈通常由 SS:SP 共同定位
    movw $0xFF00, %sp

load_setup:  # 设置磁盘读取参数
    # BIOS INT 13h / AH=02：从磁盘读取扇区。
    #
    # DX = 0x0000：DH=磁头 0，DL=驱动器 0（通常表示软盘 A:）。
    # CX = 0x0002：CH=柱面 0，CL=扇区 2；扇区编号从 1 开始。
    # ES:BX = 0x9000:0x0200 = 物理地址 0x90200，作为目标地址。
    # AL = SETUPLEN：读取 4 个扇区。
    movw $0x0000, %dx
    movw $0x0002, %cx
    movw $0x0200, %bx
    movb $SETUPLEN, %al
    movb $0x02, %ah   # AH = 0x02：读取磁盘扇区。
    int $0x13   # int $0x13 是一条真正的 x86 CPU 指令，叫做软件中断指令（Software Interrupt） 让 CPU 触发中断号 0x13，在传统 BIOS 启动环境下，这通常会调用 BIOS 提供的磁盘服务。

    # CF=0 表示 BIOS 读盘成功，跳到成功分支。
    jnc ok_load_setup

    # 读盘失败：INT 13h / AH=00 重置磁盘系统，然后重试。
    movw $0x0000, %dx
    movw $0x0000, %ax   # AH = 0x00：重置磁盘系统。
    int $0x13
    jmp load_setup

ok_load_setup:
    # 准备通过 BIOS INT 10h / AH=13 显示字符串。
    # ES:BP 指向要显示的字符串。
    movw $msg, %ax
    movw %ax, %bp

    # AX=0x1301：BIOS 字符串输出功能，并在输出后更新光标。
    # BX=0x000C：页号为 0，字符颜色为亮红色。
    # CX=21：字符串 "Setup has been loaded" 的字符数。
    # DH=0、DL=0：从第 0 行、第 0 列开始显示。
    movw $0x1301, %ax
    movw $0x0c, %bx
    movw $21, %cx
    movb $0, %dl
    int $0x10   # int $0x10 就是调用 BIOS 的视频服务，开始把字符串显示到屏幕上

    # 跳转到已经加载到 0x90200 的 setup 模块入口。
    jmpl $SETUPSEG, $0

msg:
    # 21 个字符，供 INT 10h / AH=13 使用。
    .ascii "Setup has been loaded"

# 将当前位置填充到启动扇区的倒数第 4 个字节。
# 508-509 保存根设备号，510-511 保存 BIOS 启动签名。
.org 508

root_dev:
    # 根设备号。0 表示暂未指定根设备。
    .word ROOT_DEV

boot_flag:
    # x86 BIOS 认可的启动扇区签名；小端序写入后为字节 55 AA。
    .word 0xaa55
