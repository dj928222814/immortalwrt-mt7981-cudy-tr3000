#!/bin/bash
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)

# 1. 在输出的固件文件名中加入编译日期
sed -i -e '/^IMG_PREFIX:=/i BUILD_DATE := $(shell date +%Y%m%d)' \
       -e '/^IMG_PREFIX:=/ s/\($(SUBTARGET)\)/\1-$(BUILD_DATE)/' include/image.mk

# 2. 解决 Rust 编译报错
if [ -f "feeds/packages/lang/rust/Makefile" ]; then
    echo "正在修复 Rust 编译配置..."
    sed -i 's/ci-llvm=true/ci-llvm=false/g' feeds/packages/lang/rust/Makefile
fi

# 3. 【核心融合】同步 Quickstart 基础配置，并【直接编译嵌入】你的所有目标插件
if [ -f "defconfig/mt7981-ax3000.config" ]; then
    echo "🔄 正在加载 Quickstart 官方最新基础配置..."
    cp -f defconfig/mt7981-ax3000.config .config
    
    echo "🧱 正在向固件中直接硬编码（编译嵌入）你的所有插件及依赖..."
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

# 4. 【核心扩容】精准对 256M 固件的分区表执行 250MB 顶格扩容
DTS_256M="target/linux/mediatek/dts/mt7981b-cudy-tr3000-v1-ubootmod.dts"

if [ -f "$DTS_256M" ]; then
    echo "⚡ 检测到 256M Ubootmod 专用 DTS，正在执行 250.25M 顶格扩容..."
    sed -i 's/reg = <0x5c0000 0x7000000>;/reg = <0x5c0000 0xfa40000>;/g' "$DTS_256M"
else
    echo "⚠️ 未在默认路径找到 mt7981b-cudy-tr3000-v1-ubootmod.dts，启动全盘兼容搜索..."
    for file in target/linux/mediatek/files-*/arch/arm64/boot/dts/mediatek/*tr3000*ubootmod*.dts target/linux/mediatek/dts/*tr3000*ubootmod*.dts; do
        if [ -f "$file" ]; then
            echo "正在对兼容路径执行 250.25M 扩容改写: $file"
            sed -i '/label = "ubi";/{n;s/reg = <0x5c0000 [^>]*>/reg = <0x5c0000 0xfa40000>/}' "$file"
        fi
    done
fi
