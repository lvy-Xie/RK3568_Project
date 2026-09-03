# RK3568 Board1（Schematic1）Armbian 移植指南

> 原理图版本：`SCH_Schematic1_2026-08-30.pdf` / Board1 V1.0<br>
> 软件目标：Debian 13 Trixie / Armbian `current` / Linux 6.18 / 主线 U-Boot v2026.04<br>
> 调试串口：UART2_M0，`1500000 8N1`

## 项目状态

| 项目 | 状态 |
| --- | --- |
| 原理图网络、GPIO、VCCIO 和 DNP 审计 | 已完成 |
| Linux 板级 DTS、内核和内核包 | Linux 6.18.49 与 DTB 包已成功生成 |
| U-Boot DTS、defconfig 和补丁 | U-Boot v2026.04 包已成功生成 |
| Armbian 板卡定义和 AIC8800 集成 | Trixie 整机镜像构建成功，三个 AIC8800 DKMS 模块已安装 |
| 上板启动、电源、接口和稳定性验证 | 未开始 |

这里的“已完成”不代表硬件已经验证。2026-09-02 的最终构建已经生成 U-Boot v2026.04、Linux 6.18.49、DTB、headers、AIC8800 DKMS 和 Debian 13 Trixie 整机镜像。当前最重要的边界是：**镜像尚未写卡，BootROM、DDR、U-Boot、内核启动和全部板级接口仍需实机验证**。

## 文档导航

