#!/bin/bash
#========================================================================================================================
# https://github.com/ophub/amlogic-s9xxx-openwrt
# Description: Automatically Build OpenWrt
# Function: Diy script (After Update feeds, Modify the default IP, hostname, theme, add/remove software packages, etc.)
# Source code repository: https://github.com/immortalwrt/immortalwrt / Branch: master
# Profile: GZOS full firewall4/nftables comparison build
#========================================================================================================================

# ------------------------------- Main source started -------------------------------
#
# Add the default password for the 'root' user（Change the empty password to 'password'）
sed -i 's/root:::0:99999:7:::/root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.::0:99999:7:::/g' package/base-files/files/etc/shadow

# Apply GZOS default IP, hostname and release branding.
REPO_WORKSPACE="${GITHUB_WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${REPO_WORKSPACE}/config/common/gzos-defaults.sh"
apply_gzos_defaults

# Set etc/openwrt_release for ImmortalWrt's base-files path.
if [ -f package/base-files/files/etc/openwrt_release ]; then
  sed -i \
    -e "s|DISTRIB_REVISION='.*'|DISTRIB_REVISION='${GZOS_RELEASE_REVISION:-R26.05.20}'|g" \
    -e "s|DISTRIB_DESCRIPTION='.*'|DISTRIB_DESCRIPTION='${GZOS_DEFAULT_HOSTNAME:-GZOS} '|g" \
    package/base-files/files/etc/openwrt_release
  grep -q "^DISTRIB_SOURCECODE='GZOS'" package/base-files/files/etc/openwrt_release || \
    echo "DISTRIB_SOURCECODE='GZOS'" >> package/base-files/files/etc/openwrt_release
fi

# Drop unselected third-party feed packages with known recursive Kconfig edges.
# This keeps the fw4 comparison profile clean while retaining OpenClash/Nikki/Momo.
rm -rf \
  feeds/small/luci-app-fchomo package/feeds/small/luci-app-fchomo \
  feeds/smpackage/luci-app-fchomo package/feeds/smpackage/luci-app-fchomo \
  feeds/smpackage/luci-app-alist package/feeds/smpackage/luci-app-alist \
  feeds/smpackage/luci-app-kodexplorer package/feeds/smpackage/luci-app-kodexplorer \
  feeds/smpackage/luci-app-nekobox package/feeds/smpackage/luci-app-nekobox \
  feeds/smpackage/luci-app-nat6-helper package/feeds/smpackage/luci-app-nat6-helper \
  feeds/luci/applications/luci-app-natmap package/feeds/luci/luci-app-natmap \
  feeds/smpackage/luci-app-natmap package/feeds/smpackage/luci-app-natmap \
  feeds/packages/net/natmap package/feeds/packages/natmap \
  feeds/luci/applications/luci-app-qbittorrent package/feeds/luci/luci-app-qbittorrent \
  feeds/smpackage/luci-app-qbittorrent package/feeds/smpackage/luci-app-qbittorrent \
  feeds/packages/net/qbittorrent package/feeds/packages/qbittorrent \
  feeds/luci/applications/luci-app-ua2f package/feeds/luci/luci-app-ua2f \
  feeds/packages/net/ua2f package/feeds/packages/ua2f \
  feeds/smpackage/luci-app-torbp package/feeds/smpackage/luci-app-torbp \
  feeds/packages/net/tor package/feeds/packages/tor \
  feeds/smpackage/mentohust feeds/smpackage/luci-app-mentohust \
  package/feeds/smpackage/mentohust package/feeds/smpackage/luci-app-mentohust \
  feeds/packages/net/minieap package/feeds/packages/minieap \
  feeds/smpackage/luci-app-minieap package/feeds/smpackage/luci-app-minieap \
  feeds/smpackage/luci-app-oaf package/feeds/smpackage/luci-app-oaf \
  feeds/packages/net/open-app-filter package/feeds/packages/open-app-filter \
  feeds/packages/net/strongswan package/feeds/packages/strongswan

# luci-app-openvpn-client and luci-app-openvpn-server both ship an openvpn UCI
# file in these feeds. Keep the server UI but remove the duplicate default file.
rm -f feeds/luci/applications/luci-app-openvpn-server/root/etc/config/openvpn

