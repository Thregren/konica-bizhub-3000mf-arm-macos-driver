# Changelog

本项目遵循 [Semantic Versioning](https://semver.org/)。

## [1.0.0] - 2026-08-18

首个正式版本：Apple Silicon (arm64) 原生打印驱动。

### 新增

- 基于开源 brlaser v6 编译的 arm64 原生 CUPS 过滤器 `rastertobrlaser`
- KONICA MINOLTA bizhub 2600P / 3000MF / 3080MF 专用 PPD
- 支持 600dpi、1200HQ、双面、省墨模式
- 支持 A4、Letter、Legal、B5/JIS B5、16K、Folio、信封等纸型
- 提供安装 / 卸载脚本与本地验证脚本
- GitHub Release 提供可直接交给 macOS Installer 的 `.pkg` 打印驱动安装包

### 已知限制

- 尚未在实体打印机上完成联机验证
- 不包含扫描、传真发送与状态监视功能
- 安装包只安装驱动文件；用户仍需在 macOS 中搜索并添加打印机，
  然后在「使用 → 选择软件…」中手动选择对应的 `(ARM)` 驱动
