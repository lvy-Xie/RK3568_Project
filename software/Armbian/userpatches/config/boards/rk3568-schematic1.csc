# RK3568 Board1 / Schematic1, based on SCH_Schematic1_2026-08-30.pdf V1.0
BOARD_NAME="Schematic1 RK3568 Board1"
BOARD_VENDOR="custom"
BOARDFAMILY="rk35xx"
BOARD_MAINTAINER="community"
INTRODUCED="2026"
BOOTCONFIG="schematic1-rk3568_defconfig"
BOOT_SOC="rk3568"
KERNEL_TARGET="current"
KERNEL_TEST_TARGET="current"
FULL_DESKTOP="yes"
BOOT_LOGO="desktop"
BOOT_FDT_FILE="rockchip/rk3568-schematic1.dtb"
BOOT_SCENARIO="spl-blobs"
IMAGE_PARTITION_TABLE="gpt"

# U19 has no UART connection.  Both Wi-Fi and the optional Bluetooth HCI
# interface, when exposed by this module revision, travel over USB2_HOST2.
MODULES="aic_load_fw_usb aic8800_fdrv_usb aic_btusb_usb"
PACKAGE_LIST_BOARD="rfkill bluetooth bluez bluez-tools"
AIC8800_TYPE="usb"
enable_extension "radxa-aic8800"

function post_family_config__schematic1_use_mainline_uboot() {
	display_alert "$BOARD" "Using mainline U-Boot v2026.04" "info"
	declare -g BOOTCONFIG="schematic1-rk3568_defconfig"
	declare -g BOOTDELAY=1
	declare -g BOOTSOURCE="https://github.com/u-boot/u-boot"
	declare -g BOOTBRANCH="tag:v2026.04"
	declare -g BOOTPATCHDIR="v2026.04/board_${BOARD}"
	declare -g BOOTDIR="u-boot-${BOARD}"
	declare -g UBOOT_TARGET_MAP="BL31=${RKBIN_DIR}/${BL31_BLOB} ROCKCHIP_TPL=${RKBIN_DIR}/${DDR_BLOB};;u-boot-rockchip.bin"

	unset uboot_custom_postprocess write_uboot_platform write_uboot_platform_mtd

	function write_uboot_platform() {
		dd "if=$1/u-boot-rockchip.bin" "of=$2" bs=32k seek=1 conv=notrunc status=none
	}
}

# The stock multi-platform configuration omits the board's Ethernet driver.
# Keep boot-critical buses built in; user-facing audio/input/backlight stay modules.
function custom_kernel_config__schematic1_required_drivers() {
	# custom_kernel_config is called once for hashing without a kernel tree and
	# again with .config present.  Use the aggregation arrays so both phases are
	# deterministic and the framework applies scripts/config only in phase two.
	opts_y+=(
		"STMMAC_ETH"
		"STMMAC_PLATFORM"
		"DWMAC_ROCKCHIP"
		"REALTEK_PHY"
		"PCI"
		"PCIE_ROCKCHIP_DW_HOST"
		"I2C_RK3X"
		"MFD_RK8XX_I2C"
		"REGULATOR_FIXED_VOLTAGE"
		"REGULATOR_RK808"
		"MMC_DW_ROCKCHIP"
		"MMC_SDHCI_OF_DWCMSHC"
		"ROCKCHIP_IODOMAIN"
		"ROCKCHIP_SARADC"
		"ROCKCHIP_THERMAL"
		"PHY_ROCKCHIP_INNO_USB2"
		"PHY_ROCKCHIP_NANENG_COMBO_PHY"
		"USB_DWC3"
		"USB_XHCI_HCD"
		"USB_EHCI_HCD"
		"USB_EHCI_HCD_PLATFORM"
		"USB_OHCI_HCD"
		"USB_OHCI_HCD_PLATFORM"
		"USB_GADGET"
		"PWM_ROCKCHIP"
		"LEDS_GPIO"
		"LEDS_TRIGGER_HEARTBEAT"
		"ROCKCHIP_DW_HDMI"
	)

	opts_m+=(
		"USB_ETH"
		"KEYBOARD_ADC"
		"INPUT_RK805_PWRKEY"
		"BACKLIGHT_PWM"
		"RTC_DRV_RK808"
		"DRM_ROCKCHIP"
		"DRM_DISPLAY_CONNECTOR"
		"DRM_DW_HDMI_AHB_AUDIO"
		"DRM_DW_HDMI_GP_AUDIO"
		"DRM_DW_HDMI_CEC"
		"SND_SOC_ROCKCHIP_I2S_TDM"
		"SND_SOC_RK817"
		"SND_SIMPLE_CARD"
	)
}

function post_family_tweaks_bsp__schematic1_aic8800_wifi() {
	display_alert "$BOARD" "Installing AIC8800D40L USB Wi-Fi configuration" "info"
	install -d -m 0755 "${destination}/etc/modprobe.d"
	install -m 0644 \
		"${SRC}/userpatches/board-rk3568-schematic1/aic8800-usb.conf" \
		"${destination}/etc/modprobe.d/aic8800-usb.conf"
}
