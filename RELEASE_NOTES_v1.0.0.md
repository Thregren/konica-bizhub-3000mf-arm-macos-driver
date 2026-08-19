# KONICA MINOLTA bizhub ARM macOS 打印驱动 v1.0.0

适用机型：`bizhub 2600P` / `3000MF` / `3080MF`  
适用系统：Apple Silicon (arm64) Mac，macOS 12 或更高版本

## 下载与安装

普通用户请下载：

`KONICA-MINOLTA-bizhub-2600P-3000MF-3080MF-ARM-v1.0.0.pkg`

双击 `.pkg` 安装。安装包未使用 Apple Developer ID 签名；如 macOS 拦截，
可在「系统设置 → 隐私与安全性」中确认打开，或使用：

```bash
sudo installer -pkg "$HOME/Downloads/KONICA-MINOLTA-bizhub-2600P-3000MF-3080MF-ARM-v1.0.0.pkg" -target /
```

## 安装后必须手动添加打印机

**安装包只会安装驱动文件，不会自动创建打印机。**

1. 打开「系统设置 → 打印机与扫描仪」，点击「添加打印机、扫描仪或传真机」。
2. 等待 macOS 搜索到 bizhub，然后选中该设备。
3. 在「使用」下拉框选择「选择软件…」。
4. 手动选择与机型对应的 `KONICA MINOLTA bizhub ... (ARM)` 驱动，
   然后点击「添加」。

不要使用 macOS 自动选中的 AirPrint 或「通用 PostScript 打印机」，
否则这类 GDI 机型无法正确打印。

## 包含内容

- arm64 原生 CUPS 过滤器 `rastertobrlaser`
- bizhub 2600P / 3000MF / 3080MF 三份专用 PPD
- 600dpi、1200HQ、双面、省墨、纸盒和常用纸型选项

## 限制

- 本 Release 的 `.pkg` 只包含打印驱动，不包含扫描、传真或状态监视工具。
- 请先用小文档试打，确认边距、分辨率和双面符合预期。
