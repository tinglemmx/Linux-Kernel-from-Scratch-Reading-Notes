# 1.4.1 GCC 扩展内嵌汇编示例的构建文件。
#
# 每个 C 示例都可以：
#   1. 编译为可执行文件；
#   2. 使用 gcc -S 生成 AT&T 格式汇编，便于观察内联汇编如何展开。

CC := gcc

# 保留调试友好的栈帧，并打开常用警告。
CFLAGS := -Wall -Wextra -O0

# 让 make 默认同时生成两个可执行文件和两份汇编文件。
.PHONY: all run-example1 run-example2 clean

all: example1 example2 example1.s example2.s

# 将 example1.c 编译并链接为可执行文件。
example1: example1.c
	$(CC) $(CFLAGS) -o $@ $<

# 将 example2.c 编译并链接为可执行文件。
example2: example2.c
	$(CC) $(CFLAGS) -o $@ $<

# -S 只生成汇编，不进行汇编和链接；-masm=att 使用 AT&T 语法。
example1.s: example1.c
	$(CC) -O0 -S -masm=att $< -o $@

example2.s: example2.c
	$(CC) -O0 -S -masm=att $< -o $@

# 运行第一个示例。
run-example1: example1
	./example1

# 运行第二个示例。
run-example2: example2
	./example2

# 删除编译生成的可执行文件和汇编文件。
clean:
	rm -f example1 example2 example1.s example2.s
