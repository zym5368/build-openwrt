#!/bin/bash
#========================================================================================================================
# https://github.com/ophub/amlogic-s9xxx-openwrt
# Description: Automatically Build OpenWrt for Amlogic s9xxx tv box
# Function: Diy script (After Update feeds, Modify the default IP, hostname, theme, add/remove software packages, etc.)
# Source code repository: https://github.com/coolsnowwolf/lede / Branch: master
#========================================================================================================================

# ------------------------------- Main source started -------------------------------
#
# Modify default theme（FROM uci-theme-bootstrap CHANGE TO luci-theme-material）
# sed -i 's/luci-theme-bootstrap/luci-theme-material/g' ./feeds/luci/collections/luci/Makefile

# Add autocore support for armvirt
sed -i 's/TARGET_rockchip/TARGET_rockchip\|\|TARGET_armvirt/g' package/lean/autocore/Makefile

# Reuse the validated defaults helper with YMOS-specific values.
REPO_WORKSPACE="${GITHUB_WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
GZOS_DEFAULT_HOSTNAME="YMOS"
GZOS_DEFAULT_LAN_IP="192.168.110.115"
GZOS_DEFAULT_BROADCAST="192.168.110.255"
GZOS_RELEASE_REVISION="R26.07.16"
. "${REPO_WORKSPACE}/config/common/gzos-defaults.sh"
apply_gzos_defaults

# Replace the default software source
# sed -i 's#openwrt.proxy.ustclug.org#mirrors.bfsu.edu.cn\\/openwrt#' package/lean/default-settings/files/zzz-default-settings
#
# ------------------------------- Main source ends -------------------------------

# ------------------------------- Other started -------------------------------
#
add_gzos_full_package() {
  local repo_url="$1"
  local branch="$2"
  local repo_path="$3"
  local target_path="$4"
  local tmp_dir

  tmp_dir="$(mktemp -d)"
  echo "Import ${repo_url} ${branch}:${repo_path} -> ${target_path}"
  git clone -q --depth 1 --filter=blob:none --sparse --branch "${branch}" "${repo_url}" "${tmp_dir}"
  git -C "${tmp_dir}" sparse-checkout set "${repo_path}"
  rm -rf "${target_path}"
  mkdir -p "$(dirname "${target_path}")"
  cp -a "${tmp_dir}/${repo_path}" "${target_path}"
  rm -rf "${tmp_dir}"
}

mkdir -p package/gzos-full

# Restore legacy LuCI entries needed by the current YMOS package set without replacing the full 24.10 LuCI feed.
add_gzos_full_package https://github.com/coolsnowwolf/luci.git openwrt-23.05 applications/luci-app-accesscontrol package/gzos-full/luci-app-accesscontrol
add_gzos_full_package https://github.com/coolsnowwolf/luci.git openwrt-23.05 applications/luci-app-filetransfer package/gzos-full/luci-app-filetransfer
add_gzos_full_package https://github.com/coolsnowwolf/luci.git openwrt-23.05 applications/luci-app-opkg package/gzos-full/luci-app-opkg
add_gzos_full_package https://github.com/coolsnowwolf/luci.git openwrt-23.05 libs/luci-lib-fs package/gzos-full/luci-lib-fs

# Packages no longer present in the current configured feeds, imported individually from known Lean-oriented feeds.
add_gzos_full_package https://github.com/kenzok8/small-package.git main luci-app-istorepanel package/gzos-full/luci-app-istorepanel
add_gzos_full_package https://github.com/kenzok8/small-package.git main luci-app-npc package/gzos-full/luci-app-npc
add_gzos_full_package https://github.com/kenzok8/small-package.git main luci-app-openvpn-client package/gzos-full/luci-app-openvpn-client
add_gzos_full_package https://github.com/kenzok8/small-package.git main luci-app-easytier/luci-app-easytier package/gzos-full/luci-app-easytier
add_gzos_full_package https://github.com/haiibo/openwrt-packages.git master luci-app-bypass package/gzos-full/luci-app-bypass
add_gzos_full_package https://github.com/tianiue/luci-app-bypass.git master lua-maxminddb package/gzos-full/lua-maxminddb

# Old LuCI branch packages expect their original applications/* layout. Make them build from package/gzos-full.
for makefile in \
  package/gzos-full/luci-app-accesscontrol/Makefile \
  package/gzos-full/luci-app-filetransfer/Makefile \
  package/gzos-full/luci-app-opkg/Makefile
do
  sed -i 's#include ../../luci.mk#include $(TOPDIR)/feeds/luci/luci.mk#' "${makefile}"
done

# luci-app-openvpn-client pulls in openvpn-openssl, which already owns /etc/config/openvpn.
# Keep the OpenVPN server LuCI page, but drop its duplicate default config to avoid rootfs clashes.
rm -f feeds/luci/applications/luci-app-openvpn-server/root/etc/config/openvpn

# Add luci-app-amlogic
# svn co https://github.com/ophub/luci-app-amlogic/trunk/luci-app-amlogic package/luci-app-amlogic

# Fix runc version error
# rm -rf ./feeds/packages/utils/runc/Makefile
# svn export https://github.com/openwrt/packages/trunk/utils/runc/Makefile ./feeds/packages/utils/runc/Makefile

# coolsnowwolf default software package replaced with Lienol related software package
# rm -rf feeds/packages/utils/{containerd,libnetwork,runc,tini}
# svn co https://github.com/Lienol/openwrt-packages/trunk/utils/{containerd,libnetwork,runc,tini} feeds/packages/utils

# Add third-party software packages (The entire repository)
# git clone https://github.com/libremesh/lime-packages.git package/lime-packages
# Add third-party software packages (Specify the package)
# svn co https://github.com/libremesh/lime-packages/trunk/packages/{shared-state-pirania,pirania-app,pirania} package/lime-packages/packages
# Add to compile options (Add related dependencies according to the requirements of the third-party software package Makefile)
# sed -i "/DEFAULT_PACKAGES/ s/$/ pirania-app pirania ip6tables-mod-nat ipset shared-state-pirania uhttpd-mod-lua/" target/linux/armvirt/Makefile

# Apply patch
# git apply ../config/patches/{0001*,0002*}.patch --directory=feeds/luci
#
# ------------------------------- Other ends -------------------------------
