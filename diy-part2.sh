#!/bin/bash
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)

# =====================================================================
# 1. 主题清理与强制替换逻辑
# =====================================================================
# 彻底斩断系统自带旧版主题和缓存的残留，确保 100% 采用你克隆的新版 ucode 源码
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/luci/applications/luci-app-argon-config
rm -rf package/feeds/luci/luci-theme-argon
rm -rf package/feeds/luci/luci-app-argon-config

# 强制将系统的默认主题修改为高颜值的 luci-theme-argon
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile


# =====================================================================
# 2. 基础修补逻辑
# =====================================================================
# 临时解决 Rust 编译器的编译问题
sed -i 's/ci-llvm=true/ci-llvm=false/g' feeds/packages/lang/rust/Makefile

# 在输出的固件文件名中自动加上编译日期
sed -i -e '/^IMG_PREFIX:=/i BUILD_DATE := $(shell date +%Y%m%d)' \
       -e '/^IMG_PREFIX:=/ s/\($(SUBTARGET)\)/\1-$(BUILD_DATE)/' include/image.mk


# =====================================================================
# 3. 插件注入逻辑：直接在你原有的 .config 基础配置末尾追加插件开关
# =====================================================================
if [ -f ".config" ]; then
    echo "🧱 正在向你现有的 256M 基础配置中硬编码注入自定义插件..."
    cat << EOF >> .config
# 核心依赖：确保旧版 Luci 兼容层直接编译进固件（iStore、QModem 必备）
CONFIG_PACKAGE_luci-compat=y

# 1. 直接编译嵌入：iStore 应用商店
CONFIG_PACKAGE_luci-app-istore=y

# 2. 直接编译嵌入：新版 Argon 主题及配置菜单
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-app-argon-config=y

# 3. 直接编译嵌入：QModem-custom 5G 核心及相关网络依赖组件
CONFIG_PACKAGE_luci-app-qmodem=y
CONFIG_PACKAGE_kmod-mii=y
CONFIG_PACKAGE_kmod-usb-net=y
CONFIG_PACKAGE_kmod-usb-wdm=y
CONFIG_PACKAGE_kmod-usb-net-qmi-wwan=y
CONFIG_PACKAGE_kmod-usb-serial=y
CONFIG_PACKAGE_kmod-usb-serial-option=y
CONFIG_PACKAGE_kmod-usb-serial-wwan=y
CONFIG_PACKAGE_comgt=y
CONFIG_PACKAGE_uqmi=y
EOF
fi


# =====================================================================
# 4. 稳健扩容：精准对 256M 固件的分区表执行 240MB 稳健扩容（留出 10M 缓冲区）
# =====================================================================
DTS_256M="target/linux/mediatek/dts/mt7981b-cudy-tr3000-v1-ubootmod.dts"

if [ -f "$DTS_256M" ]; then
    echo "⚡ 检测到 256M Ubootmod 专用 DTS，正在执行 240M 稳健扩容..."
    sed -i 's/reg = <0x5c0000 0x7000000>;/reg = <0x5c0000 0xf000000>;/g' "$DTS_256M"
else
    echo "⚠️ 未在默认路径找到 mt7981b-cudy-tr3000-v1-ubootmod.dts，启动全盘兼容搜索..."
    for file in target/linux/mediatek/files-*/arch/arm64/boot/dts/mediatek/*tr3000*ubootmod*.dts target/linux/mediatek/dts/*tr3000*ubootmod*.dts; do
        if [ -f "$file" ]; then
            echo "正在对兼容路径执行 240M 扩容改写: $file"
            sed -i '/label = "ubi";/{n;s/reg = <0x5c0000 [^>]*>/reg = <0x5c0000 0xf000000>/}' "$file"
        fi
    done
fi
