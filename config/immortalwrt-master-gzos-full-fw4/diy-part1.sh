#!/bin/bash
#========================================================================================================================
# https://github.com/ophub/amlogic-s9xxx-openwrt
# Description: Automatically Build OpenWrt
# Function: Diy script (Before Update feeds, Modify the default IP, hostname, theme, add/remove software packages, etc.)
# Source code repository: https://github.com/immortalwrt/immortalwrt / Branch: master
# Profile: GZOS full firewall4/nftables comparison build
#========================================================================================================================

# Add a feed source
# sed -i '$a src-git lienol https://github.com/Lienol/openwrt-package' feeds.conf.default
# sed -i '$a src-git helloworld https://github.com/fw876/helloworld.git' feeds.conf.default
# sed -i '$a src-git kenzo https://github.com/kenzok8/openwrt-packages' feeds.conf.default
grep -q '^src-git small ' feeds.conf.default || \
  sed -i '$a src-git small https://github.com/kenzok8/small' feeds.conf.default
grep -q '^src-git smpackage ' feeds.conf.default || \
  sed -i '$a src-git smpackage https://github.com/kenzok8/small-package' feeds.conf.default

# Keep ImmortalWrt core packages authoritative. Package/feed cleanup that needs
# fetched feeds is done in diy-part2 after ./scripts/feeds install -a.
