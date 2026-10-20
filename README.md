# Linux-Kernel-from-Scratch-Reading-Notes

《从零开始写 Linux 内核》的阅读笔记、实验代码和运行记录。

## 项目结构

- [`1.3.1-hello-world-boot-sector/`](./1.3.1-hello-world-boot-sector/)：Hello World 启动扇区代码、实验文件和章节笔记
- [`1.4.1-gcc-extended-inline-assembly/`](./1.4.1-gcc-extended-inline-assembly/)：GCC 扩展内嵌汇编示例代码和章节笔记
- [`2.1.1-setup-module/`](./2.1.1-setup-module/)：启动时跳转到 setup 模块的相关代码
- [`assets/`](./assets/)：图片、截图和其他 Markdown 附件，统一平铺存放

章节相关的笔记直接放在对应章节目录的 `README.md` 中；通用的环境与工具链说明放在本项目 README 的下方。

## 环境与工具链

> [!info] 目标
> 实验机装好 QEMU/KVM（跑内核）+ Bochs（早期调试）+ nasm/gdb（汇编与调试），能启动模拟器、能单步调试。

### 1 实验设备

- **系统**：Ubuntu 24.04.2 LTS（Noble Numbat），x86_64
- 确认方法：`cat /etc/os-release`
- 说明：Ubuntu 24.04 可直接用 apt 装 KVM，无需自编译 QEMU

### 2 QEMU / KVM 安装

#### 2.1 安装 KVM 及 libvirt

```bash
sudo apt update

sudo apt install -y \
  qemu-kvm \
  libvirt-daemon-system \
  libvirt-clients \
  virtinst \
  bridge-utils \
  cpu-checker
```
Ubuntu 26.04 LTS 
```BASH
sudo apt update

sudo apt install -y \
  qemu-system-x86 \
  libvirt-daemon-system \
  libvirt-clients \
  virtinst \
  bridge-utils \
  cpu-checker
```

#### 2.2 启动 libvirtd 服务（Ubuntu 24.04）

```bash
sudo systemctl enable --now libvirtd
systemctl status libvirtd --no-pager
```

#### 2.3 检查 KVM 是否可用（Ubuntu 官方文档方式）

```bash
egrep -c '(vmx|svm)' /proc/cpuinfo
kvm-ok
ls -l /dev/kvm
```

预期正常输出：

```
INFO: /dev/kvm exists
KVM acceleration can be used
```

#### 2.4 验证 libvirt 管理能力

```bash
virsh -c qemu:///system list --all
virsh -c qemu:///system pool-list --all
virsh -c qemu:///system net-list --all
```

> [!note] 注意
> 统一使用 `qemu:///system`（系统模式），避免与用户模式（`qemu:///session`）的虚拟机、网络、存储资源混淆。若后续配合 OpenTofu 使用，这点尤其重要。

### 3 Bochs 安装

```bash
sudo apt update

sudo apt install -y \
  bochs \
  bochs-x \
  bochs-sdl \
  bochsbios \
  vgabios \
  nasm \
  gdb
```

各包作用：

- `bochs`：模拟器核心
- `bochs-x` / `bochs-sdl`：图形显示后端（是否可用取决于软件包构建）
- `bochsbios` / `vgabios`：BIOS 固件
- `nasm`：汇编器
- `gdb`：调试工具

### 4 验证清单（待执行并回填输出）

- [x] `kvm-ok` → 输出 `INFO: /dev/kvm exists / KVM acceleration can be used`
- [x] `ls -l /dev/kvm` → 设备存在
- [x] `virsh -c qemu:///system list --all` → 命令正常返回
- [x] `bochs --version`
- [x] `nasm -v`
- [x] `gdb --version`

> [!note] 实际输出（执行后回填）
> - kvm-ok：
```BASH
❯ kvm-ok
INFO: /dev/kvm exists
KVM acceleration can be used
```

> - ls -l /dev/kvm：
```BASH
❯ ls -l /dev/kvm
crw-rw---- 1 root kvm 10, 232 Oct 15 08:59 /dev/kvm
```
> - virsh list --all：
```BASH
❯ virsh list --all
 Id   Name   State
--------------------
```
> - bochs --version：
```BASH
❯ bochs --version
00000000000i[      ] LTDL_LIBRARY_PATH not set. using compile time default '/usr/lib/x86_64-linux-gnu/bochs/plugins'
========================================================================
                        Bochs x86 Emulator 2.7
              Built from SVN snapshot on August  1, 2021
                Timestamp: Sun Aug  1 10:07:00 CEST 2021
========================================================================
Usage: bochs [flags] [bochsrc options]

  -n               no configuration file
  -f configfile    specify configuration file
  -q               quick start (skip configuration interface)
  -benchmark N     run Bochs in benchmark mode for N millions of emulated ticks
  -dumpstats N     dump Bochs stats every N millions of emulated ticks
  -r path          restore the Bochs state from path
  -log filename    specify Bochs log file name
  -unlock          unlock Bochs images leftover from previous session
  -rc filename     execute debugger commands stored in file
  -dbglog filename specify Bochs internal debugger log file name
  --help           display this help and exit
  --help features  display available features / devices and exit
  --help cpu       display supported CPU models and exit

For information on Bochs configuration file arguments, see the
bochsrc section in the user documentation or the man page of bochsrc.
00000000000p[      ] >>PANIC<< command line arg '--version' was not understood
00000000000e[SIM   ] notify called, but no bxevent_callback function is registered
00000000000e[SIM   ] notify called, but no bxevent_callback function is registered
========================================================================
Bochs is exiting with the following message:
[      ] command line arg '--version' was not understood
========================================================================
00000000000i[SIM   ] quit_sim called with exit code 1
```

### 5 踩坑记录 / 备注

- 若 `kvm-ok` 报错或没有 `/dev/kvm`：先确认是物理机还是虚拟化环境，物理机检查 BIOS 里的虚拟化开关（VMX/SVM），虚拟机检查是否开启嵌套虚拟化
- 若 `libvirtd` 启动失败：查看 `journalctl -u libvirtd -n 50` 定位原因
