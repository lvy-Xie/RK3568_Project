# OpenWrt for RK3568 Board1

本目录保存 RK3568 Board1 的 OpenWrt/LEDE 构建输入和历史镜像，与 `software/Armbian/` 并列维护。

## 状态说明

历史镜像基于：

- 源码：`coolsnowwolf/lede`
- 提交：`ed9364067`（`r7875-ed9364067`）
- 目标：`rockchip/armv8`
- 设备：`DEVICE_board1`
- 内核：Linux 6.12.103

这些镜像已经完成构建，但尚未完成本板实机启动验证。更重要的是，历史镜像对应的 `source/legacy/rk3568-board1.dts` 早于最新原理图审计：它仍启用实际 NC 的 UART0，并沿用 EVB 的 Type-C VBUS 配置。因此历史镜像只用于保存构建结果，不建议直接上板。

## 目录

```text
OpenWrt/
├── source/
│   ├── rk3568-board1.dts     # 最新修正版候选 DTS，待 OpenWrt 重编译验证
│   ├── armv8-board1.mk       # Board1 设备定义片段
│   └── legacy/               # 历史镜像对应的旧源码
├── build-info/               # config、feeds 和源码版本
├── images/
│   ├── board1-r7875/         # 已构建的 Board1 历史镜像
│   └── legacy/               # 来源/适用范围尚待确认的旧 Docker 镜像
└── README.md
```

## 下一版集成步骤

```bash
git clone https://github.com/coolsnowwolf/lede.git
cd lede
git checkout ed9364067

cp ../RK3568_Project/software/OpenWrt/source/rk3568-board1.dts \
  target/linux/rockchip/files/arch/arm64/boot/dts/rockchip/rk3568-board1.dts
```

然后把 `source/armv8-board1.mk` 中的设备段加入 `target/linux/rockchip/image/armv8.mk`，再执行：

```bash
./scripts/feeds update -a
./scripts/feeds install -a
make menuconfig
make -j"$(nproc)" V=s
```

在 `menuconfig` 中选择：

```text
Target System: Rockchip
Subtarget: RK33xx/RK35xx boards (64 bit)
Target Profile: Board1 RK3568 Board1 V1.0
```

`source/rk3568-board1.dts` 来自已经完成 DNP、VCCIO 和 GPIO 竞争修正的公共 Linux DTS，但尚未在 LEDE 6.12.103 上重新编译；合并前应检查基础 DTS 标签兼容性。

## 历史镜像

`images/board1-r7875/` 中包含 SquashFS、EXT4、DTB、manifest 和 SHA256：

```bash
cd images/board1-r7875
sha256sum -c SHA256SUMS
```

SquashFS 通常适合路由器式只读根文件系统和恢复出厂设置；EXT4 适合需要可写根分区的开发场景。两者都尚未通过本板实机验证。

`images/legacy/openwrt-docker.img.7z` 的精确硬件目标和构建提交尚未确认，不应把它当作 Board1 发布镜像。文件本身的传输完整性可用同目录的 `SHA256SUMS` 检查。
