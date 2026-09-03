# Add this block to target/linux/rockchip/image/armv8.mk.
define Device/board1
  DEVICE_VENDOR := Board1
  DEVICE_MODEL := RK3568 Board1 V1.0
  SOC := rk3568
  UBOOT_DEVICE_NAME := generic-rk3568
  IMAGE/sysupgrade.img.gz := boot-common | boot-script vop | pine64-img | gzip | append-metadata
  DEVICE_PACKAGES := kmod-drm-rockchip kmod-gpio-button-hotplug
endef
TARGET_DEVICES += board1
