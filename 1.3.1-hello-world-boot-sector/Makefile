# 1.3.1 Hello World 启动扇区的构建文件。
#
# 构建流程：
#   bootsect.s -> bootsect.o -> linux.img -> floppy.img
#
# linux.img 是 512 字节的启动扇区，floppy.img 是可以交给 QEMU 启动的
# 1.44 MB 软盘镜像。

AS := as
LD := ld
QEMU := qemu-system-i386

# 按 32 位 i386 ELF 格式汇编和链接，但源代码生成的是 16 位实模式指令。
ASFLAGS := --32
LDFLAGS := -m elf_i386 -Ttext 0x0 --oformat binary

.PHONY: all image run inspect clean

# 默认目标：生成可以启动的软盘镜像。
all: image

image: floppy.img

# 将启动扇区放进一个 1.44 MB 的空白软盘镜像。
floppy.img: linux.img
	dd if=/dev/zero of=$@ bs=512 count=2880
	dd if=$< of=$@ conv=notrunc

# 将启动扇区链接为原始二进制文件。
linux.img: bootsect.o
	$(LD) $(LDFLAGS) -o $@ $<

# 汇编启动扇区源码。
bootsect.o: bootsect.s
	$(AS) $(ASFLAGS) -o $@ $<

# 使用 QEMU 从软盘镜像启动。
run: floppy.img
	$(QEMU) -fda $<

# 查看启动扇区末尾的 BIOS 启动签名。
inspect: linux.img
	od -An -tx1 -j510 -N2 $<

# 删除构建产生的中间文件和镜像。
clean:
	rm -f bootsect.o linux.img floppy.img
