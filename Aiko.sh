#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

version="v1.0.0"

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Lỗi: ${plain} Kịch bản này phải được chạy bằng cách sử dụng người dùng root!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}Phiên bản hệ thống không được phát hiện, vui lòng liên hệ với tác giả tập lệnh!${plain}\n" && exit 1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Vui lòng sử dụng CentOS 7 hoặc phiên bản mới hơn của hệ thống!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Vui lòng sử dụng Ubuntu 16 hoặc phiên bản mới hơn của hệ thống!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Vui lòng sử dụng Debian 8 hoặc phiên bản mới hơn của hệ thống!${plain}\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [Mặc định$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Có khởi động Aiko lại hay không?" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Nhấn trở lại để trở về menu chính: ${plain}" && read temp
    show_menu
}

install() {
    bash -c "$(curl -L https://github.com/AikoCute/Xray-install/raw/main/install-release.sh)" @ install
    bash <(curl -Ls https://raw.githubusercontent.com/AikoCute/Aiko-install/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}
update_xray(){
  bash -c "$(curl -L https://github.com/AikoCute/Xray-install/raw/main/install-release.sh)" @ install
  return 0
}
update() {
    if [[ $# == 0 ]]; then
        echo && echo -n -e "Nhập phiên bản được chỉ định (phiên bản mới nhất mặc định).): " && read version
    else
        version=$2
    fi
#    confirm "Tính năng này sẽ buộc phải cài đặt lại phiên bản mới nhất hiện tại, dữ liệu sẽ không bị mất, bạn có tiếp tục không?" "n"
#    if [[ $? != 0 ]]; then
#        echo -e "${red}Đã hủy bỏ${plain}"
#        if [[ $1 != 0 ]]; then
#            before_show_menu
#        fi
#        return 0
#    fi
    bash <(curl -Ls https://raw.githubusercontent.com/AikoCute/Aiko-install/master/install.sh) $version
    if [[ $? == 0 ]]; then
        echo -e "${green}Bản cập nhật hoàn tất và Aiko đã được tự động khởi động lại, vui lòng xem nhật ký đang chạy bằng cách sử dụng nhật ký xem trong trang menu${plain}"
        exit
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

config() {
    cat /usr/local/etc/Aiko/Aiko.json
}

uninstall() {
    confirm "Bạn có chắc bạn muốn gỡ cài đặt Aiko không?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop Aiko
    systemctl disable Aiko
    rm /etc/systemd/system/Aiko.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /usr/local/etc/Aiko/ -rf
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove
    echo ""
    echo -e "Gỡ cài đặt thành công và nếu bạn muốn xóa tập lệnh này, hãy chạy sau khi thoát khỏi tập lệnh ${green}rm /usr/bin/Aiko -f${plain} Để xóa"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}Aiko đang chạy và không cần khởi động lại, vui lòng chọn Khởi động lại nếu bạn muốn khởi động lại${plain}"
    else
        systemctl start Aiko
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}Aiko khởi động thành công, hãy sử dụng xem nhật ký chạy${plain}"
        else
            echo -e "${red}Aiko có thể khởi động không thành công, vui lòng sử dụng menu để xem thông tin nhật ký sau${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    systemctl stop Aiko
    sleep 2
    check_status
    if [[ $? == 1 ]]; then
        echo -e "${green}Aiko dừng thành công${plain}"
    else
        echo -e "${red}Aiko dừng lại thất bại, có thể là do thời gian dừng vượt quá hai giây, vui lòng kiểm tra thông tin nhật ký sau${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart Aiko
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}Khởi động lại Aiko thành công, hãy sử dụng menu để xem nhật ký đang chạy${plain}"
    else
        echo -e "${red}Aiko có thể khởi động không thành công, vui lòng sử dụng menu để xem thông tin nhật ký sau${plain}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status Aiko --no-pager -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable Aiko
    if [[ $? == 0 ]]; then
        echo -e "${green}Thiết lập Aiko khởi động thành công${plain}"
    else
        echo -e "${red}Thiết lập Aiko tự khởi động thất bại${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable Aiko
    if [[ $? == 0 ]]; then
        echo -e "${green}Aiko hủy bỏ việc khởi động thành công${plain}"
    else
        echo -e "${red}Aiko hủy bỏ khởi động tự khởi động thất bại${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u Aiko.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

install_bbr() {
    bash <(curl -L -s https://raw.githubusercontent.com/AikoCute/BBR/aiko/tcp.sh)
    #if [[ $? == 0 ]]; then
    #    echo ""
    #    echo -e "${green}Cài đặt bbr thành công, khởi động lại máy chủ${plain}"
    #else
    #    echo ""
    #    echo -e "${red}Tải xuống tập lệnh cài đặt bbr không thành công, vui lòng kiểm tra xem máy có thể kết nối Github hay không${plain}"
    #fi

    #before_show_menu
}

update_shell() {
    wget -O /usr/bin/Aiko -N --no-check-certificate https://raw.githubusercontent.com/AikoCute/Aiko-install/master/Aiko.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}Tập lệnh tải xuống không thành công, vui lòng kiểm tra xem máy có thể kết nối Github hay không${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/Aiko
        echo -e "${green}Nâng cấp kịch bản thành công, chạy lại tập lệnh${plain}" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/Aiko.service ]]; then
        return 2
    fi
    temp=$(systemctl status Aiko | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled Aiko)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1;
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red}Aiko đã được cài đặt và vui lòng không cài đặt lại${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red}Vui lòng cài đặt Aiko trước${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

acme() {
  mkdir -p /usr/local/share/Aiko/
  chmod -R 755 /usr/local/share/Aiko
  cert_path="/usr/local/share/Aiko/server.crt"
  key_path="/usr/local/share/Aiko/server.key"
  rm /usr/local/share/Aiko/server.key
  rm /usr/local/share/Aiko/server.crt
  curl  https://get.acme.sh | sh
  alias acme.sh=~/.acme.sh/acme.sh
  source ~/.bashrc
  
  ~/.acme.sh/acme.sh --set-default-ca  --server  letsencrypt
  read -r -p "Input domain: " domain

  echo && echo -e "Choose type:
  1. http
  2. dns (only support cloudflare)"
  read -r -p "Choose type: " issue_type

  if [ "$issue_type" == "1" ]; then
    echo && echo -e "Choose HTTP type:
    1. web path
    2. nginx
    3. apache
    4. use 80 port"
    read -r -p "Choose type: " http_type

    if [ "$http_type" == "1" ]; then
      read -r -p "Input web path: " web_path
      ~/.acme.sh/acme.sh  --issue  -d "${domain}" --webroot  "${web_path}" --fullchain-file "${cert_path}" --key-file "${key_path}" --force
      return 0
    elif [ "$http_type" == "2" ]; then
      ~/.acme.sh/acme.sh  --issue  -d "${domain}" --nginx --fullchain-file "${cert_path}" --key-file "${key_path}" --force
      return 0
    elif [ "$http_type" == "3" ]; then
      read -r -p "Input web path: " web_path
      ~/.acme.sh/acme.sh  --issue  -d "${domain}" --apache --fullchain-file "${cert_path}" --key-file "${key_path}" --force
      return 0
    elif [ "$http_type" == "4" ]; then
      ~/.acme.sh/acme.sh  --issue  -d "${domain}" --standalone --fullchain-file "${cert_path}" --key-file "${key_path}" --force
      return 0
    fi

  fi

  if [ "$issue_type" == "2" ]; then
    echo && echo -e "Choose a DNS provider:
    1. CloudFlare
    2. AliYun
    3. DNSPod(Tencent)"
    read -r -p "Choose: " dns_type

    if [ "$dns_type" == "1" ]; then
      read -r -p "Input your CloudFlare Email: " cf_email
      export CF_Email="${cf_email}"
      read -r -p "Input your CloudFlare Global API Key: " cf_key
      export CF_Key="${cf_key}"

      ~/.acme.sh/acme.sh  --issue  -d "${domain}" --dns dns_cf --fullchain-file "${cert_path}" --key-file "${key_path}" --force
    elif [ "$dns_type" == "2" ]; then
      read -r -p "Input your Ali Key: " Ali_Key
      export Ali_Key="${Ali_Key}"
      read -r -p "Input your Ali Secret: " Ali_Secret
      export Ali_Secret="${Ali_Secret}"

      ~/.acme.sh/acme.sh  --issue  -d "${domain}" --dns dns_ali --fullchain-file "${cert_path}" --key-file "${key_path}" --force
    elif [ "$dns_type" == "3" ]; then
      read -r -p "Input your DNSPod ID: " DP_Id
      export DP_Id="${DP_Id}"
      read -r -p "Input your DNSPod Key: " DP_Key
      export DP_Key="${DP_Key}"

      ~/.acme.sh/acme.sh  --issue  -d "${domain}" --dns dns_dp --fullchain-file "${cert_path}" --key-file "${key_path}" --force
    fi

  fi

  chmod -R 755 /usr/local/share/Aiko/
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
    # Do not combine this judgment condition with the following judgment condition.
    ## Be aware of Linux distribution like Gentoo, which kernel supports switch between Systemd and OpenRC.
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

get_latest_Aiko_version() {
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

update_Aiko() {
  Aiko_url="https://github.com/AikoCute/Aiko/releases/download/${VERSION}/Aiko-linux-${MACHINE}.zip"

  wget -N  ${Aiko_url} -O ./Aiko.zip
  unzip ./Aiko.zip -d /usr/local/bin/
  rm ./Aiko.zip
  rm /usr/local/bin/Aiko
  mv /usr/local/bin/Aiko /usr/local/bin/Aiko
  chmod +x /usr/local/bin/Aiko
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "Trạng thái Aiko: ${green}Đang chạy${plain}"
            show_enable_status
            ;;
        1)
            echo -e "Trạng thái Aiko: ${yellow}Không chạy${plain}"
            show_enable_status
            ;;
        2)
            echo -e "Trạng thái Aiko: ${red}Không được cài đặt${plain}"
    esac
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Có bật nguồn hay không: ${green}Vâng${plain}"
    else
        echo -e "Có bật nguồn hay không: ${red}Không${plain}"
    fi
}

show_Aiko_version() {
    echo -n "Phiên bản Aiko："
    /usr/local/bin/Aiko -v
    /usr/local/bin/xray -v
    echo ""
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_usage() {
    echo "Aiko Quản lý phương pháp sử dụng tập lệnh: "
    echo "------------------------------------------"
    echo "Aiko              - Hiển thị menu quản lý (nhiều tính năng hơn)"
    echo "Aiko start        - Bắt đầu Aiko"
    echo "Aiko stop         - Dừng lại Aiko"
    echo "Aiko restart      - Chạy lại Aiko"
    echo "Aiko status       - Xem trạng thái Aiko"
    echo "Aiko enable       - Thiết lập Aiko để khởi động"
    echo "Aiko disable      - Hủy Aiko để khởi động"
    echo "Aiko log          - Xem nhật ký Aiko"
    echo "Aiko update x.x.x - Chỉ định phiên bản Aiko"
    echo "Aiko install      - Cài đặt Aiko"
    echo "Aiko uninstall    - Gỡ cài đặt Aiko"
    echo "Aiko version      - Phiên bản Aiko"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}Aiko Kịch bản quản lý back-end，${plain}${red}Không áp dụng cho docker${plain}
--- https://github.com/AikoCute/Aiko ---
  ${green}0.${plain} Thoát khỏi kịch bản
————————————————
  ${green}1.${plain} Cài đặt Aiko
  ${green}2.${plain} Sử dụng ACME để nhận chứng chỉ SSL
  ${green}3.${plain} Gỡ cài đặt Aiko
————————————————
  ${green}4.${plain} Khởi động Aiko
  ${green}5.${plain} Dừng Aiko
  ${green}6.${plain} Khởi động lại Aiko
  ${green}7.${plain} Xem trạng thái Aiko
  ${green}8.${plain} Xem nhật kí Aiko
————————————————
  ${green}9.${plain} Đặt Aiko tự động khởi động
 ${green}10.${plain} Hủy khởi động Aiko tự động
————————————————
 ${green}11.${plain} Cài đặt 1 cú nhấp chuột bbr (mới nhất)
 ${green}12.${plain} Xem phiên bản Aiko & Xray
 ${green}13.${plain} Nâng cấp nhân Xray
 ${green}14.${plain} Nâng cấp Aiko
 "
 # Cập nhật tiếp theo có thể được thêm vào chuỗi trên
    show_status
    echo && read -p "Vui lòng nhập một lựa chọn [0-14]: " num

    case "${num}" in
        0) exit 0
        ;;
        1) check_uninstall && install
        ;;
        2) check_install && acme && restart
        ;;
        3) check_install && uninstall
        ;;
        4) check_install && start
        ;;
        5) check_install && stop
        ;;
        6) check_install && restart
        ;;
        7) check_install && status
        ;;
        8) check_install && show_log
        ;;
        9) check_install && enable
        ;;
        10) check_install && disable
        ;;
        11) install_bbr
        ;;
        12) check_install && show_Aiko_version
        ;;
        13) check_install && update_xray && restart
        ;;
        14) check_install && identify_the_operating_system_and_architecture && get_latest_Aiko_version && update_Aiko && restart
        ;;
        *) echo -e "${red}Vui lòng nhập số chính xác [0-14]${plain}"
        ;;
    esac
}


if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0
        ;;
        "stop") check_install 0 && stop 0
        ;;
        "restart") check_install 0 && restart 0
        ;;
        "status") check_install 0 && status 0
        ;;
        "enable") check_install 0 && enable 0
        ;;
        "disable") check_install 0 && disable 0
        ;;
        "log") check_install 0 && show_log 0
        ;;
        "update") check_install 0 && update 0 $2
        ;;
        "config") config $*
        ;;
        "install") check_uninstall 0 && install 0
        ;;
        "uninstall") check_install 0 && uninstall 0
        ;;
        "version") check_install 0 && show_Aiko_version 0
        ;;
        "update_shell") update_shell
        ;;
        *) show_usage
    esac
else
    show_menu
fi
