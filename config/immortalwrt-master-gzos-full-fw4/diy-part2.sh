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

# ImmortalWrt packages/frp 0.69.x builds frpc/frps web assets through npm in a
# shared web/node_modules directory. On GitHub runners this can fail with npm
# ENOTEMPTY while renaming ajv, leaving missing dist files for Go embed. Keep
# frpc/frps selected, but make this package build serial and clean npm leftovers
# before the web asset build.
for FRP_MAKEFILE in feeds/packages/net/frp/Makefile package/feeds/packages/frp/Makefile; do
  [ -f "$FRP_MAKEFILE" ] || continue
  sed -i 's/^PKG_BUILD_PARALLEL:=1/PKG_BUILD_PARALLEL:=0/' "$FRP_MAKEFILE"
  awk '
    BEGIN { in_block = 0 }
    /^define Build\/Compile$/ {
      print "define Build/Compile"
      print "\trm -rf $(PKG_BUILD_DIR)/web/node_modules $(PKG_BUILD_DIR)/web/frpc/node_modules $(PKG_BUILD_DIR)/web/frps/node_modules $(PKG_BUILD_DIR)/web/.npm-cache"
      print "\trm -rf $(PKG_BUILD_DIR)/web/frpc/dist $(PKG_BUILD_DIR)/web/frps/dist"
      print "\t$(MAKE) -C $(PKG_BUILD_DIR)/web/frpc install"
      print "\trm -rf $(PKG_BUILD_DIR)/web/node_modules/.ajv-* $(PKG_BUILD_DIR)/web/node_modules/.cache"
      print "\t$(MAKE) -C $(PKG_BUILD_DIR)/web/frps install"
      print "\t$(MAKE) -C $(PKG_BUILD_DIR) web"
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
