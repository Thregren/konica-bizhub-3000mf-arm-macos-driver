# 扫描支持（开发中，v0.1）

为 KONICA MINOLTA bizhub 3000MF / 3080MF 增加 **arm64 原生**扫描能力，目标
是兼容 macOS「图像捕捉 / Image Capture」。

当前状态：**网络扫描已在实体 bizhub 3000MF 上验证通过**（150dpi / 300dpi
灰阶，平板）；ICA 设备模块已能编译，等待装入「图像捕捉」做界面联调。

## 目录结构

```text
protocol/     Brother ML13 网络扫描协议（TCP 54921）
cli/          brscan_cli：命令行扫描工具，用于协议验证和抓取设备行为
mock/         mock_server.py：本地模拟扫描仪，供无实体机测试
ica/          KMBizhubScanner.app：Image Capture 设备模块（arm64）
```

## 协议

这台机器是 Brother ML13 引擎的 GDI 一体机，扫描走私有 TCP 协议（端口
54921），与 Brother MFC-L2700DW 相同：

1. 连接后设备发送 `+OK 200`（忙时 `-NG 401`）
2. `\x1bI\nR=DPI,DPI\nM=GRAY64\n\x80` 请求能力（lease）
3. `\x1bX\nR=...\nM=...\nC=...\nJ=MID\nB=50\nN=50\nA=x,y,w,h\n\x80` 开始扫描
4. 图像数据按行分块：每行是 `0x40`（灰度）类型字节 + 9 字节行描述 +
   2 字节小端长度 + 像素数据；`0x82` 表示一页结束（后接 9 字节描述），
   `0x80` 表示整个作业结束

实机（`192.168.0.22`，固件 Bonjour 名称 `KMN94DDF872B852`）确认：

- 能力应答 `\x00\x1d\x00150,150,2,209,1240,291,1718,\x00` 等，字段为
  `dpiX,dpiY,adf,planeW,widthPx,planeH,heightPx`
- 台面有效扫描高度比标称值少 1~2 行（例如 300dpi 请求 3437 行、实际返回
  3435 行），CLI 与 ICA 模块会用最后一行补齐
- 空台面输出接近全白的灰阶图，端到端 PGM→PNG 验证正常

参考资料：

- <https://github.com/jmesmon/brother2/blob/master/PROTO>
- <https://github.com/corsmith/mfc-7820n>
- <https://github.com/thebino/brother-to-paperless>

## 构建

```bash
# 命令行扫描工具
clang++ -std=c++17 -O2 -arch arm64 -I protocol \
  cli/brscan_cli.cpp protocol/brscan.cpp -o build/brscan_cli

# ICA 设备模块
zsh ica/build.sh
```

## 本地测试（无需打印机）

```bash
python3 mock/mock_server.py --port 55421
# 另一个终端：
build/brscan_cli --ip 127.0.0.1 --port 55421 --dpi 300 --mode gray --out test
```

灰阶输出为 PGM（P5）文件，可用预览打开。

## 在 Image Capture 中使用

```bash
sudo rm -rf "/Library/Image Capture/Devices/KMBizhubScanner.app"
sudo cp -R "ica/build/KMBizhubScanner.app" "/Library/Image Capture/Devices/"
```

打印机需要以网络方式连接，并通过 Bonjour 广播 `_scanner._tcp`（原厂固件
自带）。打开「图像捕捉」后应能看到该扫描仪。

## 已知限制（待实机联调）

- 仅网络扫描；USB 传输尚未实现
- 仅 8 位灰阶；彩色（CGRAY+JPEG）与黑白文本模式待抓包确认后加入
- 概览/预览的数据格式需要在真实 Image Capture 中验证
- ADF 多页与取消流程需实测

## 许可证

- `protocol/`、`cli/`、`mock/` 为原创实现，GPL-2.0-or-later
- `ica/KMBizhubScanner/` 结构参考 Apple VirtualScanner 示例，示例许可见
  `ica/NOTICE-APPLE-SAMPLE`；本模块代码本身按项目 GPL-2.0-or-later 发布
