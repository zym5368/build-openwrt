#!/bin/bash
#========================================================================================================================
# https://github.com/ophub/amlogic-s9xxx-openwrt
# Description: Automatically Build OpenWrt for Amlogic s9xxx tv box
# Function: Diy script (Before Update feeds, Modify the default IP, hostname, theme, add/remove software packages, etc.)
# Source code repository: https://github.com/coolsnowwolf/lede / Branch: master
#========================================================================================================================

# Add a feed source
# sed -i '$a src-git lienol https://github.com/Lienol/openwrt-package' feeds.conf.default
src-git packages https://github.com/coolsnowwolf/packages
src-git luci https://github.com/coolsnowwolf/luci.git;openwrt-23.05
src-git routing https://github.com/coolsnowwolf/routing
src-git telephony https://github.com/coolsnowwolf/telephony.git
src-git helloworld https://github.com/fw876/helloworld.git
src-git smpackage https://github.com/kenzok8/small-package
src-git small https://github.com/kenzok8/small
# other
# rm -rf package/lean/{samba4,luci-app-samba4,luci-app-ttyd}
