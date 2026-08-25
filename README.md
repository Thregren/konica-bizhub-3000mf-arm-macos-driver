# 柯尼卡美能达 bizhub 2600P / 3000MF / 3080MF —— Apple Silicon (arm64) 原生打印驱动

> **v1.1.0（跨平台）**：现同时支持 macOS（Apple Silicon）与 **Linux（x86_64 / arm64）**，下载见 [Release v1.1.0](https://github.com/Thregren/konica-bizhub-3000mf-arm-macos-driver/releases/tag/v1.1.0)。
>
> **Linux 快速安装：**
> ```bash
> sudo dpkg -i konica-bizhub-2600p-3000mf-3080mf_1.1.0-1_$(dpkg --print-architecture).deb
> lpadmin -p Bizhub3000MF -E -v socket://打印机IP:9100 \
>   -P "/usr/share/cups/model/konica/KONICA MINOLTA bizhub 3000MF (ARM).ppd"
> ```

一个**纯 arm64、开源、无 Rosetta、不含厂商二进制**的 macOS CUPS 打印驱动。

## 先说结论（这个驱动到底解决了什么问题）

`bizhub_3000MF_3080MF_009_signed.dmg`（2017 年 7 月）里的原厂驱动经过解包分析：

- bizhub 3000MF 是 Brother 代工的 **GDI 主机型**打印机（USB VID/PID 为 Brother 的 `0x132B:0x235A`，引擎为 Brother ML13 系列）。
- 原厂打印路径是「PPD + CUPS 过滤器 `rastertobh2600`」。该过滤器**只有 x86_64/i386 版本，没有任何 arm64 版本**，柯尼卡官方也只支持到 macOS 10.12，之后从未发布 Apple Silicon 版。
- 扫描部分的 TWAIN 数据源是 **i386-only**，Apple Silicon 上即使装了 Rosetta 也跑不了；ICA 扫描应用是 x86_64，可以靠 Rosetta 运行。

本项目的做法不是把厂商闭源二进制「转码」，而是：

1. 确认这台机器的打印协议（PJL + Brother HBP 栅格，`*b1030m` 分带压缩）与开源项目 [brlaser](https://github.com/pdewacht/brlaser)（GPL-2.0+，Brother 激光打印协议的开源逆向实现）同族；
2. 用 brlaser 源码在本机编译出 **arm64 原生过滤器**，并为柯尼卡机型的纸型（含 16K、信封、Folio 等）做适配；
3. 为 bizhub 2600P / 3000MF / 3080MF 各写一份专用 PPD。

打印数据流完全由 macOS 自带组件 + 本项目编译的 arm64 过滤器完成，**不需要 Rosetta、不需要厂商的 `rastertobh2600`**。

## 目录结构

```text
src/                 适配后的 brlaser 过滤器源码（C++11）
brlaser-upstream/    上游 brlaser v6 源码（未修改，保留原样以便对照）
ppd/                 KONICA MINOLTA 三个机型的 PPD
dist/rastertobrlaser 已编译好的 arm64 过滤器（无外部依赖）
build.sh             本机编译脚本
install.sh / uninstall.sh   安装 / 卸载脚本
build-pkg.sh         可选：在本机生成 .pkg 安装包
```

## 安装

先决条件：Apple Silicon Mac、macOS 12 或更高版本、有管理员权限。

```bash
# 推荐方式（最透明）
cd "本目录"
zsh install.sh
```

也可以在本机生成 .pkg 安装包（未签名）：

```bash
zsh build-pkg.sh
sudo installer -pkg "dist/KONICA-MINOLTA-bizhub-3000MF-ARM-1.0.0.pkg" -target /
```

仓库默认不附带 .pkg 文件；需要时由 `build-pkg.sh` 现场生成。

安装内容：

- `/Library/Printers/KONICAMINOLTA/Filter/rastertobrlaser`（arm64）
- `/Library/Printers/PPDs/Contents/Resources/` 下的三份 `KONICA MINOLTA bizhub … (ARM).ppd.gz`

## 添加打印机

**图形界面：**

系统设置 → 打印机与扫描仪 → 添加打印机 → 选择设备 → 在「使用」下拉框选择「选择软件…」→ 选中 `KONICA MINOLTA bizhub 3000MF (ARM)`。

**网络打印（命令行，推荐）：**

```bash
lpadmin -p Bizhub3000MF -E -v socket://192.168.1.100:9100 \
  -P "/Library/Printers/PPDs/Contents/Resources/KONICA MINOLTA bizhub 3000MF (ARM).ppd.gz"
```

把 `192.168.1.100` 换成打印机 IP。打印一张测试页验证：

```bash
lp -d Bizhub3000MF /etc/hosts
```

**USB 打印：**

先查看设备 URI：

```bash
lpinfo --include-schemes usb -v
```

通常形如 `usb://KONICA%20MINOLTA/bizhub%203000MF?serial=...`，然后：

```bash
lpadmin -p Bizhub3000MF -E -v "上面查到的URI" \
  -P "/Library/Printers/PPDs/Contents/Resources/KONICA MINOLTA bizhub 3000MF (ARM).ppd.gz"
```

## 已验证和未验证的部分

**已验证（本机端到端）：**

- 过滤器是纯 arm64 Mach-O，只链接系统库 `libcups/libc++/libSystem`；
- macOS 自带链路（`cgpdftoraster`）输出 1 位单色栅格，过滤器正确产出 `%-12345X@PJL`、`RESOLUTION`、`ECONOMODE`、`SOURCETRAY`、`MEDIATYPE`、`PAPER`、`*b1030m` 数据块；
- 600dpi / 1200HQ、A4 / Letter / 16K / Folio / 信封等纸型、纸盒、双面、省墨选项均正确映射。

**未验证（需要实机）：**

- 与你的 3000MF 实际联机打印。协议与原厂过滤器同族，但请先用小文档试打，确认边距/分辨率/双面符合预期。
- 若实机拒绝此协议，可退回原厂驱动路径：原厂 PPD + `rastertobh2600` 的 x86_64 部分在装了 Rosetta 2 的情况下也能打印（Rosetta 不能运行其中的 i386 组件，但打印过滤器恰好是 x86_64）。

**不包含的功能：**

- 传真发送 PDE、状态监视器、耗材/维护工具、扫描（见下文）。

## 扫描怎么办

这台机器是 Brother 代工的私有扫描协议，没有开源的 arm64 扫描方案。可选：

- 原厂「KONICA MINOLTA Scanner B」ICA 应用是 x86_64，装 Rosetta 2 后可在「图像捕捉 / Image Capture」里扫描；
- 原厂 TWAIN 数据源是 i386-only，Apple Silicon 无法运行，忽略即可；
- 或用打印机的「扫描到网络文件夹 / 邮件」功能，不走 Mac 驱动。

## 卸载

```bash
zsh uninstall.sh
```

## 重新编译

需要 Xcode Command Line Tools：

```bash
xcode-select --install   # 如未安装
zsh build.sh
```

## 许可证与来源

- 过滤器核心来自 [brlaser](https://github.com/pdewacht/brlaser) v6，Copyright © 2013 Peter De Wachter，GPL-2.0-or-later，完整 GPL 文本见 `brlaser-upstream/COPYING`；
- 本项目对 brlaser 的适配修改（柯尼卡纸型映射、1200HQ 的 `RESOLUTION=1200`、macOS 双面/省墨选项兼容）同样以 GPL-2.0-or-later 发布；
- 本项目不含任何柯尼卡美能达/Brother 的闭源代码、LUT 或数据文件，与两家厂商无隶属关系；
- 请遵守打印机使用许可，本驱动按原样提供，不附带任何担保。建议先试打一张再批量使用。

## 贡献者

详见 [CONTRIBUTORS.md](CONTRIBUTORS.md)。本项目由以下成员协作完成：

- **Thregren** —— 项目发起、机型信息与需求
- **Codex**（OpenAI Codex）—— 驱动逆向分析、arm64 原生实现与验证
- **DeepSeek** —— 方案协作

## Linux / 全平台构建

本仓库同样提供 **Linux CUPS 驱动**，产物为 **x86_64 (amd64)** 与 **aarch64 (arm64)**
的 `.deb` 安装包。Linux 过滤器源码在 `linux/`（与 macOS 版同源的 brlaser 适配），
链接 `libcupsimage` + `libcups`，PPD 已改用相对 `*cupsFilter`，CUPS 会从标准
filter 目录自动解析。

### 在 Linux 上构建并安装

```bash
# 需要 build-essential、g++、libcups2-dev、libcupsimage2-dev
sudo ./scripts/install-linux.sh

# 或生成 .deb
./scripts/build-linux-deb.sh            # 当前架构
./scripts/build-linux-deb.sh amd64      # x86_64
./scripts/build-linux-deb.sh arm64      # ARM64
```

### 添加打印机（Linux）

```bash
lpadmin -p Bizhub3000MF -E -v socket://192.168.1.51:9100 \
  -P "/usr/share/cups/model/konica/KONICA MINOLTA bizhub 3000MF (ARM).ppd"
lp -d Bizhub3000MF /etc/hosts
```

### 全平台构建（GitHub Actions）

`.github/workflows/release.yml` 在打 tag 时自动构建并上传：

- macOS（Apple Silicon arm64）：`dist/KONICA-MINOLTA-bizhub-2600P-3000MF-3080MF-ARM-1.1.0.pkg`
- Linux x86_64（amd64）：`build/linux/amd64/*.deb`
- Linux aarch64（arm64）：`build/linux/arm64/*.deb`

本版本不包含扫描/传真功能；扫描相关的 ICA 组件仍在开发中（见
`codex/arm64-scanner-ica` 分支）。
