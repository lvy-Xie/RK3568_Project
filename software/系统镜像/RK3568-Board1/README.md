# RK3568 Board1 V1.0 固件

编译目标：`rockchip/armv8`，设备配置：`DEVICE_board1`。

## 推荐镜像

首次测试建议使用：

`openwrt-rockchip-armv8-board1-squashfs-sysupgrade.img.gz`

写卡工具不支持 gzip 时，先解压得到 `.img` 文件再烧录。

## 文件说明

- `*-squashfs-sysupgrade.img.gz`：推荐的 SquashFS 固件，支持恢复出厂设置。
- `*-ext4-sysupgrade.img.gz`：EXT4 根文件系统固件。
- `image-rk3568-board1.dtb`：本次编译生成的设备树二进制。
- `*.manifest`：固件软件包清单。
- `*.buildinfo`：构建配置、feeds 和版本信息。
- `source/`：Board1 DTS 及 Rockchip 镜像设备定义。
- `sha256sums`：固件、manifest 和 DTB 的 SHA-256 校验值。

烧录前请确认目标设备确实为 RK3568 Board1 V1.0，并备份原始镜像。
