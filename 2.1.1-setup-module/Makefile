# 使用 GNU assembler 汇编源文件。
AS := as

# 项目级构建工具位于仓库根目录的 tools/ 中。
TOOLS_DIR := ../tools
BUILD_TOOL := $(TOOLS_DIR)/build

# 使用 GNU linker，并生成 x86_64 ELF 格式的中间目标。
# 虽然源代码使用 .code16 生成 16 位指令，但目标文件仍需要匹配当前工具链的 ELF 类型。
LD := ld -m elf_x86_64

# 链接参数：
#   -Ttext 0x0      从地址 0 开始布局代码；
#   -s              删除符号表等调试信息；
#   --oformat binary 输出原始二进制，而不是 ELF 文件。
LDFLAG := -Ttext 0x0 -s --oformat binary

# 默认目标：执行 make 时生成 linux.img。
image: linux.img

# 使用项目根目录 tools/build 将 bootsect 和 setup 拼接成最终启动镜像。
# $@ 表示当前目标 linux.img。
linux.img: $(BUILD_TOOL) bootsect setup
	$(BUILD_TOOL) bootsect setup > $@

# 编译镜像构建工具。
# $< 表示第一个依赖文件，即项目根目录的 tools/build.c。
$(BUILD_TOOL): $(TOOLS_DIR)/build.c
	gcc -o $@ $<

# 将 bootsect.o 链接为裸二进制启动扇区。
bootsect: bootsect.o
	$(LD) $(LDFLAG) -o $@ $<

# 汇编 bootsect.S，生成目标文件 bootsect.o。
bootsect.o: bootsect.S
	$(AS) -o $@ $<

# 将 setup.o 链接为裸二进制 setup 模块。
# -e _start_setup 指定 setup 模块的入口符号。
setup: setup.o
	$(LD) $(LDFLAG) -e _start_setup -o $@ $<

# 汇编 setup.S，生成目标文件 setup.o。
setup.o: setup.S
	$(AS) -o $@ $<

# 删除汇编、链接和镜像构建过程中产生的文件。
clean:
	rm -f *.o
	rm -f bootsect
	rm -f setup
	rm -f $(BUILD_TOOL)
	rm -f linux.img