# Linux 6.18 currently makes both kmod-iptables and kmod-nf-ipt package the
# same ip_tables.ko/x_tables.ko files. Keep the modern kmod-nf-ipt owner used
# by nft-compat and stop pulling the duplicate legacy package into rootfs.
NETFILTER_MODULES_MK="package/kernel/linux/modules/netfilter.mk"
if [ -f "$NETFILTER_MODULES_MK" ]; then
  sed -i 's/^  DEPENDS:=+!LINUX_6_12:kmod-iptables$/  DEPENDS:=/' "$NETFILTER_MODULES_MK"
fi

# Boost.System is header-only and no longer emitted as a separate package by
# the current Boost 1.91 feed. trojan-plus compiles without that runtime IPK;
# remove only the stale package dependency and retain boost/program_options.
for TROJAN_PLUS_MAKEFILE in feeds/small/trojan-plus/Makefile package/feeds/small/trojan-plus/Makefile; do
  [ -f "$TROJAN_PLUS_MAKEFILE" ] || continue
  sed -i 's/+boost +boost-system +boost-program_options/+boost +boost-program_options/' "$TROJAN_PLUS_MAKEFILE"
done

# ImmortalWrt packages/frp 0.69.x builds frpc/frps web assets through a shared
# npm workspace. The upstream Makefiles run npm install repeatedly and use the
# runner HOME cache, which can be root-owned in this workflow. Keep frpc/frps,
# but install the workspace once with a package-local HOME/cache, then build the
# two dashboards sequentially before compiling Go.
for FRP_MAKEFILE in feeds/packages/net/frp/Makefile package/feeds/packages/frp/Makefile; do
  [ -f "$FRP_MAKEFILE" ] || continue
  sed -i 's/^PKG_BUILD_PARALLEL:=1/PKG_BUILD_PARALLEL:=0/' "$FRP_MAKEFILE"
  awk '
    BEGIN { in_block = 0 }
    /^define Build\/Compile$/ {
      print "define Build/Compile"
      print "\trm -rf $(PKG_BUILD_DIR)/web/node_modules $(PKG_BUILD_DIR)/web/.npm-cache $(PKG_BUILD_DIR)/web/.npm-home"
      print "\trm -rf $(PKG_BUILD_DIR)/web/frpc/dist $(PKG_BUILD_DIR)/web/frps/dist"
      print "\tmkdir -p $(PKG_BUILD_DIR)/web/.npm-cache $(PKG_BUILD_DIR)/web/.npm-home"
      print "\tcd $(PKG_BUILD_DIR)/web && HOME=$(PKG_BUILD_DIR)/web/.npm-home npm_config_cache=$(PKG_BUILD_DIR)/web/.npm-cache npm ci --no-audit --no-fund"
      print "\tcd $(PKG_BUILD_DIR)/web && HOME=$(PKG_BUILD_DIR)/web/.npm-home npm_config_cache=$(PKG_BUILD_DIR)/web/.npm-cache npm run build --workspace=frpc"
      print "\tcd $(PKG_BUILD_DIR)/web && HOME=$(PKG_BUILD_DIR)/web/.npm-home npm_config_cache=$(PKG_BUILD_DIR)/web/.npm-cache npm run build --workspace=frps"
      print "\t$(call GoPackage/Build/Compile)"
      in_block = 1
      next
    }
    in_block && /^endef$/ {
      print "endef"
      in_block = 0
      next
    }
    !in_block { print }
  ' "$FRP_MAKEFILE" > "${FRP_MAKEFILE}.tmp" && mv "${FRP_MAKEFILE}.tmp" "$FRP_MAKEFILE"
done
#
# ------------------------------- Main source ends -------------------------------

# ------------------------------- Other started -------------------------------
#
# Add luci-app-amlogic
# svn co https://github.com/ophub/luci-app-amlogic/trunk/luci-app-amlogic package/luci-app-amlogic

# Apply patch
# git apply ../config/patches/{0001*,0002*}.patch --directory=feeds/luci
#
# ------------------------------- Other ends -------------------------------
