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

# Set etc/openwrt_release
# sed -i "s|DISTRIB_REVISION='.*'|DISTRIB_REVISION='R$(date +%Y.%m.%d)'|g" package/lean/default-settings/files/zzz-default-settings
sed -i "s|DISTRIB_DESCRIPTION='.*'|DISTRIB_DESCRIPTION='YMOS'|g" ${GITHUB_WORKSPACE}/openwrt/package/lean/default-settings/files/zzz-default-settings

# Modify default IP（FROM 192.168.1.1 CHANGE TO 192.168.31.4）
sed -i 's/192.168.1.1/192.168.110.115/g' package/base-files/luci/bin/config_generate
sed -i "s/hostname='LEDE'/hostname='YMOS'/g" package/base-files/luci/bin/config_generate

# Replace the default software source
# sed -i 's#openwrt.proxy.ustclug.org#mirrors.bfsu.edu.cn\\/openwrt#' package/lean/default-settings/files/zzz-default-settings
#
# ------------------------------- Main source ends -------------------------------

# ------------------------------- Other started -------------------------------
#
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
# ==========================================
# 修复 qttools 编译问题 - 最终修复版本
# 直接复制到 config/lede-master/diy-part2.sh
# ==========================================
echo "=========================================="
echo "开始修复 qttools 编译问题..."
echo "=========================================="

if [ -f "feeds/packages/libs/qttools/Makefile" ]; then
    # 备份原文件
    cp feeds/packages/libs/qttools/Makefile feeds/packages/libs/qttools/Makefile.bak
    
    # 添加 TARGET_CXXFLAGS（如果还没有）
    if ! grep -q "TARGET_CXXFLAGS += -Wno-dangling-reference" feeds/packages/libs/qttools/Makefile; then
        sed -i '/^include.*package.mk/a\\n# 禁用 GCC 13.3 的悬空引用警告\nTARGET_CXXFLAGS += -Wno-dangling-reference' feeds/packages/libs/qttools/Makefile
    fi
    
    # 替换 Build/Configure 部分
    # 关键修复：在 shell 脚本中使用 sed 替换 Makefile 时
    # - 在 shell 脚本中：\\\$\\\$ 会被解释为 \$\$
    # - 写入 Makefile 后：\$\$ 会被 Makefile 解释为 $（用于匹配行尾）
    # - 在 sed 命令中（单引号内）：$ 表示行尾
    sed -i '/^define Build\/Configure$/,/^endef$/c\
define Build/Configure\
	cd $$(PKG_BUILD_DIR) && \\\
		sed -i '\''s/qtHaveModule(dbus): SUBDIRS += qdbus/# qtHaveModule(dbus): SUBDIRS += qdbus # Disabled: qtbase has -no-dbus/'\'' src/src.pro && \\\
		sed -i '\''s/^requires(qtConfig(qdbus))\\$\\$/# requires(qtConfig(qdbus)) # Disabled: qtbase has -no-dbus/'\'' src/qdbus/qdbus.pro && \\\
		sed -i '\''s|qtConfig(dom): SUBDIRS = qdbus|# qtConfig(dom): SUBDIRS = qdbus # Disabled: qtbase has -no-dbus|'\'' src/qdbus/qdbus.pro && \\\
		sed -i '\''s|SUBDIRS += qdbusviewer|# SUBDIRS += qdbusviewer # Disabled: qdbus is disabled|'\'' src/qdbus/qdbus.pro && \\\
		(echo '\'''\''; echo '\''# Add CXXFLAGS to disable dangling-reference warning'\''; echo '\''QMAKE_CXXFLAGS += -Wno-dangling-reference'\'') >> qttools.pro && \\\
		qmake -o Makefile qttools.pro \\\
		QMAKE_CXXFLAGS+="$$(TARGET_CXXFLAGS) $$(EXTRA_CXXFLAGS)"\
endef' feeds/packages/libs/qttools/Makefile
    
    echo "qttools Makefile 修复完成！"
    echo "=========================================="
else
    echo "警告: 找不到 feeds/packages/libs/qttools/Makefile，跳过修复"
fi
