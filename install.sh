#!/bin/bash

VERSION=""
APP_PATH="/usr/local/bin/"
CONFIG_PATH="/usr/local/etc/Aiko/"


create_folders() {
  if [[ ! -e "${APP_PATH}" ]]; then
    mkdir "${APP_PATH}"
  fi
  if [[ ! -e "${CONFIG_PATH}" ]]; then
    mkdir "${CONFIG_PATH}"
  fi

}

panelConfig() {
  echo "Aiko $VERSION + Xray"
  echo "########Aiko config#######"
  read -r -p "Enter panel domain(Include https:// or http://): " pUrl
  read -r -p "Enter panel token: " nKey
  read -r -p "Enter node_ids, (eg 1,2,3): " nIds
  echo && echo -e "Choose panel type:
  1. SSPanel
  2. V2board
  3. Django-sspanel"
  read -r -p "Choose panel type: " panelnum
  if [ "$panelnum" == "1" ]; then
    panelType="sspanel"
  fi
  if [ "$panelnum" == "2" ]; then
    panelType="v2board"
    read -r -p "Enter nodes type, (eg \"vmess\",\"ss\",\"trojan\")(DON'T FORGET '\"'): " nType
  fi
  if [ "$panelnum" == "3" ]; then
    panelType="django-sspanel"
    read -r -p "Enter nodes type, (eg \"vmess\",\"ss\",\"trojan\")(DON'T FORGET '\"'): " nType
  fi
}

check_root() {
  [[ $EUID != 0 ]] && echo -e "${Error} Tài khoản ROOT hiện tại không phải là tài khoản (hoặc không có quyền ROOT) và không thể tiếp tục, vui lòng thay thế tài khoản ROOT hoặc sử dụng ${Green_background_prefix}sudo su${Font_color_suffix} Lệnh lấy quyền ROOT tạm thời (mật khẩu cho tài khoản hiện tại có thể được nhắc sau khi thực hiện)." && exit 1
}
check_sys() {
  if [[ -f /etc/redhat-release ]]; then
    release="centos"
  elif cat /etc/issue | grep -q -E -i "debian"; then
    release="debian"
  elif cat /etc/issue | grep -q -E -i "ubuntu"; then
    release="ubuntu"
  elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
    release="centos"
  elif cat /proc/version | grep -q -E -i "debian"; then
    release="debian"
  elif cat /proc/version | grep -q -E -i "ubuntu"; then
    release="ubuntu"
  elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
    release="centos"
  fi
  bit=$(uname -m)
}
Installation_dependency() {
  if [[ ${release} == "centos" ]]; then
    yum update -y
    yum install -y gzip ca-certificates curl unzip socat
  else
    apt-get update -y
    apt-get install -y ca-certificates curl unzip socat
  fi
  cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
  mkdir /var/log/Aiko
  chown -R nobody /var/log/Aiko
}
download() {
  mkdir /usr/local/etc/Aiko/
  airuniverse_url="https://github.com/AikoCute/Aiko/releases/download/${VERSION}/Aiko-linux-${MACHINE}.zip"
  xray_json_url="https://raw.githubusercontent.com/AikoCute/Aiko-install/master/xray_config.json"

  mv /usr/local/etc/xray/config.json /usr/local/etc/xray/config.json.bak
  wget -N  ${xray_json_url} -O /usr/local/etc/xray/config.json
  wget -N  ${airuniverse_url} -O ./Aiko.zip
  unzip ./Aiko.zip -d /usr/local/bin/
  rm ./Aiko.zip
  mv /usr/local/bin/Aiko /usr/local/bin/Aiko
  chmod +x /usr/local/bin/Aiko

}

