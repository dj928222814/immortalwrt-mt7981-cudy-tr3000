#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#

# 1. 创建专用的自定义插件目录
mkdir -p package/custom
cd package/custom

# 2. 拉取你指定的 QModem-custom 5G 源码
git clone https://github.com/sfwtw/QModem-custom.git

# 3. 拉取 linkease 官方的 iStore 商店核心组件源码
git clone https://github.com/linkease/istore.git

# 4. 拉取真正适配新版 ucodebridge 架构的 Argon 主题主分支
git clone https://github.com/jerrykuku/luci-theme-argon.git
git clone https://github.com/jerrykuku/luci-app-argon-config.git

# 5. 退出目录，将控制权交还给主编译器
cd ../../

# 6. 保留原脚本中本地包复制逻辑
if [ -d "$GITHUB_WORKSPACE/package/luci-compat-keep" ]; then
  mkdir -p package
  cp -r "$GITHUB_WORKSPACE/package/luci-compat-keep" package/
fi
