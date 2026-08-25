# Changelog

本项目遵循 [Semantic Versioning](https://semver.org/)。

## [1.1.0] - 2026-08-25

新增 Linux 跨平台驱动与全平台构建。

### 新增

- Linux CUPS 过滤器 rastertobrlaser (x86_64 / aarch64)，源码位于 linux/
- Linux .deb 打包与安装脚本 (scripts/build-linux-deb.sh / install-linux.sh)
- GitHub Actions：打 tag 自动构建 macOS (.pkg) 与 Linux (.deb, amd64 + arm64)
- PPD 改为 Linux 相对 cupsFilter

### 已知限制

- 尚未在实体打印机上完成 Linux 端联机验证
- 不包含扫描、传真发送与状态监视功能（扫描仍在 codex/arm64-scanner-ica 分支开发）

## [1.0.0] - 2026-08-18

首个正式版本：Apple Silicon (arm64) 原生打印驱动。

### 新增

- 基于开源 brlaser v6 编译的 arm64 原生 CUPS 过滤器 `rastertobrlaser`
- KONICA MINOLTA bizhub 2600P / 3000MF / 3080MF 专用 PPD
- 支持 600dpi、1200HQ、双面、省墨模式
- 支持 A4、Letter、Legal、B5/JIS B5、16K、Folio、信封等纸型
- 提供安装 / 卸载脚本与本地验证脚本

### 已知限制

- 尚未在实体打印机上完成联机验证
- 不包含扫描、传真发送与状态监视功能