identify_the_operating_system_and_architecture() {
  if [[ "$(uname)" == 'Linux' ]]; then
    case "$(uname -m)" in
      'i386' | 'i686')
        MACHINE='32'
        ;;
      'amd64' | 'x86_64')
        MACHINE='64'
        ;;
      'armv5tel')
        MACHINE='arm32-v5'
        ;;
      'armv6l')
        MACHINE='arm32-v6'
        grep Features /proc/cpuinfo | grep -qw 'vfp' || MACHINE='arm32-v5'
        ;;
      'armv7' | 'armv7l')
        MACHINE='arm32-v7a'
        grep Features /proc/cpuinfo | grep -qw 'vfp' || MACHINE='arm32-v5'
        ;;
      'armv8' | 'aarch64')
        MACHINE='arm64-v8a'
        ;;
      'mips')
        MACHINE='mips32'
        ;;
      'mipsle')
        MACHINE='mips32le'
        ;;
      'mips64')
        MACHINE='mips64'
        ;;
      'mips64le')
        MACHINE='mips64le'
        ;;
      'ppc64')
        MACHINE='ppc64'
        ;;
      'ppc64le')
        MACHINE='ppc64le'
        ;;
      'riscv64')
        MACHINE='riscv64'
        ;;
      's390x')
        MACHINE='s390x'
        ;;
      *)
        echo "error: The architecture is not supported."
        exit 1
        ;;
    esac
    if [[ ! -f '/etc/os-release' ]]; then
      echo "error: Don't use outdated Linux distributions."
      exit 1
    fi
    # Không kết hợp điều kiện phán xét này với điều kiện phán xét sau đây.
    # Hãy nhận thức được phân phối Linux như Gentoo, hạt nhân hỗ trợ chuyển đổi giữa Systemd và OpenRC.
    if [[ -f /.dockerenv ]] || grep -q 'docker\|lxc' /proc/1/cgroup && [[ "$(type -P systemctl)" ]]; then
      true
    elif [[ -d /run/systemd/system ]] || grep -q systemd <(ls -l /sbin/init); then
      true
    else
      echo "error: Only Linux distributions using systemd are supported."
      exit 1
    fi
    if [[ "$(type -P apt)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='apt -y --no-install-recommends install'
      PACKAGE_MANAGEMENT_REMOVE='apt purge'
      package_provide_tput='ncurses-bin'
    elif [[ "$(type -P dnf)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='dnf -y install'
      PACKAGE_MANAGEMENT_REMOVE='dnf remove'
      package_provide_tput='ncurses'
    elif [[ "$(type -P yum)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='yum -y install'
      PACKAGE_MANAGEMENT_REMOVE='yum remove'
      package_provide_tput='ncurses'
    elif [[ "$(type -P zypper)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='zypper install -y --no-recommends'
      PACKAGE_MANAGEMENT_REMOVE='zypper remove'
      package_provide_tput='ncurses-utils'
    elif [[ "$(type -P pacman)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='pacman -Syu --noconfirm'
      PACKAGE_MANAGEMENT_REMOVE='pacman -Rsn'
      package_provide_tput='ncurses'
    else
      echo "error: The script does not support the package manager in this operating system."
      exit 1
    fi
  else
    echo "error: This operating system is not supported."
    exit 1
  fi
}


get_latest_version() {
  # Get Xray latest release version number
  local tmp_file
  tmp_file="$(mktemp)"
  if ! curl -x "${PROXY}" -sS -H "Accept: application/vnd.github.v3+json" -o "$tmp_file" 'https://api.github.com/repos/AikoCute/Aiko/releases/latest'; then
    "rm" "$tmp_file"
    echo 'error: Failed to get release list, please check your network.'
    exit 1
  fi
  RELEASE_LATEST="$(sed 'y/,/\n/' "$tmp_file" | grep 'tag_name' | awk -F '"' '{print $4}')"
  if [[ -z "$RELEASE_LATEST" ]]; then
    if grep -q "API rate limit exceeded" "$tmp_file"; then
      echo "error: github API rate limit exceeded"
    else
      echo "error: Failed to get the latest release version."
      echo "Welcome bug report:https://github.com/AikoCute/Aiko/issues"
    fi
    "rm" "$tmp_file"
    exit 1
  fi
  "rm" "$tmp_file"
  VERSION="v${RELEASE_LATEST#v}"
}
makeConfig() {
  mkdir -p /usr/lib/systemd/system/
  cat >/usr/local/etc/Aiko/Aiko.json <<EOF
{
  "panel": {
    "type": "${panelType}",
    "url": "${pUrl}",
    "key": "${nKey}",
    "node_ids": [${nIds}],
    "nodes_type": [${nType}]
  },
  "proxy": {
    "type":"xray"
  }
}
EOF
chmod 644 /usr/local/etc/Aiko/Aiko.json
}

createService() {
  service_file="https://raw.githubusercontent.com/AikoCute/Aiko-install/master/Aiko.service"
  wget -N  -O /etc/systemd/system/Aiko.service ${service_file}
  chmod 644 /etc/systemd/system/Aiko.service
  systemctl daemon-reload
}

check_root
check_sys
Installation_dependency
get_latest_version
identify_the_operating_system_and_architecture
panelConfig
download
makeConfig
createService

systemctl enable Aiko
systemctl restart xray
systemctl start Aiko
