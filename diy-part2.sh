#!/bin/bash
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)

# =====================================================================
# 1. 主题及插件清理与强制替换逻辑
# =====================================================================
# 彻底斩断系统自带旧版主题和缓存的残留，确保 100% 采用你克隆的新版 ucode 源码
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/luci/applications/luci-app-argon-config
rm -rf package/feeds/luci/luci-theme-argon
rm -rf package/feeds/luci/luci-app-argon-config

# 【强效清理】彻底清理 feeds 缓存中自带的旧版 daed，逼迫编译器必须使用你在 custom 目录克隆的最新源码
rm -rf feeds/luci/applications/luci-app-daed
rm -rf package/feeds/luci/luci-app-daed

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
    echo "🧱 正在向你现有的基础配置中硬编码注入自定义插件及 DAE 内核依赖..."
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

# 4. 直接编译嵌入：daed 网页 UI 菜单及语言包
# CONFIG_PACKAGE_luci-app-daed=y
# CONFIG_PACKAGE_luci-i18n-daed-zh-cn=y

# =====================================================================
# 4. DAE 运行前提：根据 截屏2026-07-07 01.10.12.jpg 强制注入 eBPF 和 BTF 内核配置
# =====================================================================
CONFIG_DEVEL=y
CONFIG_KERNEL_DEBUG_INFO=y
CONFIG_KERNEL_DEBUG_INFO_REDUCED=n
CONFIG_KERNEL_DEBUG_INFO_BTF=y
CONFIG_KERNEL_CGROUPS=y
CONFIG_KERNEL_CGROUP_BPF=y
CONFIG_KERNEL_BPF_EVENTS=y
CONFIG_BPF_TOOLCHAIN_HOST=y
CONFIG_KERNEL_XDP_SOCKETS=y
CONFIG_PACKAGE_kmod-xdp-sockets-diag=y

# 【补齐的核心流量分类组件】强行开启系统内核的 BPF 网络分流底座
CONFIG_NET_CLS_BPF=y
CONFIG_NET_ACT_BPF=y
EOF
fi
