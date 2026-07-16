#!/bin/bash

GZOS_DEFAULT_HOSTNAME="${GZOS_DEFAULT_HOSTNAME:-GZOS}"
GZOS_DEFAULT_LAN_IP="${GZOS_DEFAULT_LAN_IP:-192.168.113.205}"
GZOS_DEFAULT_BROADCAST="${GZOS_DEFAULT_BROADCAST:-192.168.113.255}"
GZOS_RELEASE_REVISION="${GZOS_RELEASE_REVISION:-R26.05.20}"

apply_gzos_defaults() {
  local config_generate
  for config_generate in \
    package/base-files/files/bin/config_generate \
    package/base-files/luci/bin/config_generate
  do
    [ -f "${config_generate}" ] || continue

    sed -i \
      -e "s|lan) ipad=\${ipaddr:-\"[0-9.]*\"} ;;|lan) ipad=\${ipaddr:-\"${GZOS_DEFAULT_LAN_IP}\"} ;;|g" \
      -e "s|set system.@system\\[-1\\].hostname='[^']*'|set system.@system[-1].hostname='${GZOS_DEFAULT_HOSTNAME}'|g" \
      "${config_generate}"
  done

  if [ -f package/base-files/files/etc/init.d/system ]; then
    sed -i -E \
      "s|'hostname:string:[^']*'|'hostname:string:${GZOS_DEFAULT_HOSTNAME}'|g" \
      package/base-files/files/etc/init.d/system
  fi

  if [ -f package/lean/default-settings/files/zzz-default-settings ]; then
    sed -i \
      -e "s|DISTRIB_DESCRIPTION='.*'|DISTRIB_DESCRIPTION='${GZOS_DEFAULT_HOSTNAME} '|g" \
      -e "s|DISTRIB_REVISION='.*'|DISTRIB_REVISION='${GZOS_RELEASE_REVISION}'|g" \
      -e "s|OPENWRT_RELEASE=\"[^\"]*\"|OPENWRT_RELEASE=\"${GZOS_DEFAULT_HOSTNAME} ${GZOS_RELEASE_REVISION}\"|g" \
      package/lean/default-settings/files/zzz-default-settings
  fi

  mkdir -p package/base-files/files/etc/uci-defaults
  cat > package/base-files/files/etc/uci-defaults/99-gzos-defaults <<EOF
#!/bin/sh

gzos_hostname='${GZOS_DEFAULT_HOSTNAME}'
gzos_lan_ip='${GZOS_DEFAULT_LAN_IP}'
gzos_release_revision='${GZOS_RELEASE_REVISION}'

current_hostname="\$(uci -q get system.@system[0].hostname)"
case "\${current_hostname}" in
  ""|LEDE|OpenWrt|YMOS)
    uci -q set system.@system[0].hostname="\${gzos_hostname}"
    uci -q commit system
    printf '%s\n' "\${gzos_hostname}" > /proc/sys/kernel/hostname 2>/dev/null || true
  ;;
esac

current_lan_ip="\$(uci -q get network.lan.ipaddr)"
case "\${current_lan_ip}" in
  ""|192.168.1.1)
    uci -q set network.lan.ipaddr="\${gzos_lan_ip}"
    uci -q commit network
  ;;
esac

if [ -f /etc/openwrt_release ]; then
  sed -i \
    -e '/^DISTRIB_DESCRIPTION=/d' \
    -e '/^DISTRIB_REVISION=/d' \
    /etc/openwrt_release
  echo "DISTRIB_REVISION='\${gzos_release_revision}'" >> /etc/openwrt_release
  echo "DISTRIB_DESCRIPTION='\${gzos_hostname} '" >> /etc/openwrt_release
fi

if [ -f /usr/lib/os-release ]; then
  sed -i \
    -e "s|^NAME=.*|NAME=\"\${gzos_hostname}\"|g" \
    -e "s|^PRETTY_NAME=.*|PRETTY_NAME=\"\${gzos_hostname}\"|g" \
    -e "s|^OPENWRT_RELEASE=.*|OPENWRT_RELEASE=\"\${gzos_hostname} \${gzos_release_revision}\"|g" \
    /usr/lib/os-release
fi

rm -rf /tmp/luci-modulecache/
rm -f /tmp/luci-indexcache

exit 0
EOF
  chmod 755 package/base-files/files/etc/uci-defaults/99-gzos-defaults
}
