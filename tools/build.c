#include <stdio.h>      // fprintf()、perror()
#include <string.h>     // strcmp()
#include <stdlib.h>     // exit()
#include <sys/types.h>  // 系统调用使用的类型定义
#include <sys/stat.h>   // stat() 和 struct stat
#include <linux/fs.h>   // Linux 文件系统相关定义
#include <unistd.h>     // read()、write()、close()
#include <fcntl.h>      // open() 和 O_RDONLY

// 旧版启动镜像格式中的文件头大小。
// 当前版本没有使用这两个常量，保留它们是为了便于对照历史代码。
#define MINIX_HEADER 32
#define GCC_HEADER 1024

// system 允许的最大大小，单位是 16 字节段落（paragraph）。
// 实际限制为 0x2000 * 16 = 128 KiB。
#define SYS_SIZE 0x2000

// 未指定 rootdev 时使用的默认根设备号。
#define DEFAULT_MAJOR_ROOT 2
#define DEFAULT_MINOR_ROOT 29

// setup 模块在启动镜像中固定占用 4 个扇区，即 4 * 512 = 2048 字节。
#define SETUP_SECTS 4

// 将宏参数转换为字符串，用于错误提示信息。
#define STRINGIFY(x) #x

// 必需参数数量：程序名、bootsect、setup、system，共 4 个参数。
#define ARG_LEN 4

// 打印错误信息并退出程序。
void die(char * str)
{
	fprintf(stderr, "%s\n", str);
	exit(1);
}

// 打印命令行用法。
// 最后的重定向符号表示将标准输出写入最终启动镜像文件。
void usage(void)
{
    die("Usage: build bootsect setup [system] [rootdev] [> image]");
}

int main(int argc, char **argv)
{
	int i, c, id;
	// 读写输入文件时使用 1 KiB 缓冲区。
	char buf[1024];
	// 根设备号由主设备号和次设备号组成。
	char major_root, minor_root;
	struct stat sb;

	// 允许两种调用形式：
	//   build bootsect setup system
	//   build bootsect setup system rootdev

	if (argc < 3 || argc > 5)
		usage();

	// 处理可选的 rootdev 参数。
	// rootdev 可以是设备文件路径，也可以使用 FLOPPY 表示软盘根设备。
	if (argc == ARG_LEN + 1)
	{
		if (strcmp(argv[ARG_LEN], "FLOPPY"))
		{
			// 读取设备文件的 stat 信息，从 st_rdev 中取得设备号。
			if (stat(argv[ARG_LEN], &sb))
			{
				perror(argv[ARG_LEN]);
				die("Couldn't stat root device");
			}
			major_root = sb.st_rdev & 0xff00;
			minor_root = sb.st_rdev & 0x00ff;
		}
		else
		{
			// 软盘根设备使用 0 作为主设备号和次设备号。
			major_root = 0;
			minor_root = 0;
		}
	}
	else
	{
		// 未传入 rootdev 时使用默认的硬盘根设备号。
		major_root = DEFAULT_MAJOR_ROOT;
		minor_root = DEFAULT_MINOR_ROOT;
	}

	// 诊断信息输出到 stderr，避免污染 stdout 中的启动镜像二进制数据。
	fprintf(stderr, "Root device is (%d, %d)\n", major_root, minor_root);
	// 当前启动代码只允许软盘或指定的硬盘设备作为根设备。
	if ((major_root != 2) && (major_root != 3) && (major_root != 0))
	{
		fprintf(stderr, "Illegal root device (major = %d)\n", major_root);
		die("Bad root device --- major #");
	}

	// 初始化缓冲区，后面用于填充 setup 模块末尾的空白区域。
	for (i = 0; i < sizeof(buf); i++)
		buf[i] = 0;

	// 第一个输入文件是 bootsect，必须是恰好 512 字节的启动扇区。
	if ((id = open(argv[1], O_RDONLY, 0)) < 0)
		die("Unable to open 'boot'");

	i = read(id, buf, sizeof(buf));
	fprintf(stderr, "Boot sector %d bytes.\n", i);
	// BIOS 加载的启动扇区固定为 512 字节。
	if (i != 512)
		die("Boot block must be exactly 512 bytes");

	// 启动代码会从这两个位置读取根设备号：
	//   buf[508]：次设备号 minor
	//   buf[509]：主设备号 major
	buf[508] = (char) minor_root;
	buf[509] = (char) major_root;

	// 标准输出 fd=1：先写入带有根设备号的 bootsect。
	i = write(1, buf, 512);
	if (i != 512)
		die("Write call failed");
	close(id);

	// 第二个输入文件是 setup 模块，紧接着 bootsect 写入启动镜像。
	if ((id = open(argv[2], O_RDONLY, 0)) < 0)
		die("Unable to open 'setup'");

	// 分块复制 setup，避免假设它一定小于缓冲区大小。
	for (i = 0; (c = read(id, buf, sizeof(buf))) > 0; i += c)
		if (write(1, buf, c) != c)
			die("Write call failed");

	close(id);

	// setup 必须不超过预留的 4 个扇区。
	if (i > SETUP_SECTS * 512)
		die("Setup exceeds" STRINGIFY(SETUP_SECTS) " sectors - rewrite build/boot/setup");
	fprintf(stderr, "Setup is %d bytes.\n", i);

	// setup 不足 4 个扇区时，用 0 填充剩余空间，
	// 保证 system 从固定的扇区位置开始。
	for (c = 0; c < sizeof(buf); c++)
		buf[c] = '\0';
	while (i < SETUP_SECTS * 512)
	{
		// 每次最多写入一个缓冲区大小，最后一次只写剩余字节数。
		c = SETUP_SECTS * 512 - i;
		if (c > sizeof(buf))
			c = sizeof(buf);

		if (write(1, buf, c) != c)
			die("Write call failed");
		i += c;
	}

	if (argc >= 4)
	{
		if ((id = open(argv[3], O_RDONLY, 0)) < 0)
			die("Unable to open system file");

		for (i = 0; (c = read(id, buf, sizeof(buf))) > 0; i += c)
			if (write(1, buf, c) != c)
				die("Write call failed");

		close(id);
		fprintf(stderr, "System is %d bytes.\n", i);

		if (i > SYS_SIZE * 16)
			die("System is too big");
	}

	return 0;
}
