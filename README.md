# KONICA MINOLTA bizhub 2600P / 3000MF / 3080MF 打印驱动（macOS + Linux）

> **v1.1.0（跨平台）**：支持 **macOS（Apple Silicon）** 与 **Linux（x86_64 / arm64）**。下载见 [Release v1.1.0](https://github.com/Thregren/konica-bizhub-3000mf-arm-macos-driver/releases/tag/v1.1.0)。

## 简介

这是基于开源 [brlaser](https://github.com/pdewacht/brlaser)（GPL-2.0+）的
CUPS 打印过滤器，用于把 CUPS Raster 转换为这三台 Brother 代工机型的原生
PJL + Brother HBP `*b1030m` 数据流。macOS 版为 Apple Silicon 原生 `arm64`；
Linux 版为 `x86_64` / `aarch64` 的 `.deb` 安装包。两者都不依赖厂商二进制或内核模块。

- **打印协议**：PJL + Brother HBP 栅格，`*b1030m` 分带压缩（与 brlaser 同族）。
- **机型**：bizhub 2600P / 3000MF / 3080MF（Brother ML13 引擎，GDI/HBP）。
- **本驱动不含**：扫描、传真、状态监视、耗材/维护工具（厂商闭源，Apple Silicon 无法运行；
  扫描说明见下文）。

### 支持的平台

| 平台 | 架构 | 产物 |
|------|------|------|
| macOS | Apple Silicon (arm64) | 原生 arm64 过滤器 + `.pkg` |
| Linux | x86_64 (amd64) | `.deb` |
| Linux | aarch64 (arm64) | `.deb` |

## 安装

### macOS

先决条件：Apple Silicon Mac、macOS 12 或更高版本、有管理员权限。

#### 方式一：使用 .pkg 安装包（推荐）

从 Releases 下载 `KONICA-MINOLTA-bizhub-2600P-3000MF-3080MF-ARM-1.1.0.pkg`：

```bash
sudo installer -pkg ~/Downloads/KONICA-MINOLTA-bizhub-2600P-3000MF-3080MF-ARM-1.1.0.pkg -target /
```

若 macOS 拦截未签名安装包，在“系统设置 → 隐私与安全性”中确认打开，或直接用上面的终端命令。

#### 方式二：源码脚本安装

```bash
zsh install.sh
```

两种方式都只安装驱动文件，不会自动创建打印机队列。安装内容：

- `/Library/Printers/KONICAMINOLTA/Filter/rastertobrlaser`（arm64）
- `/Library/Printers/PPDs/Contents/Resources/` 下三份 `KONICA MINOLTA bizhub … (ARM).ppd.gz`

### Linux

#### 方式一：安装 .deb（推荐）

```bash
sudo dpkg -i konica-bizhub-2600p-3000mf-3080mf_1.1.0-1_$(dpkg --print-architecture).deb
```

#### 方式二：源码编译安装

需要 `build-essential`、`g++`、`libcups2-dev`、`libcupsimage2-dev`：

```bash
sudo ./scripts/install-linux.sh
```

若发行版 filter 目录是 `/usr/libexec/cups/filter`（RHEL/Fedora）：

```bash
make -C linux
sudo FILTERDIR=/usr/libexec/cups/filter make -C linux install
sudo systemctl restart cups
```

## 添加打印机

### macOS

安装驱动文件后，在“系统设置 → 打印机与扫描仪”里添加打印机，并在“使用”下拉框选
“选择软件…”，按机型选中 `KONICA MINOLTA bizhub 2600P/3000MF/3080MF (ARM)`。
不要选 AirPrint 或「通用 PostScript 打印机」。

命令行（推荐）：

```bash
lpadmin -p Bizhub3000MF -E -v socket://打印机IP:9100 \
  -P "/Library/Printers/PPDs/Contents/Resources/KONICA MINOLTA bizhub 3000MF (ARM).ppd.gz"
lp -d Bizhub3000MF /etc/hosts
```

USB 打印先查设备 URI：

```bash
lpinfo --include-schemes usb -v
lpadmin -p Bizhub3000MF -E -v "usb://..." \
  -P "/Library/Printers/PPDs/Contents/Resources/KONICA MINOLTA bizhub 3000MF (ARM).ppd.gz"
```

### Linux

用对应机型的 PPD 注册队列：

```bash
lpadmin -p Bizhub3000MF -E -v socket://打印机IP:9100 \
  -P "/usr/share/cups/model/konica/KONICA MINOLTA bizhub 3000MF (ARM).ppd"
lp -d Bizhub3000MF /etc/hosts
```

同型号的 2600P / 3080MF 请把 PPD 文件名换成对应的
`KONICA MINOLTA bizhub 2600P (ARM).ppd` 或 `... 3080MF (ARM).ppd`。

## 功能范围与验证状态

### 已验证（本机端到端）

- 过滤器是纯 arm64 Mach-O，只链接系统库 `libcups/libc++/libSystem`；
- macOS 自带链路（`cgpdftoraster`）输出 1 位单色栅格，过滤器正确产出
  `%-12345X@PJL`、`RESOLUTION`、`ECONOMODE`、`SOURCETRAY`、`MEDIATYPE`、
  `PAPER`、`*b1030m` 数据块；
- 600dpi / 1200HQ、A4 / Letter / 16K / Folio / 信封等纸型、纸盒、双面、省墨选项均正确映射。
- Linux 版端到端（CUPS Raster → `@PJL`）冒烟测试通过。

### 未验证（需要实机）

- 实机联机打印。请先用小文档试打，确认边距/分辨率/双面符合预期。
- 若实机拒绝此协议，可退回原厂路径：原厂 PPD + `rastertobh2600` 的 x86_64 部分
  在装了 Rosetta 2 的 Mac 上仍能打印。

### 不包含的功能

- 传真发送 PDE、状态监视器、耗材/维护工具以及扫描（见下文）。

## 扫描怎么办

这台机器是 Brother 代工的私有扫描协议，没有开源 arm64 扫描方案。可选：

- 原厂「KONICA MINOLTA Scanner B」ICA 应用是 x86_64，装 Rosetta 2 后可在
  「图像捕捉 / Image Capture」里扫描；
- 原厂 TWAIN 数据源是 i386-only，Apple Silicon 无法运行，忽略即可；
- 或用打印机的「扫描到网络文件夹 / 邮件」功能，不走 Mac 驱动。

Linux 端扫描不在本驱动范围内。

## 从源码构建

### macOS

需要 Xcode Command Line Tools：

```bash
xcode-select --install   # 如未安装
zsh build.sh
zsh build-pkg.sh         # 生成 .pkg
```

### Linux / 跨架构

- 本机 `.deb`：`./scripts/build-linux-deb.sh`
- 指定架构：`./scripts/build-linux-deb.sh amd64` / `./scripts/build-linux-deb.sh arm64`
- 全平台：打 tag 后由 `.github/workflows/release.yml` 自动构建 macOS + Linux 两个架构并上传。

## 卸载

### macOS

```bash
zsh uninstall.sh
```

### Linux

```bash
sudo rm -f /usr/lib/cups/filter/rastertobrlaser
sudo rm -rf /usr/share/cups/model/konica
sudo systemctl restart cups
```

## 许可证与来源

- 过滤器核心来自 [brlaser](https://github.com/pdewacht/brlaser) v6，
  Copyright © 2013 Peter De Wachter，GPL-2.0-or-later，完整 GPL 文本见
  `brlaser-upstream/COPYING`。
- 本项目对 brlaser 的适配修改（柯尼卡纸型映射、1200HQ 的 `RESOLUTION=1200`、
  macOS 双面/省墨选项兼容）同样以 GPL-2.0-or-later 发布。
- 本项目不含任何柯尼卡美能达/Brother 的闭源代码、LUT 或数据文件，与两家厂商无隶属关系。
- 驱动按原样提供，不附带任何担保；建议先试打一张再批量使用。
