# RK3568 Board1 开源项目

本仓库整理 RK3568 Board1 V1.0 的硬件设计资料，以及两条并列的软件路线：
Debian/Armbian 与 OpenWrt。项目面向板级移植、驱动开发和首次上电验证，不代表已经达到量产状态。

## 当前状态

| 项目 | 状态 |
| --- | --- |
| 原理图、GPIO、VCCIO 与 DNP 审计 | 已完成软件侧审计，硬件改版/实物 BOM 待确认 |
| Armbian | Debian 13 Trixie、Linux 6.18.49、U-Boot v2026.04 镜像构建成功 |
| OpenWrt | LEDE r7875 / Linux 6.12.103 历史镜像已归档；修正版 DTS 待重新编译 |
| TF 卡启动与板级接口 | 待实机验证 |
| eMMC 烧录与量产验证 | 未开始 |

> [!CAUTION]
> 首次上电前必须核对 R18、R46、RK809 SWOUT1 网络和 CAM0/RS485 冲突。软件不能修复电源短接、错误 strap 或 PCB 同网问题。

## 仓库结构

```text
RK3568_Project/
├── hardware/                 # 自有嘉立创 EDA 工程
├── software/
│   ├── Armbian/              # Armbian userpatches、构建说明与产物校验值
│   └── OpenWrt/              # OpenWrt 源码输入、历史镜像与构建信息
├── manual/                   # 芯片/参考设计资料（版权归原权利人）
├── tools/                    # Rockchip 与第三方工具
└── README.md
```

软件入口：

- [Armbian 构建与移植说明](software/Armbian/README.md)
- [Armbian 完整硬件审计/调试文档](software/Armbian/PORTING.md)
- [OpenWrt 构建与镜像说明](software/OpenWrt/README.md)

## 硬件摘要

- SoC：Rockchip RK3568
- 内存：LPDDR4X（具体颗粒和容量需以实物 BOM 为准）
- PMIC：RK809
- 启动介质：TF 卡、eMMC
- 网络：RTL8211F 千兆以太网
- 无线：AIC8800D40L USB 模块
- 显示/音频：HDMI、RK809 codec、预留 MIPI DSI/CSI
- 扩展：PCIe 2.0 x1、USB 3.0 Host、USB 2.0 Type-C Device、I2C/UART

## 上电前停止条件

以下任一项没有确认时，不应给主板上电：

1. R17 保持 0 Ω，R18 必须 DNP，避免 1.8 V 与 3.3 V 短接。
2. 建议 R46 DNP，使 `FLASH_VOL_SEL` 与 eMMC 1.8 V IO 一致。
3. RK809 SWOUT1 的输入 `VCC3V3_SYS` 与下游 `VCC_3V3` 必须是不同网络。
4. `CAM0_GPIO` 网上 GPIO3_D4 与 GPIO3_B5 不能同时配置为输出；当前软件选择 D4，禁用 B5。
5. Type-C 按 UFP/设备端使用，不应与 12 V 主输入形成未经确认的双路供电。

首次启动应使用 TF 卡、限流电源和 UART2 调试串口（`1500000 8N1`），确认 BootROM、DDR、U-Boot 和内核启动后再考虑 eMMC。

## 镜像说明

Armbian 完整镜像约 2.68 GiB，超过普通 GitHub 文件限制，因此仓库只保存可复现的构建输入、文件名和 SHA256，不把 `.img` 提交进 Git 历史。OpenWrt 的历史压缩镜像体积较小，保留在 `software/OpenWrt/images/`，但其旧 DTS 尚未包含最新硬件审计修正，使用前务必阅读对应 README。

## 第三方资料与许可证

设备树文件带有各自的 SPDX 标识。`manual/`、`tools/`、预编译镜像和固件可能受各自原厂许可证约束，本仓库的整理不改变其版权归属，也不自动授予再分发权。向公众发布或制作 Release 前，维护者仍应逐项确认第三方资料和二进制文件的授权范围。

## 贡献约定

- 涉及 GPIO、pinmux、regulator 或 VCCIO 的修改，必须注明原理图页码和网络名。
- 新增屏幕、触摸或摄像头节点时，应提供准确器件型号、公开资料依据和启动日志。
- 不提交构建缓存、密钥、访问令牌、无线凭据或未经授权的固件。
- 提交测试结果时，请同时给出硬件版本、镜像 SHA256、UART 日志和实际 BOM 差异。

## 免责声明

本项目按“现状”提供，不承诺适用于特定用途。打板、焊接、上电和烧录可能造成硬件损坏或数据丢失，使用者应自行完成电气、时序、信号完整性、散热和合规验证。
