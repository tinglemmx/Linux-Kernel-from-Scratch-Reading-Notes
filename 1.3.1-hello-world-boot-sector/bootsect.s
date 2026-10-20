# bootsect.s
#
# 最简单的 BIOS 启动扇区示例：
#   1. 设置 16 位实模式下的数据段；
#   2. 调用 BIOS INT 10h 在屏幕上显示 Hello World!；
#   3. 进入死循环，避免 CPU 继续执行未知内存中的内容。
#
# 本文件使用 GNU as 的 AT&T 语法：
#   - $ 表示立即数，例如 $0x7c0；
#   - % 表示寄存器，例如 %ax；
#   - 源操作数在前，目标操作数在后。

# BIOS 通常把启动扇区加载到物理地址 0x7C00。
# 实模式物理地址 = 段地址 * 16 + 偏移地址，因此 0x7C0:0 = 0x7C00。
BOOTSEG = 0x7c0

# 生成 16 位代码，并进入代码段。
.code16
.text

# 导出启动入口，链接器会使用 _start 作为程序入口。
.global _start
_start:
  # 远跳转同时设置 CS 和 IP，使代码从 BOOTSEG:start2 执行。
  jmpl $BOOTSEG, $start2

start2:
  # 将启动扇区所在的段地址设置给 DS、ES、FS 和 GS。
  # 后续访问 msg 时，段寄存器会参与物理地址计算。
  movw $BOOTSEG, %ax
  movw %ax, %ds
  movw %ax, %es
  movw %ax, %fs
  movw %ax, %gs

  # BIOS INT 10h / AH=13 要求 ES:BP 指向要显示的字符串。
  movw $msg, %ax
  movw %ax, %bp

  # AX=0x1301：选择 BIOS 字符串输出功能，并在输出后更新光标。
  # BX=0x000C：页号为 0，字符颜色为亮红色。
  # CX=12：Hello World! 一共 12 个字符。
  # DL=0：从第 0 列开始显示；DH 没有在此处显式清零。
  movw $0x01301, %ax
  movw $0x0c, %bx  # 文字为红色
  movw $12, %cx    # 字符串长度
  movb $0, %dl     # DL 表示列号

  # 调用 BIOS 视频服务，在屏幕上显示字符串。
  int $0x010

loop:
  # 程序没有后续任务，停在这里避免执行启动扇区之外的内容。
  jmp loop

msg:
  # 启动扇区中实际显示的字符串，不包含结尾的 NUL 字节。
  .ascii "Hello World!"

# 启动扇区总大小必须是 512 字节。
# 偏移 510 和 511 用于存放 BIOS 启动签名。
.org 510

boot_flag:
  # x86 BIOS 认可的启动扇区签名；小端序写入后为字节 55 AA。
  .word 0xaa55
