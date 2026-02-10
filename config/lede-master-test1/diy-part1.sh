#!/bin/bash
#========================================================================================================================
# https://github.com/ophub/amlogic-s9xxx-openwrt
# Description: Automatically Build OpenWrt for Amlogic s9xxx tv box
# Function: Diy script (Before Update feeds, Modify the default IP, hostname, theme, add/remove software packages, etc.)
# Source code repository: https://github.com/coolsnowwolf/lede / Branch: master
#========================================================================================================================

# 清空并按你的配置重写 feeds.conf.default，减少 sed 带来的错误
cat > feeds.conf.default << 'EOF'
src-git packages https://github.com/coolsnowwolf/packages
#src-git luci https://github.com/coolsnowwolf/luci.git
#src-git luci https://github.com/coolsnowwolf/luci.git;openwrt-23.05
src-git luci https://github.com/coolsnowwolf/luci.git;openwrt-24.10
src-git routing https://github.com/coolsnowwolf/routing
src-git telephony https://github.com/coolsnowwolf/telephony.git
src-git helloworld https://github.com/fw876/helloworld.git
#src-git qmodem https://github.com/FUjr/modem_feeds.git
#src-git video https://github.com/openwrt/video.git
#src-git targets https://github.com/openwrt/targets.git
#src-git oldpackages http://git.openwrt.org/packages.git
#src-link custom /usr/src/openwrt/custom-feed
src-git kenzo https://github.com/kenzok8/openwrt-packages
src-git small https://github.com/kenzok8/small
EOF

# other（按需取消注释）
# rm -rf package/lean/{samba4,luci-app-samba4,luci-app-ttyd}