- [快速开始](#快速开始)
- [已完成的修改](#已完成的修改)
- [按原理图配置的硬件](#按原理图配置的硬件)
- [有意没有启用的功能](#有意没有启用的功能)
- [编译前必须知晓的原理图问题](#编译前必须知晓的原理图问题)
- [DNP 审计结果](#dnp-审计结果)
- [编译前软件优化审查](#编译前软件优化审查)
- [下一步路线图](#下一步路线图)
- [编译、写卡与串口命令](#编译写卡与串口命令)
- [分阶段上板验收](#分阶段上板验收)
- [故障定位和日志采集](#故障定位和日志采集)
- [GitHub 开源发布流程](#github-开源发布流程)

## 快速开始

建议构建主机使用 Armbian/Debian 13（Trixie），至少 8 GB 内存和约 50 GB 可用磁盘；也可以在可用 Docker 的 Linux 主机上构建。构建 AIC8800 DKMS 驱动和固件时需要网络。

先把本目录的 `userpatches/` 合并到指定版本的 Armbian build 树，再生成 Debian 13 Trixie 命令行镜像：

```bash
export ARMBIAN_BUILD_DIR=/path/to/armbian-build
cp -a userpatches/. "$ARMBIAN_BUILD_DIR/userpatches/"
cd "$ARMBIAN_BUILD_DIR"
./compile.sh build BOARD=rk3568-schematic1 BRANCH=current RELEASE=trixie KERNEL_GIT=shallow BUILD_MINIMAL=no BUILD_DESKTOP=no KERNEL_CONFIGURE=no
```

镜像完成后通常位于 `output/images/`。必须确认输出文件名属于 `rk3568-schematic1` 后才能写卡；该目录可能还保存其他板卡的旧镜像。

本次已验证的构建产物：

```text
Armbian-unofficial_26.11.0-trunk_Rk3568-schematic1_trixie_current_6.18.49.img
大小：2868903936 bytes（约 2.68 GiB）
SHA256：934dcf5da4ddee93a7ff4aa566401764422ce1888d2e14c30c1bb68e59384091
构建耗时：10 分 04 秒（复用 U-Boot/内核缓存）
```

## 已完成的修改

| 文件 | 用途 |
| --- | --- |
| [`rk3568-schematic1.dts`](userpatches/kernel/archive/rockchip64-6.18/dt/rk3568-schematic1.dts) | Linux 板级设备树 |
| [`rk3568-schematic1.csc`](userpatches/config/boards/rk3568-schematic1.csc) | Armbian 板卡定义、U-Boot 版本、内核驱动选项、AIC8800 集成 |
| [`0001-add-schematic1-rk3568-board.patch`](userpatches/u-boot/v2026.04/board_rk3568-schematic1/0001-add-schematic1-rk3568-board.patch) | U-Boot 设备树、SPL/eMMC/TF 启动、PCIe 和 Type-C RockUSB 恢复配置 |
| [`aic8800-usb.conf`](userpatches/board-rk3568-schematic1/aic8800-usb.conf) | AIC8800 USB Wi-Fi/蓝牙驱动加载顺序及 Wi-Fi 参数 |

板卡定义会启用 Armbian 的 `radxa-aic8800` USB 扩展，并预装 BlueZ。编译主机需要能够访问网络，以下载对应的 DKMS 驱动和固件包。

## 按原理图配置的硬件

| 模块 | 配置 |
| --- | --- |
| 电源 | 12 V 输入、5 V/3.3 V 系统电源、TCS4525 CPU DCDC、RK809 全部 DCDC/LDO/SW 电源树与休眠状态 |
| PMIC | RK809，I2C0 地址 `0x20`，中断 GPIO0_A3，系统关机控制器和电源键驱动 |
| CPU/GPU | CPU 绑定 TCS4525，GPU 绑定 RK809 DCDC2 |
| eMMC | 8 bit、1.8 V IO、HS200/HS400、增强数据选通、硬件复位 |
| TF 卡 | SDMMC0 4 bit，GPIO0_A4 低有效插卡检测，RK809 SW2/LDO5 供电与电压切换 |
| 千兆网 | GMAC0 RGMII、RTL8211F-CG 地址 1、外部 125 MHz 输入、GPIO3_B7 复位、GPIO3_C0 低电平中断、PHY 内部收发延时 |
| HDMI | HDMI TX、DDC、HPD、CEC M0、VOP VP0 显示通路和 HDMI 音频 |
| 模拟音频 | RK809 I2S1_M0，差分麦克风、耳机和差分扬声器路由 |
| USB Type-A | USB3_HOST1（`usb_host1_xhci` + `usb2phy0_host` + COMBPHY1），USB2 + SuperSpeed，GPIO0_A6 控制 SY6280 5 V 开关 |
| USB Type-C | USB_OTG0 仅配置为 USB 2.0 固定设备模式；CC1/CC2 为 5.1 kΩ Rd，GPIO0_D6 由显式 GPIO pinctrl、下拉和 GPIO hog 固定为低电平，本地 5 V 源无法被普通驱动误开启；U-Boot 保留 RockUSB/UMS 恢复能力 |
| 板载无线 | AIC8800D40L：USB2_HOST2 对应 `usb_host0_ehci/ohci` + `usb2phy1_otg`；Wi-Fi 及模块版本可能提供的 USB HCI 蓝牙均走此 USB 链路 |
| PCIe | PCIe 2.0 x1 / COMBPHY2，M1 复用，CLKREQ GPIO2_D0、WAKE GPIO2_D1、PERST GPIO3_C1 |
| 按键 | SARADC0 Recovery 键；PMIC RESET/PWRON 为 RK809 硬件按键 |
| LED | GPIO0_C2 状态灯、GPIO0_A0 WLAN 灯，均经 PUMH9 三极管高电平点亮 |
| 扩展总线 | I2C1 触摸屏接口、I2C2_M1 摄像头接口、I2C3_M0 外接接口、UART2_M0 调试口 |
| CAM0/RS485 冲突网 | 选择 GPIO3_D4 作为 `CAM0_RESET_L` 并保持低电平复位；GPIO3_B5 被 GPIO hog 固定为输入，禁止作为 RS485_DIR 输出 |
| 背光 | PWM4 驱动 SY7201，默认亮度为 0，等待实际面板启用 |

内核配置额外确保了 Rockchip DWMAC、Realtek PHY、RK809、PCIe、USB PHY/DWC3、SARADC、PWM、ADC 按键、PWM 背光和 RK817 音频驱动可用。

## 有意没有启用的功能

- MIPI-DSI 屏幕：图纸只有连接器和背光电路，没有 LCD 型号、分辨率、时序、初始化命令、lane 速率及触摸 IC 型号。已准备 LCD 3.3 V、I2C1 和 PWM4，未编造 panel/touch 节点。
- MIPI-CSI 摄像头：图纸没有传感器型号、I2C 地址、电源时序和 MCLK 要求，因此只启用了 I2C2 总线。GPIO3_D4 已选作摄像头复位并暂时保持复位；取得传感器资料后，应删除 `cam0-reset-l-hog`，再由 sensor 节点通过 `reset-gpios` 正式接管 GPIO3_D4。
- NPU：当前主线 RK3568 设备树/驱动没有可安全启用的完整 NPU 节点，保留了 `vdd_npu` 电源轨但不创建虚假设备。
- GMAC1：只引出了 MDC/MDIO/复位/中断，没有完整 RGMII 数据线，不能作为第二个以太网口启用。
- RS485：图纸没有给出 UART 数据通道和收发器完整连接，同时方向脚与摄像头复位网冲突。
- AIC8800 UART 蓝牙路径：第 20 页 U19 的 9、10 脚虽然命名为 `UART0_RX`、`UART0_TX`，但两个管脚均画有绿色 NC 标记，实际没有接到 RK3568。设备树不启用 UART0，也不安装 `hciattach` 脚本或 UART 蓝牙服务。AIC USB 驱动本身包含 `aic_btusb_usb`，所以仍保留 BlueZ 和 USB 蓝牙模块；最终是否枚举 HCI 取决于所焊 D40L 版本及固件，可在首启后用 `bluetoothctl list` 确认。
- `PMIC_32KOUT_WIFI`：该网只出现在第 11 页 RK809 的 CLK32K 输出处，第 20 页 U19 没有连接 32 kHz 输入，因此不在 DTS 中创建虚假的 Wi-Fi 时钟消费者。

## 编译前必须知晓的原理图问题

这些问题不能通过设备树修复，打板前应先确认或改版：

1. 第 23 页的 `MIPI_CAM0_RST_L_GPIO3_D4` 与 `RS485_DIR_GPIO3_B5` 都接到 `CAM0_GPIO`。软件方案已经选择 GPIO3_D4：D4 属于 1.8 V 的 VCCIO6 域，更符合摄像头控制 IO；它以输出低电平保持摄像头复位。B5 属于 3.3 V 的 VCCIO5 域，现被固定为输入高阻，防止 Linux 和 U-Boot 下发生输出争用及 3.3 V 倒灌 1.8 V IO。量产板仍建议断开 B5，保留 D4 摄像头复位功能。
2. 第 11 页“无线模块电源选择”中的 R17 和 R18 都标成 0 Ω 且都没有 DNP：这会把 `VCC_1V8` 与 `VCC3V3_SYS` 直接短接。根据 GMAC0 所在的 VCCIO4 域及 RTL8211F 的 R64/R68 选配，正确装配应为 **R17 = 0 Ω、R18 = DNP**，使 `VCCIO_WL` 为 1.8 V。DTS 已按 1.8 V 配置，但软件无法修复两条电源轨的硬短路。
3. 第 4/14 页的 `FLASH_VOL_SEL` 与 eMMC IO 电压不一致：R44 把 `VCCIO_FLASH` 固定为 1.8 V，但 R45=10 kΩ、R46=2.2 kΩ 会把 GPIO0_A7 拉到约 0.60 V，即图纸说明中的低电平/3.3 V 选择。建议保持 **R45 = 10 kΩ、把 R46 改为 DNP**，使 strap 为高电平并选择 1.8 V。该 strap 在上电早期采样，设备树无法补救；当前 DTS 的 `vqmmc`/`vccio2-supply` 已按实际 eMMC 1.8 V IO 配置。
4. 第 11 页 RK809 `SWOUT1` 的输出网被命名为 `VCC3V3_SYS`，而 RK809 的 VCC9 输入和第 14 页 U6 外部 3.3 V Buck 输出也使用同名网。这会让负载开关输入、输出落在同一网络，开关被旁路并存在对输出脚反向供电的风险；第 14 页说明中写的目标名称其实是独立的 `VCC_3V3`。建议把 **SWOUT1 下游及其负载统一改为独立 `VCC_3V3`**，输入仍为 `VCC3V3_SYS`。DTS 已按这一设计意图保留独立且常开的 `vcc_3v3`，但软件不能修复 PCB 同网。
5. Type-C 的 CC1/CC2 使用 5.1 kΩ 下拉，端口被定义为 UFP/设备端，但电路又提供 GPIO0_D6 控制的本地 5 V VBUS 源。当前 DTS 强制采用 peripheral 模式，并用 GPIO hog 将 D6 锁为低电平；硬件上仍建议取消 U15 或明确做成不可装的 source 选项。
6. 第 24 页说明写明 RX 与 REFCLK 不应重复串联隔直电容，但图中 PCIe RXP/RXN 各串 100 nF，REFCLKP/N 各串 100 pF。应结合实际端点卡和 RK3568 PCIe 参考设计复核；尤其 100 pF REFCLK 电容值可疑。
7. 第 19 页 USB3_HOST1 的 SSTX 串联电容 C214/C215 标为 1 µF，明显不同于常见 USB 3.x/RK3568 参考设计采用的约 100 nF。软件无法补偿 AC 耦合值，建议在投板前按芯片参考设计和 USB 规范复核。
8. LPDDR4X 与 eMMC 的具体料号没有标出。U-Boot 使用 RK3568 通用 LPDDR4 训练固件，但量产前仍需按实际颗粒验证容量、频率和 HS400 稳定性。

## DNP 审计结果

已重新搜索并检查原理图中全部明确标注为 `DNP` 的位置。DTS 按“不焊接”处理，没有依赖这些器件形成的连接或默认电平。

| 页码/器件 | DNP 作用 | 软件处理 |
| --- | --- | --- |
| 第 6 页 R131 | GMAC0_RXD0 的可选 4.7 kΩ 下拉 | 未假定该下拉存在，RGMII 管脚只配置为 PHY 输入 |
| 第 17 页 C189 | PHY 125 MHz CLKOUT 路径的可选 18 pF 对地电容 | 按未安装处理，仍使用 RTL8211F 的 CLKOUT125 作为 GMAC0 外部时钟 |
| 第 17 页 R65 | RTL8211F RESET_N 的可选 4.7 kΩ 上拉 | GPIO3_B7 由驱动主动控制，并配置 20 ms/100 ms 复位时序；若要求上电阶段复位电平绝对确定，建议硬件补上拉 |
| 第 17 页 R68 | PHY IO 电源的可选 3.3 V 选择电阻 | R68 不装、R64 为 0 Ω，因此 VCCIO_PHY0 是 1.8 V；GMAC0 所在的 `vccio4-supply` 已配置为 1.8 V |
| 第 17 页 R78、R80 | RTL8211F RX/TX delay 的可选上拉 | 两个 DNP 与已装下拉共同形成低电平 strap；DTS 使用 `rgmii-id`，由 RTL8211F 驱动启用收发内部延时 |
| 第 17 页 R81、R83 | PLLOFF、PHYAD0 的可选下拉 | 按 DNP 处理；R84 上拉使 PHYAD0 为 1，结合 PHYAD1/2 下拉，PHY 地址配置为 `1` |
| 第 17 页 R88、R89 | CFG_EXT、CFG_LDO1 的可选 strap 电阻 | 按未安装处理，软件不覆盖对应电压/LED strap |

HDMI、USB ESD 芯片以及 AIC8800 UART 管脚上标注的 `NC` 是器件未连接管脚，不是 DNP 装配选项。尤其 U19 的 UART0_RX/TX 已按断开处理，设备树没有引用它们；这不妨碍同一模块通过 USB 复合接口提供蓝牙。

另外，本次审计发现两处“应当有 DNP、但图纸没有标”的位置：R17/R18 中必须将 R18 设为 DNP；FLASH_VOL_SEL 建议将 R46 设为 DNP。这两项优先级高于表中的普通选配器件，打板前必须同步修改原理图和 BOM。

## VCCIO 电压域交叉检查

| SoC 电压域 | 原理图目标电压 | DTS 电源 |
| --- | --- | --- |
| PMUIO1 / PMUIO2 | 3.3 V | `vcc3v3_pmu` |
| VCCIO1（模拟音频/I2S） | 3.3 V | `vccio_acodec` |
| VCCIO2（eMMC/FLASH） | 1.8 V | `vcc_1v8` |
| VCCIO3（TF 卡） | 1.8/3.3 V 动态切换 | `vccio_sd` |
| VCCIO4（GMAC0） | 1.8 V | `vcc_1v8` |
| VCCIO5（PCIe/部分 GPIO） | 3.3 V | `vcc_3v3` |
| VCCIO6（摄像头/显示控制） | 1.8 V | `vcc_1v8` |
| VCCIO7（HDMI CEC 等） | 3.3 V | `vcc_3v3` |

这里再次确认：DTS 电压域本身一致，问题位于硬件装配选项——R18 和 R46 漏标 DNP。修正这两处后，VCCIO4 与 VCCIO2 才会分别符合 1.8 V 设计。

## 首次启动建议检查

```bash
dmesg | grep -Ei 'rk809|mmc|stmmac|rtl8211|dw-pcie|aic|usb|error|fail'
lsblk
ip link
lsusb
lsusb -t
lspci -nn
aplay -l
bluetoothctl list
```

如果 RTL8211F 可以识别但千兆链路不稳定，应先测量 PHY 输出给 SoC 的 125 MHz 时钟，再根据 PCB 实测调整 PHY 内部 RGMII 延时。当前配置采用 `rgmii-id`，与原理图的 RTL8211F 时钟输入方式相符。

## 静态检查与首次构建结果

- Bash 语法检查通过。
- DTS 括号平衡及 phandle 标签静态引用检查通过。
- Linux DTS 与 U-Boot 补丁中携带的板级 DTS 逐字节一致。
- U-Boot 补丁 `git apply --check` 通过。
- U-Boot defconfig 中引用的全部 Kconfig 符号均可在 v2026.04 源码中解析。
- USB 控制器/PHY 映射已按 RK3568 基础 DTS 交叉检查：HOST1 为 `usb_host1_xhci`/`usb2phy0_host`，HOST2 为 `usb_host0_ehci/ohci`/`usb2phy1_otg`，未连接的 HOST3 保持关闭。
- PDF 文本层共检出 10 处 `DNP` 标记，均已逐项列入上面的 DNP 表；另行检查了 U19 UART 的 NC 标记。
- 已确认成品配置、U-Boot 补丁和板级资产中不存在 UART0 或旧 UART 蓝牙服务的残留引用。
- 首次构建的 `arch-test arm64` 已返回 `arm64: ok`，板卡定义被正确读取，U-Boot v2026.04 源码和 RKBin 已取得，本板 U-Boot 补丁已成功应用。
- 首次构建在 U-Boot `syncconfig` 阶段发现 `FASTBOOT_BUF_ADDR` 为空并进入交互菜单，随后由用户用 `Ctrl+C` 中止；该问题已修复。
- 后续构建成功生成 U-Boot v2026.04、Linux 6.18.49、DTB、headers 和 libc-dev 包，证明本板 U-Boot/DTS/内核配置已越过编译阶段。
- Bookworm 根文件系统使用 GCC 12.2 编译 AIC8800 DKMS，而内核由 GCC 14.2 构建，导致旧编译器不识别 `-fmin-function-alignment=8`；Bookworm 版本的完整镜像因此未生成。
- 改用 Debian 13 Trixie 后，AIC8800 的 `aic_load_fw_usb.ko`、`aic8800_fdrv_usb.ko` 和 `aic_btusb_usb.ko` 均完成构建、安装和 `depmod`；整机镜像随后成功生成。
- 产物 SHA256 已重新计算，并与 Armbian 生成的 `.img.sha` 文件一致。

## 编译前软件优化审查

### 已落实的确定性优化

1. **修正 Armbian 内核配置 hook 的两阶段调用。** `custom_kernel_config` 在计算构建哈希时可能还没有内核源码和 `.config`。板卡定义已改用框架的 `opts_y`/`opts_m` 聚合数组；框架会在哈希阶段只记录配置，在真正存在 `.config` 时再调用 `scripts/config`。这也避免了逐项启动几十个子进程。
2. **补齐 U-Boot PCI 基础配置。** 原 defconfig 有 PCIe/NVMe 驱动和 `pci` 命令，但遗漏 `CONFIG_PCI=y`；现已补齐，避免依赖项把 PCIe 相关选项静默丢弃。
3. **增加无系统时的恢复通道。** U-Boot 已启用 `rockusb`、USB Mass Storage 和 RockUSB gadget。Type-C 物理上是 UFP，适合在串口进入 U-Boot 后作为恢复接口，同时仍禁止板端输出 VBUS。
4. **强化 Type-C VBUS source 保护。** GPIO0_D6 不再只依靠 GPIO hog，还显式设置为 GPIO 功能并启用内部下拉。Linux 与 U-Boot 使用同一份板级 DTS，两个阶段的行为保持一致。
5. **显式保留启动和验收所需驱动。** 内核配置聚合项覆盖 PMIC/regulator、eMMC/TF、RTL8211F、PCIe、USB host/gadget、ADC key、HDMI、RK809 音频、LED 和背光，减少上游默认配置变化造成的功能丢失。
6. **关闭未使用的 U-Boot Fastboot。** RK3568 架构会隐式选择 `USB_FUNCTION_FASTBOOT`，但 v2026.04 没有为 RK3568 提供 `FASTBOOT_BUF_ADDR` 默认值，从而在非交互构建中反复询问地址。本板恢复方案使用 RockUSB 和 USB Mass Storage，defconfig 现已明确设置 `# CONFIG_USB_FUNCTION_FASTBOOT is not set`；RockUSB/UMS 不受影响。

### 首次编译前仍需接受的限制

- `compatible = "schematic1,rk3568-board1"` 使用的是本项目临时命名空间，适合本地构建，但不适合直接向 Linux 上游提交。准备上游时应替换为真实厂商/项目前缀，并同步设备树 binding。
- `radxa-aic8800` 扩展从 GitHub 的 latest release 下载 DKMS 和固件包，因此首次构建依赖网络，且不同日期可能得到不同版本。首次成功构建后，应记录下载文件名和 SHA256；发布可复现版本时再固定驱动版本或保存有授权的构建依赖。
- LCD、触摸、摄像头料号仍未知，保持未绑定比加入猜测节点更安全。
- LPDDR4X 和 eMMC 的实际料号仍未知，无法在编译前安全收紧 DDR 频率或删除 HS400；这两项应根据首次串口训练结果和实测稳定性决定。
- U-Boot patch 目前是 Armbian 本地集成形式。准备向 U-Boot 上游提交时，还需要正式 commit message、Signed-off-by、MAINTAINERS 条目和板级文档；这些不影响本地首次构建。

### 构建后立即检查的配置结果

构建成功不等于请求的 Kconfig 最终生效。构建后应从日志检查 unknown symbol、依赖降级和 patch fuzz：

```bash
grep -Ein 'unknown symbol|undefined reference|not in final \.config|patch failed|reject|warning:|error:' build-rk3568-schematic1.log
```

镜像启动后还应保存最终内核配置，确认关键符号：

```bash
zgrep -E 'CONFIG_(REALTEK_PHY|PCIE_ROCKCHIP_DW_HOST|DWMAC_ROCKCHIP|MFD_RK8XX_I2C|MMC_SDHCI_OF_DWCMSHC|USB_DWC3|SND_SOC_RK817)=' /proc/config.gz
```

进入 U-Boot 后可用下面的只读命令确认基础总线；不要在未确认设备号时执行写操作：

```text
mmc list
usb start
usb tree
pci enum
pci
```

需要恢复时，可在确认 eMMC 设备号后手动运行 `rockusb 0 mmc <设备号>`，或者使用 `ums 0 mmc <设备号>` 暴露块设备。两者都属于维护操作，不应加入默认自动启动流程。

## 下一步路线图

建议严格按下面顺序推进。前一阶段没有通过时，不要同时调试后一阶段，否则电源、DDR、存储和驱动问题会混在一起。

| 阶段 | 目标 | 通过标准 | 未通过时的动作 |
| --- | --- | --- | --- |
| P0 原理图/BOM 收口 | 排除上电即损坏或电源互短 | R18、R46、SWOUT1 网络和 Type-C 供电处理已落实，并确认 CAM0 冲突网只保留一个有效输出 | 停止编译和上电，先改原理图/BOM/PCB |
| P1 构建 | 得到本板专用镜像 | 命令退出码为 0，输出文件名含 `Schematic1`，构建日志无 patch reject | 保存完整日志，先修复第一个真正错误 |
| P2 最小启动 | 验证 BootROM、SPL、DDR、U-Boot、内核串口 | UART2 可连续看到 SPL/U-Boot/Kernel，系统进入登录提示 | 只检查电源、晶振、DDR、启动介质和串口 |
| P3 核心资源 | 验证 PMIC、regulator、eMMC/TF 和设备树型号 | 无 regulator 循环依赖/欠压，根文件系统稳定，型号正确 | 暂不接 USB、PCIe、屏幕和摄像头 |
| P4 基础接口 | 验证以太网、USB Host、AIC8800、PCIe | 各总线稳定枚举，无持续 reset/disconnect/AER | 一次只接一个外设并保留日志 |
| P5 多媒体 | 验证 HDMI、HDMI 音频、RK809 模拟音频 | 显示模式稳定、音频设备可枚举和播放 | 分开检查 DRM、I2S、codec 和路由 |
| P6 稳定性 | 验证温度、供电、存储和网络压力 | 连续运行无崩溃、掉盘、降压复位和链路抖动 | 结合示波器、电源日志和内核日志定位 |
| P7 补齐未知器件 | 增加 LCD、触摸和摄像头 | 获得准确料号、datasheet、时序和上电顺序后单独提交 | 不使用猜测参数合入主分支 |
| P8 开源发布 | 让第三方可复现并可提交问题 | 源码、版本、已知问题、构建命令、日志要求和许可证齐全 | 不发布无授权原理图或私密生产资料 |

### P0：上电前的硬件停止条件

以下四项任一未确认，都不建议给主板上电：

1. R18 必须 DNP，R17 保持 0 Ω，不能把 1.8 V 与 3.3 V 电源短接。
2. R46 建议 DNP，使 `FLASH_VOL_SEL` 与 1.8 V eMMC IO 一致。
3. RK809 SWOUT1 输入 `VCC3V3_SYS` 和下游 `VCC_3V3` 必须是不同网络，或明确按改版方案处理。
4. `CAM0_GPIO` 冲突网上不能让 GPIO3_D4 和 GPIO3_B5 同时成为输出；现有软件选择 D4、禁用 B5，但还应检查 PCB 实物连接。

首次上电建议使用带限流和电流显示的实验电源。不要在 Type-C 和 12 V 主输入之间形成两个未经确认的供电源；当前 Type-C 软件定义为设备端，不能把它当作板卡主供电输出验证。

## 编译、写卡与串口命令

本节是给后续实际操作使用的命令清单。文档维护本身不会自动执行编译或写卡；上面记录的成功状态来自 2026-09-02 的用户构建日志。

### 1. 构建前记录环境

```bash
cd "$ARMBIAN_BUILD_DIR"
git rev-parse --short HEAD
git status --short
df -h .
free -h
nproc
```

当前适配时使用的 Armbian build 基线提交是 `fe0ad5fdf`。后续若更新上游导致构建失败，应先在 issue 中同时给出新旧提交号。

### 2. 构建完整命令行镜像

首次在 x86_64 主机上构建 arm64 镜像前，先确认 Docker 和 AArch64
`binfmt` 可用：

```bash
docker info >/dev/null
update-binfmts --display qemu-aarch64 | sed -n '1,8p'
arch-test arm64
```

`arch-test arm64` 必须返回 `arm64: ok`（不同版本的措辞可能略有差异），不能是
`arm64: not supported on this machine/kernel`。如果不满足，先按本文“Docker 在数秒内退出”一节修复宿主机，不要反复启动构建。

```bash
cd "$ARMBIAN_BUILD_DIR"
set -o pipefail
./compile.sh build \
  BOARD=rk3568-schematic1 \
  BRANCH=current \
  RELEASE=trixie \
  KERNEL_GIT=shallow \
  BUILD_MINIMAL=no \
  BUILD_DESKTOP=no \
  KERNEL_CONFIGURE=no \
  2>&1 | tee build-rk3568-schematic1.log
```

`set -o pipefail` 很重要：即使输出经过 `tee`，构建失败仍会保留非零退出状态。第一次构建不要开启桌面，也不要同时变更内核配置，以减少变量。

### 3. 确认产物身份

```bash
find output/images -maxdepth 1 -type f -iname '*schematic1*' -printf '%TY-%Tm-%Td %TH:%TM  %9s  %f\n' | sort
```

如果这条命令没有输出，不要从 `output/images/` 随便选择其他文件。当前目录可能存在 Rock-3A 等其他板卡的旧镜像，它们不属于本项目。

对实际生成的文件执行完整性检查。把示例路径替换为上一步确认过的本板镜像：

```bash
IMAGE_PATH='output/images/Armbian-...-Schematic1-...img'
file "$IMAGE_PATH"
sha256sum "$IMAGE_PATH" | tee "$IMAGE_PATH.sha256"
```

如果产物是 `.img.xz`，写卡前先检查压缩包：

```bash
xz -t 'output/images/Armbian-...-Schematic1-...img.xz'
```

### 4. 写入 TF 卡

> **危险：下面的 `dd` 会覆盖整个目标块设备。** 必须用容量、型号和传输类型三项共同确认目标卡；`/dev/sdX` 只是占位符，绝不能原样执行，也不要把系统盘或某个分区（如 `/dev/sdX1`）当成目标。

先识别设备并卸载该卡上已经挂载的每个分区：

```bash
lsblk -o NAME,PATH,SIZE,MODEL,SERIAL,TRAN,TYPE,MOUNTPOINTS
sudo umount /dev/sdX1
sudo umount /dev/sdX2
```

未压缩 `.img` 的写入命令：

```bash
sudo dd if='output/images/Armbian-...-Schematic1-...img' of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

压缩 `.img.xz` 的写入命令：

```bash
set -o pipefail
xzcat 'output/images/Armbian-...-Schematic1-...img.xz' | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

写卡完成后重新执行 `lsblk`，确认分区出现在目标卡而不是系统盘。

### 5. 连接调试串口

UART2_M0 为 3.3 V TTL 逻辑，参数为 1500000 波特、8 数据位、无校验、1 停止位。USB-TTL 适配器只连接 `GND`、板卡 `TX` 和板卡 `RX`，不要连接适配器的 5 V 电源脚。

```bash
sudo apt-get install picocom
picocom --baud 1500000 --databits 8 --parity n --stopbits 1 /dev/ttyUSB0
```

退出 picocom 使用 `Ctrl-A` 后按 `Ctrl-X`。需要保留首次启动原始输出时可运行：

```bash
script -f uart-first-boot.log -c 'picocom --baud 1500000 /dev/ttyUSB0'
```

最初几次启动应保留从上电前开始的完整串口记录，不要只截取最后一条错误。

## 分阶段上板验收

下面部分使用的诊断工具可以按需安装；缺少某个工具不代表对应硬件不存在：

```bash
sudo apt-get update
sudo apt-get install alsa-utils bluez ethtool gpiod iperf3 libdrm-tests mmc-utils pciutils usbutils
```

### P2：最小启动验收

第一次只插 TF 卡和调试串口，不接 PCIe、USB 外设、屏幕、摄像头和网线。按顺序确认：

1. BootROM 找到启动介质。
2. SPL 完成 LPDDR4X 初始化，容量与实装颗粒一致。
3. U-Boot 显示 `Schematic1 RK3568 Board1`，可以看到 eMMC/TF。
4. 内核使用 `rk3568-schematic1.dtb` 并进入用户空间。
5. 串口没有反复复位、乱码或长时间无输出。

登录后先记录系统身份：

```bash
uname -a
cat /etc/armbian-release
tr -d '\0' < /proc/device-tree/model; echo
tr -d '\0' < /proc/device-tree/compatible; echo
cat /proc/cmdline
sudo journalctl -k -b --no-pager > kernel-first-boot.log
```

如果设备树型号不是 `Schematic1 RK3568 Board1`，先解决镜像、启动脚本或 DTB 选择问题，不要继续做接口测试。

### P3：PMIC、电源和存储

```bash
sudo dmesg | grep -Ei 'rk809|regulator|voltage|under.?voltage|thermal|error|fail'
mountpoint -q /sys/kernel/debug || sudo mount -t debugfs debugfs /sys/kernel/debug
sudo cat /sys/kernel/debug/regulator/regulator_summary
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL
findmnt
sudo dmesg | grep -Ei 'mmc|sdhci|dwcmshc|hs200|hs400|timeout|crc|error'
```

安装 `mmc-utils` 后，可读取 eMMC 的只读 EXT_CSD 信息。必须先从 `lsblk` 确认哪个节点是真正的 eMMC：

```bash
sudo apt-get install mmc-utils
for node in /sys/block/mmcblk*/device/type; do printf '%s: ' "$node"; cat "$node"; done
sudo mmc extcsd read /dev/mmcblkX
```

首轮不要直接进行破坏性写压力测试。先观察 30 分钟空载日志、温度和电源，再逐步增加负载。

### P4：千兆以太网

```bash
ip -br link
ip -br address
ip route
sudo ethtool eth0
sudo ethtool -S eth0
sudo dmesg | grep -Ei 'stmmac|gmac|rtl8211|mdio|link|timeout|error'
```

确认协商为 1000 Mb/s 后再做网络测试：

```bash
ping -c 20 '<局域网网关地址>'
iperf3 -c '<局域网内的 iperf3 服务端地址>' -t 60
iperf3 -c '<局域网内的 iperf3 服务端地址>' -t 60 -R
```

如果只能协商 100 Mb/s 或千兆丢包，优先检查 125 MHz 时钟、RGMII 走线、PHY 电源和内部 delay；不要先用软件不断随机调整延时掩盖硬件问题。

### P4：USB Type-A、Type-C 和 AIC8800

先在无外设状态保存一次基线，再分别插入一个设备：

```bash
lsusb
lsusb -t
sudo dmesg --follow
```

Type-A 应出现 USB 2.0/3.x 分层。Type-C 固定为 peripheral/UFP 模式；仅设置 `dr_mode = "peripheral"` 不会自动创建 USB gadget 功能。可在确认内核模块存在后，用 USB 网卡 gadget 做最小枚举测试：

```bash
sudo modprobe g_ether
lsmod | grep -E 'g_ether|libcomposite'
```

测试期间不要开启板端 Type-C VBUS source。若主机完全检测不到设备，再检查 D+/D-、CC 下拉和 VBUS 检测。

AIC8800 的 Wi-Fi 和可能存在的蓝牙接口都走 USB2_HOST2，不应出现 UART `hciattach`：

```bash
lsusb -nn
lsmod | grep -E 'aic|cfg80211|btusb'
modinfo aic8800_fdrv_usb
sudo dmesg | grep -Ei 'aic|firmware|wlan|bluetooth|hci|usb|error|fail'
rfkill list
nmcli radio wifi on
nmcli device wifi list
bluetoothctl list
```

Wi-Fi 枚举成功但 `bluetoothctl list` 为空，并不自动说明 DTS 错误；要继续核对所焊 AIC8800D40L 子型号、USB 描述符、驱动和固件是否提供 HCI 接口。

### P4：PCIe

先断电安装端点卡，再上电测试：

```bash
lspci -nn
sudo lspci -nnvv
sudo dmesg | grep -Ei 'pcie|pci |link up|aer|timeout|error|fail'
```

如果链路不起，优先用示波器和原理图复核 PERST、REFCLK、端点供电、100 pF REFCLK 隔直电容和 RXP/RXN 电容位置；设备树不能修复差分链路硬件问题。

### P5：HDMI 和音频

```bash
ls -l /dev/dri/
modetest -M rockchip
cat /sys/class/drm/card*-HDMI-A-*/status
cat /sys/class/drm/card*-HDMI-A-*/modes
aplay -l
arecord -l
amixer -c 0 scontrols
sudo dmesg | grep -Ei 'drm|vop|hdmi|edid|i2s|rk817|codec|audio|error|fail'
```

只有在 `aplay -l` 明确确认卡号和设备号后，才使用对应设备做播放测试：

```bash
speaker-test -D 'plughw:<card>,<device>' -c 2 -t sine
```

模拟扬声器、耳机和 HDMI 音频应分开验收，以免把 codec 路由和 HDMI DRM 问题混为一谈。

### P4/P5：GPIO 竞争保护确认

安装 `gpiod` 后确认三个保护线已经被内核占用：

```bash
sudo apt-get install gpiod
gpioinfo | grep -E 'cam0-reset-l|rs485-dir-disabled|usb-otg-vbus-source-disabled'
```

预期结果：

- `cam0-reset-l` 为输出低，摄像头在未知型号阶段保持复位。
- `rs485-dir-disabled-cam0-shared` 为输入，避免与 D4 输出竞争。
- `usb-otg-vbus-source-disabled` 为输出低，禁止 Type-C 本地 VBUS source。

后续增加正式摄像头节点时，必须先删除 `cam0-reset-l-hog`，再让传感器驱动独占 GPIO3_D4；不能让 hog 和 sensor 同时申请同一根线。

### P6：温度和稳定性

先连续观察温度：

```bash
watch -n 2 'for zone in /sys/class/thermal/thermal_zone*; do printf "%s " "$(cat "$zone/type")"; cat "$zone/temp"; done'
```

基础接口全部通过后，才进行 CPU、内存、网络和存储压力测试。建议每次只增加一种负载，并在另一个串口窗口持续运行：

```bash
sudo journalctl -k -f
```

CPU 压力示例：

```bash
sudo apt-get install stress-ng
stress-ng --cpu 4 --timeout 30m --metrics-brief
```

存储写入压力会消耗闪存寿命并破坏测试文件，必须在确认目标挂载点、备份数据和供电稳定后另行制定，不应把根文件系统或未知块设备直接交给 `fio`。

## 故障定位和日志采集

### Docker 在数秒内退出：AArch64 binfmt 不可用

如果外层显示 `Docker run failed after 5s`，日志同时包含以下内容：

```text
update-binfmts --enable qemu-aarch64 ... error code 2
arch-test arm64
arm64: not supported on this machine/kernel
```

说明构建尚未进入 U-Boot、内核或设备树编译，故障属于 x86_64 构建主机的
QEMU/binfmt 环境，不能据此判断板卡补丁有问题。先在宿主机执行：

```bash
sudo apt-get update
sudo apt-get install --reinstall qemu-user-static binfmt-support arch-test
sudo modprobe binfmt_misc
sudo systemctl restart binfmt-support.service
sudo update-binfmts --import qemu-aarch64
sudo update-binfmts --enable qemu-aarch64
update-binfmts --display qemu-aarch64 | sed -n '1,8p'
arch-test arm64
```

如果 `update-binfmts` 仍提示只读，先检查挂载状态：

```bash
findmnt -no TARGET,FSTYPE,OPTIONS /proc/sys/fs/binfmt_misc
```

只有输出明确含 `ro` 时，才执行以下修复，然后重新注册：

```bash
sudo mount -o remount,rw /proc/sys/fs/binfmt_misc
sudo systemctl restart binfmt-support.service
sudo update-binfmts --enable qemu-aarch64
arch-test arm64
```

宿主机检查通过后，再确认同一个处理器在特权容器里可见：

```bash
docker run --rm --privileged \
  ghcr.io/armbian/docker-armbian-build:armbian-debian-trixie-latest \
  arch-test arm64
```

宿主机和容器中的 `arch-test arm64` 都通过后，再原样重跑构建命令。Armbian 会复用已存在的下载和 Docker 缓存，无需删除 `cache/`、`output/` 或重新制作板卡补丁。

如果宿主机返回 `arm64: ok`、但特权容器仍返回 `not supported`，说明 Docker 运行时限制了容器内的 binfmt；可绕过 Docker，使用框架自身的 sudo 重启方式在宿主机原生构建：

```bash
./compile.sh build \
  PREFER_DOCKER=no \
  BOARD=rk3568-schematic1 \
  BRANCH=current \
  RELEASE=trixie \
  KERNEL_GIT=shallow \
  BUILD_MINIMAL=no \
  BUILD_DESKTOP=no \
  KERNEL_CONFIGURE=no
```

不要执行 `sudo ./compile.sh`；由脚本按需请求 sudo。无论选择 Docker 还是原生方式，`arch-test arm64` 都必须先通过，不能跳过或屏蔽这项检查。

### AIC8800 DKMS 报 `-fmin-function-alignment=8`

如果日志显示内核由 GCC 14.2 构建，而 AIC8800 DKMS 使用 Bookworm 的 GCC
12.2，并报以下错误：

```text
gcc: error: unrecognized command-line option '-fmin-function-alignment=8'
```

说明设备树、U-Boot、内核和 headers 包已经构建完成，失败仅位于目标根文件系统中的外置无线模块编译。不要删除已生成的内核包，也不要通过删除编译参数或跳过 DKMS 得到一个缺少板载无线驱动的镜像。本项目默认改用 Debian 13 Trixie；其 GCC 14.2.0-19 与本次内核编译器完全一致：

```bash
./compile.sh build \
  BOARD=rk3568-schematic1 \
  BRANCH=current \
  RELEASE=trixie \
  KERNEL_GIT=shallow \
  BUILD_MINIMAL=no \
  BUILD_DESKTOP=no \
  KERNEL_CONFIGURE=no
```

框架会复用 `output/debs/` 中已经完成的 U-Boot 和 Linux 6.18.49 包，重新创建 Trixie 根文件系统并编译 DKMS。首次取得的 AIC8800 软件包版本和校验值为：

```text
aic8800-usb-dkms_5.0+git20260123.5f7be68d-8_all.deb
SHA256 c344650979a3a6d2578e620eb52f766c4719a0577ac4e2959380e7f5ebfd964d

aic8800-firmware_5.0+git20260123.5f7be68d-8_all.deb
SHA256 5f58bc002f4e43c683e36a40cbd1fb9fb26633bfe998ffee5b1fbd42a0400eb7
```

### 按启动阶段判断故障范围

| 最后可见位置 | 首要排查方向 |
| --- | --- |
| 串口完全无输出 | 12 V/PMIC/时钟/复位、UART 电平与 TX/RX、BootROM 启动介质 |
| 停在 SPL/DDR | LPDDR4X 料号、供电、布线、训练固件和焊接 |
| 进入 U-Boot、找不到 TF/eMMC | mmc pinctrl、电源、卡检测、FLASH_VOL_SEL、器件焊接 |
| 内核启动前停住 | DTB 选择、boot script、内核加载地址和串口参数 |
| 内核启动后反复 probe defer | regulator/phandle/时钟/复位依赖 |
| 进入用户空间但接口缺失 | 驱动配置、模块、固件、总线枚举和实际 BOM |

### 采集可提交到 issue 的日志

```bash
mkdir -p bringup-logs
uname -a > bringup-logs/uname.txt
cat /etc/armbian-release > bringup-logs/armbian-release.txt
tr -d '\0' < /proc/device-tree/model > bringup-logs/dt-model.txt
tr -d '\0' < /proc/device-tree/compatible > bringup-logs/dt-compatible.txt
sudo journalctl -k -b --no-pager > bringup-logs/kernel.log
sudo dmesg > bringup-logs/dmesg.txt
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL > bringup-logs/lsblk.txt
ip -details link > bringup-logs/ip-link.txt
lsusb -t > bringup-logs/lsusb-tree.txt
lspci -nnvv > bringup-logs/lspci.txt
```

如果安装了 `device-tree-compiler`，还可导出内核运行时真正使用的设备树：

```bash
sudo apt-get install device-tree-compiler
sudo dtc -I fs -O dts -o bringup-logs/running.dts /sys/firmware/devicetree/base
```

发布日志前应检查并遮盖 MAC 地址、IP 地址、序列号、Wi-Fi SSID、用户名以及可能存在的密钥路径。不要只发照片；同时附上原始文本日志、复现步骤和首次失败时间点。

### Issue 最小信息模板

```text
硬件版本：Board1 V1.0 / PCB revision / 实际 BOM 变更
软件基线：Armbian build commit
镜像文件名与 SHA256：
供电方式与限流值：
启动介质：TF / eMMC
已连接外设：
期望结果：
实际结果：
稳定复现步骤：
完整 UART 日志：
kernel.log / running.dts：
示波器或万用表实测：
```

## GitHub 开源发布流程

### 推荐公开的内容

- 本板 Linux DTS、U-Boot 补丁、Armbian 板卡定义和 AIC8800 配置。
- 本文档、构建基线、完整命令、已知限制和验证状态。
- 确认不敏感的 UART/内核日志和接口测试结果。
- 能公开且有明确再分发授权的硬件资料。

不要默认公开原理图 PDF、Gerber、BOM、芯片固件或厂商资料。只有在确认自己拥有发布权，并选定硬件许可证后才提交这些文件。设备树采用 `(GPL-2.0+ OR MIT)` SPDX；当前 Armbian build 仓库整体带有 GPL-2.0 `LICENSE`。如果以后独立发布硬件设计，应另外明确硬件许可证（例如 CERN-OHL 系列）及文档许可证，不能只依赖 DTS 的 SPDX。

### 在本项目仓库中创建提交

本项目已经把 Armbian 板级输入独立保存在 `software/Armbian/`，不需要提交完整的 Armbian build 源码、缓存或输出目录。提交前执行：

```bash
cd /path/to/RK3568_Project
git add README.md software/Armbian software/OpenWrt
git status --short
git diff --cached --check
git diff --cached --stat
git diff --cached
```

逐项检查暂存区后再提交：

```bash
git commit -m 'software: organize Armbian and OpenWrt support'
```

确认 `origin` 指向本项目后推送：

```bash
git remote -v
git push origin main
```

### Pull Request 建议

PR 标题可使用：

```text
board: add RK3568 Schematic1 support
```

PR 正文至少说明：

- 原理图/PCB revision 和实际 BOM 差异。
- Armbian、Linux、U-Boot 基线版本。
- 已编译/已上板/未验证的边界，不把静态检查写成硬件通过。
- R18、R46、SWOUT1、Type-C 和 CAM0/RS485 冲突的处理结果。
- 每个已测接口的命令、结果与日志链接。
- LCD、触摸、摄像头、NPU、GMAC1 和 RS485 尚未启用的原因。

### 面向贡献者的约束

1. 一个提交只处理一个可验证主题，例如“启用某型号摄像头”或“修正 RGMII delay”。
2. 涉及 pinmux、regulator 或 GPIO 的修改必须指出原理图页码和网络名。
3. 新增 LCD/摄像头节点必须附准确器件型号、公开数据手册依据和实测启动日志。
4. 不接受为了消除日志而添加虚假 regulator、虚假 GPIO 或随意延长 delay。
5. 修改 DNP/BOM 结论时，必须区分“原理图标注”“实物装配”和“软件假设”。
6. 不提交构建缓存、完整 `output/`、私钥、令牌、Wi-Fi 凭据和未经授权的厂商二进制。

## 当前完成定义

目前可以交给使用者执行的下一条实际命令是本页“构建完整命令行镜像”中的 `./compile.sh build ...`。在该命令成功、镜像身份确认、P0 硬件问题落实并完成 P2～P6 上板验证前，本项目应继续标记为 **bring-up / 未完成硬件验证**，不应宣称 production ready。
