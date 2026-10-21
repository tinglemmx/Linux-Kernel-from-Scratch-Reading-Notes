# 2.1.2 获取硬件信息

本章节在 `2.1.1` 的 setup 模块基础上，使用 BIOS 中断获取早期启动阶段可以得到的硬件信息，并将结果显示在屏幕上。

这里的 setup 模块仍然运行在 **16 位实模式** 下，代码由 `bootsect.S` 加载后执行。

## 启动流程

```text
BIOS
  │
  ├─ 将 bootsect 加载到 0x7C00
  │
  └─ bootsect.S
       ├─ 将自身复制到 0x90000
       ├─ 从软盘读取 4 个 setup 扇区到 0x90200
       ├─ 跳转到 0x9020:0000
       └─ setup.S
            ├─ 获取硬件信息
            ├─ 将结果保存到 0x90000 附近
            ├─ 将结果转换为十六进制文本
            └─ 通过 BIOS INT 10h 显示到屏幕
```

## 目录结构

```text
2.1.2-get-hardware-info/
├── Makefile       # 汇编、链接和镜像构建规则
├── bootsect.S     # 启动扇区，负责加载并跳转到 setup
├── setup.S        # 获取并显示硬件信息
├── bootsect       # 构建生成的启动扇区二进制文件
├── setup          # 构建生成的 setup 二进制文件
└── linux.img      # 构建生成的软盘镜像
```

镜像构建工具位于项目根目录：

```text
../tools/build.c
```

`get_hardware-info.S` 中的代码已经合并到本章节的 `setup.S` 中，避免两个文件同时定义 `_start_setup` 入口。

## 获取的信息

`setup.S` 会调用以下 BIOS 服务：

| 信息 | BIOS 调用 | 保存位置（相对于 `0x9000` 段） |
| --- | --- | --- |
| 光标位置 | `INT 10h, AH=03h` | `0x0000` |
| 1 MB 以上的扩展内存 | `INT 15h, AH=88h` | `0x0002` |
| 当前显示模式 | `INT 10h, AH=0Fh` | `0x0004`、`0x0006` |
| EGA/VGA 信息 | `INT 10h, AH=12h, BL=10h` | `0x0008`、`0x000A`、`0x000C` |
| 第一块硬盘参数表 | 中断向量 `INT 41h` | `0x0080` |
| 第二块硬盘参数表 | 中断向量 `INT 46h` | `0x0090` |

这些数据先保存到内存中，然后由 `show_hardware_info` 读取并显示。数值使用十六进制输出，硬盘参数表则逐字节输出。

## 构建

需要安装 GNU assembler、GNU linker、GCC、GNU Make 和 QEMU。
通用环境与工具链说明请参考项目根目录的 [`README.md`](../README.md)。

进入本章节目录：

```bash
cd 2.1.2-get-hardware-info
```

构建启动镜像：

```bash
make
```

也可以分别构建 setup 模块或最终镜像：

```bash
make setup
make linux.img
```

查看 Makefile 将要执行的命令但不实际执行：

```bash
make -n
```

清理构建产物：

```bash
make clean
```

`make` 会完成以下工作：

1. 汇编 `bootsect.S` 和 `setup.S`；
2. 将它们链接为裸二进制文件；
3. 使用项目根目录的 `tools/build` 拼接 `bootsect` 和 `setup`；
4. 将 setup 补齐到预留的 4 个扇区；
5. 生成 `linux.img`。

当前章节还没有加入 `system` 内核，因此这里生成的是用于观察 setup 阶段的实验镜像，而不是完整 Linux 启动镜像。

## 使用 QEMU 启动

在本章节目录中执行：

```bash
qemu-system-i386 \
  -drive file=linux.img,format=raw,if=floppy \
  -boot order=a
```

如果从项目根目录启动，可以使用：

```bash
qemu-system-i386 \
  -drive file=2.1.2-get-hardware-info/linux.img,format=raw,if=floppy \
  -boot order=a
```

## 预期输出

不同 BIOS 或 QEMU 版本返回的数值可能不同，屏幕上会看到类似内容：

```text
setup is running
cursor: 0x0310
memory: 0xFC00 KB
video BX: 0x000C
video AX: 0x5003
EGA AX: 0x1203
EGA BX: 0x0003
EGA CX: 0x0009
hd0 params: CF 66 68 DB E3 00 00 E9 11 D4 66 BA 80 DA 00 00
hd1 params: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
```

其中：

- `memory` 的单位是 KB；
- `video AX/BX` 是当前显示模式相关返回值；
- `EGA AX/BX/CX` 是 EGA/VGA 查询返回值；
- `hd0 params` 和 `hd1 params` 是 BIOS 硬盘参数表的原始字节；
- QEMU 中通常没有第二块硬盘，所以 `hd1 params` 可能全部为 `00`。

屏幕顶部可能还会保留一部分 SeaBIOS 的启动信息，这是 BIOS 在启动 bootsect 之前写入的内容，不是硬件信息采集失败。

## 代码说明

- [`bootsect.S`](./bootsect.S)：将启动扇区复制到 `0x90000`，从磁盘加载 setup，并跳转到 `0x9020:0000`。
- [`setup.S`](./setup.S)：获取硬件信息、保存 BIOS 返回值，并通过 `INT 10h` 将结果显示出来。
- [`Makefile`](./Makefile)：定义汇编、链接和启动镜像的构建过程。
- [`../tools/build.c`](../tools/build.c)：将启动扇区和 setup 模块拼接成镜像，并为 setup 补齐预留扇区。
