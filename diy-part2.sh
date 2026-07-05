#!/bin/bash
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)

# =====================================================================
# 1. 保留你原本的主题清理与强制替换逻辑
# =====================================================================
# 彻底斩断系统自带旧版主题和缓存的残留，确保 100% 采用刚才克隆的新版 ucode 源码
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/luci/applications/luci-app-argon-config
rm -rf package/feeds/luci/luci-theme-argon
rm -rf package/feeds/luci/luci-app-argon-config

# 强制将系统的默认主题修改为高颜值的 luci-theme-argon
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile


# =====================================================================
# 2. 保留你原本的基础修补逻辑
# =====================================================================
# 临时解决 Rust 编译器的编译问题
sed -i 's/ci-llvm=true/ci-llvm=false/g' feeds/packages/lang/rust/Makefile

# 在输出的固件文件名中自动加上编译日期
sed -i -e '/^IMG_PREFIX:=/i BUILD_DATE := $(shell date +%Y%m%d)' \
       -e '/^IMG_PREFIX:=/ s/\($(SUBTARGET)\)/\1-$(BUILD_DATE)/' include/image.mk


# =====================================================================
# 3. 核心修正：自动寻找真正属于 Cudy TR3000 的官方配置，并注入插件
# =====================================================================
# 智能寻找 padavanonly 仓库里关于 tr3000 或 256m 的官方基础配置
TR3000_CONFIG=$(ls defconfig/*tr3000*.config defconfig/*256m*.config 2>/dev/null | head -n 1)

if [ -n "$TR3000_CONFIG" ] && [ -f "$TR3000_CONFIG" ]; then
    echo "🎯 成功找到适配你机型的官方最新基础配置: $TR3000_CONFIG"
    cp -f "$TR3000_CONFIG" .config
else
    echo "⚠️ 未在 defconfig 中找到 tr3000 专属配置，正在尝试从你本地仓库的 config/256m.config 恢复..."
    if [ -f "$GITHUB_WORKSPACE/config/256m.config" ]; then
        cp -f "$GITHUB_WORKSPACE/config/256m.config" .config
    fi
fi

# 确保 .config 存在后，直接把你的核心插件硬编码（编译嵌入）进去
if [ -f ".config" ]; then
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


# =====================================================================
# 4. 核心扩容：精准对 256M 固件的分区表执行 250MB 顶格扩容
# =====================================================================
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
