# Armbian for RK3568 Board1

本目录保存 RK3568 Board1 的 Armbian 板卡定义、Linux DTS、U-Boot 补丁和 AIC8800 配置。已验证的组合为：

- Armbian build：`fe0ad5fdf`
- 用户空间：Debian 13 Trixie
- 内核：Linux 6.18.49 / `current`
- Bootloader：主线 U-Boot v2026.04
- 无线：AIC8800 USB DKMS `5.0+git20260123.5f7be68d-8`

## 目录

```text
Armbian/
├── userpatches/              # 复制到 Armbian build 根目录
├── artifacts/                # 已构建产物的名称、版本和 SHA256
├── PORTING.md                # 原理图审计、故障排查和上板路线
└── README.md
```

## 构建

```bash
git clone https://github.com/armbian/build.git armbian-build
cd armbian-build
git checkout fe0ad5fdf

cp -a ../RK3568_Project/software/Armbian/userpatches/. userpatches/

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

不要用 `sudo ./compile.sh`，也不要把 Armbian 的 `cache/`、`output/` 或完整源码树提交到本仓库。

## 已构建镜像

```text
Armbian-unofficial_26.11.0-trunk_Rk3568-schematic1_trixie_current_6.18.49.img
SHA256 934dcf5da4ddee93a7ff4aa566401764422ce1888d2e14c30c1bb68e59384091
```

完整镜像为 2,868,903,936 字节，未提交到 GitHub。详见 [artifacts/SHA256SUMS](artifacts/SHA256SUMS) 和 [完整移植文档](PORTING.md)。
