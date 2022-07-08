#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# Current folder
cur_dir=$(pwd)
# Color
red='\033[0;31m'
green='\033[0;32m'
#yellow='\033[0;33m'
plain='\033[0m'
operation=(Install Update UpdateConfig logs restart delete)
# Make sure only root can run our script
[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] Chưa vào root kìa !, vui lòng xin phép ROOT trước!" && exit 1

#Check system
check_sys() {
  local checkType=$1
  local value=$2
  local release=''
  local systemPackage=''

  if [[ -f /etc/redhat-release ]]; then
    release="centos"
    systemPackage="yum"
  elif grep -Eqi "debian|raspbian" /etc/issue; then
    release="debian"
    systemPackage="apt"
  elif grep -Eqi "ubuntu" /etc/issue; then
    release="ubuntu"
    systemPackage="apt"
  elif grep -Eqi "centos|red hat|redhat" /etc/issue; then
    release="centos"
    systemPackage="yum"
  elif grep -Eqi "debian|raspbian" /proc/version; then
    release="debian"
    systemPackage="apt"
  elif grep -Eqi "ubuntu" /proc/version; then
    release="ubuntu"
    systemPackage="apt"
  elif grep -Eqi "centos|red hat|redhat" /proc/version; then
    release="centos"
    systemPackage="yum"
  fi

  if [[ "${checkType}" == "sysRelease" ]]; then
    if [ "${value}" == "${release}" ]; then
      return 0
    else
      return 1
    fi
  elif [[ "${checkType}" == "packageManager" ]]; then
    if [ "${value}" == "${systemPackage}" ]; then
      return 0
    else
      return 1
    fi
  fi
}

# Get version
getversion() {
  if [[ -s /etc/redhat-release ]]; then
    grep -oE "[0-9.]+" /etc/redhat-release
  else
    grep -oE "[0-9.]+" /etc/issue
  fi
}

# CentOS version
centosversion() {
  if check_sys sysRelease centos; then
    local code=$1
    local version="$(getversion)"
    local main_ver=${version%%.*}
    if [ "$main_ver" == "$code" ]; then
      return 0
    else
      return 1
    fi
  else
    return 1
  fi
}

get_char() {
  SAVEDSTTY=$(stty -g)
  stty -echo
  stty cbreak
  dd if=/dev/tty bs=1 count=1 2>/dev/null
  stty -raw
  stty echo
  stty $SAVEDSTTY
}
error_detect_depends() {
  local command=$1
  local depend=$(echo "${command}" | awk '{print $4}')
  echo -e "[${green}Info${plain}] Bắt đầu cài đặt các gói ${depend}"
  ${command} >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo -e "[${red}Error${plain}] Cài đặt gói không thành công ${red}${depend}${plain}"
    exit 1
  fi
}

# Pre-installation settings
pre_install_docker_compose() {
#install key_path
    echo -e "[${Green}Key Hợp Lệ${plain}] Link Web : https://aikocute.com"
    read -p " ID nút (Node_ID_Vmess):" node_id_vmess
    [ -z "${node_id_vmess}" ] && node_id=0
    echo "-------------------------------"
    echo -e "Node_ID: ${node_id_vmess}"
    echo "-------------------------------"

    read -p " ID nút (Node_ID_Trojan):" node_id_trojan
    [ -z "${node_id_trojan}" ] && node_id=0
    echo "-------------------------------"
    echo -e "Node_ID: ${node_id_trojan}"
    echo "-------------------------------"

    read -p "Vui long nhập CertDomain :" CertDomain
    [ -z "${CertDomain}" ] && CertDomain=0
    echo "-------------------------------"
    echo -e "Domain: ${CertDomain}"
    echo "-------------------------------"

# giới hạn tốc độ
    read -p " Giới hạn tốc độ (Mbps):" limit_speed
    [ -z "${limit_speed}" ] && limit_speed=0
    echo "-------------------------------"
    echo -e "Giới hạn tốc độ: ${limit_speed}"
    echo "-------------------------------"

# giới hạn thiết bị
    read -p " Giới hạn thiết bị (Limit):" limit
    [ -z "${limit}" ] && limit=0
    echo "-------------------------------"
    echo -e "Limit: ${limit}"
    echo "-------------------------------"
}

# Config docker
config_docker() {
  cd ${cur_dir} || exit
  echo "Bắt đầu cài đặt các gói"
  install_dependencies
  echo "Tải tệp cấu hình DOCKER"
  cat >docker-compose.yml <<EOF
version: '3'
services: 
  xrayr: 
    image: aikocute/xrayr:latest
    volumes:
      - ./aiko.yml:/etc/XrayR/aiko.yml # thư mục cấu hình bản đồ
      - ./dns.json:/etc/XrayR/dns.json 
      - ./AikoBlock:/etc/XrayR/AikoBlock
      - ./server.pem:/etc/XrayR/server.pem
      - ./privkey.pem:/etc/XrayR/privkey.pem
    restart: always
    network_mode: host
EOF
  cat >dns.json <<EOF
{
    "servers": [
        "1.1.1.1",
        "8.8.8.8",
        "localhost"
    ],
    "tag": "dns_inbound"
}
EOF

  cat >aiko.yml <<EOF
Log:
  Level: none # Log level: none, error, warning, info, debug 
  AccessPath: # /etc/XrayR/access.Log
  ErrorPath: # /etc/XrayR/error.log
DnsConfigPath: # /etc/XrayR/dns.json # Path to dns config, check https://xtls.github.io/config/dns.html for help
RouteConfigPath: # /etc/XrayR/route.json # Path to route config, check https://xtls.github.io/config/routing.html for help
InboundConfigPath: # /etc/XrayR/custom_inbound.json # Path to custom inbound config, check https://xtls.github.io/config/inbound.html for help
OutboundConfigPath: # /etc/XrayR/custom_outbound.json # Path to custom outbound config, check https://xtls.github.io/config/outbound.html for help
ConnetionConfig:
  Handshake: 4 # Handshake time limit, Second
  ConnIdle: 86400 # Connection idle time limit, Second
  UplinkOnly: 2 # Time limit when the connection downstream is closed, Second
  DownlinkOnly: 4 # Time limit when the connection is closed after the uplink is closed, Second
  BufferSize: 64 # The internal cache size of each connection, kB 
Nodes:
  -
    PanelType: "V2board" # Panel type: SSpanel, V2board, PMpanel, Proxypanel
    ApiConfig:
      ApiHost: "https://zapterdata.com"
      ApiKey: "zapterdatazapterdatazapterdata"
      NodeID: $node_id_trojan
      NodeType: Trojan # Node type: V2ray, Trojan, Shadowsocks, Shadowsocks-Plugin
      Timeout: 30 # Timeout for the api request
      EnableVless: false # Enable Vless for V2ray Type
      EnableXTLS: false # Enable XTLS for V2ray and Trojan
      SpeedLimit: $limit_speed # Mbps, Local settings will replace remote settings, 0 means disable
      DeviceLimit: $limit # Local settings will replace remote settings, 0 means disable
      RuleListPath: /etc/XrayR/AikoBlock # ./rulelist Path to local rulelist file
    ControllerConfig:
      ListenIP: 0.0.0.0 # IP address you want to listen
      SendIP: 0.0.0.0 # IP address you want to send pacakage
      UpdatePeriodic: 60 # Time to update the nodeinfo, how many sec.
      EnableDNS: false # Use custom DNS config, Please ensure that you set the dns.json well
      DNSType: AsIs # AsIs, UseIP, UseIPv4, UseIPv6, DNS strategy
      DisableUploadTraffic: false # Disable Upload Traffic to the panel
      DisableGetRule: false # Disable Get Rule from the panel
      DisableIVCheck: false # Disable the anti-reply protection for Shadowsocks
      EnableProxyProtocol: false # Only works for WebSocket and TCP
      EnableFallback: false # Only support for Trojan and Vless
      FallBackConfigs:  # Support multiple fallbacks
        -
          SNI: # TLS SNI(Server Name Indication), Empty for any
          Path: # HTTP PATH, Empty for any
          Dest: 80 # Required, Destination of fallback, check https://xtls.github.io/config/fallback/ for details.
          ProxyProtocolVer: 0 # Send PROXY protocol version, 0 for dsable
      CertConfig:
        CertMode: file # Option about how to get certificate: none, file, http, dns. Choose "none" will forcedly disable the tls config.
        CertDomain: "$CertDomain" # Domain to cert
        CertFile: /etc/XrayR/server.pem # Provided if the CertMode is file
        KeyFile: /etc/XrayR/privkey.pem
        Provider: cloudflare # DNS cert provider, Get the full support list here: https://go-acme.github.io/lego/dns/
        Email: test@me.com
        DNSEnv: # DNS ENV option used by DNS provider
          CLOUDFLARE_EMAIL: aaa
          CLOUDFLARE_API_KEY: bbb
  -
    PanelType: "V2board" # Panel type: SSpanel, V2board, PMpanel, Proxypanel
    ApiConfig:
      ApiHost: "https://zapterdata.com"
      ApiKey: "zapterdatazapterdatazapterdata"
      NodeID: $node_id_vmess
      NodeType: V2ray # Node type: V2ray, Trojan, Shadowsocks, Shadowsocks-Plugin
      Timeout: 30 # Timeout for the api request
      EnableVless: false # Enable Vless for V2ray Type
      EnableXTLS: false # Enable XTLS for V2ray and Trojan
      SpeedLimit: $limit_speed # Mbps, Local settings will replace remote settings, 0 means disable
      DeviceLimit: $limit # Local settings will replace remote settings, 0 means disable
      RuleListPath: /etc/XrayR/AikoBlock # ./rulelist Path to local rulelist file
    ControllerConfig:
      ListenIP: 0.0.0.0 # IP address you want to listen
      SendIP: 0.0.0.0 # IP address you want to send pacakage
      UpdatePeriodic: 60 # Time to update the nodeinfo, how many sec.
      EnableDNS: false # Use custom DNS config, Please ensure that you set the dns.json well
      DNSType: AsIs # AsIs, UseIP, UseIPv4, UseIPv6, DNS strategy
      DisableUploadTraffic: false # Disable Upload Traffic to the panel
      DisableGetRule: false # Disable Get Rule from the panel
      DisableIVCheck: false # Disable the anti-reply protection for Shadowsocks
      EnableProxyProtocol: false # Only works for WebSocket and TCP
      EnableFallback: false # Only support for Trojan and Vless
      FallBackConfigs:  # Support multiple fallbacks
        -
          SNI: # TLS SNI(Server Name Indication), Empty for any
          Path: # HTTP PATH, Empty for any
          Dest: 80 # Required, Destination of fallback, check https://xtls.github.io/config/fallback/ for details.
          ProxyProtocolVer: 0 # Send PROXY protocol version, 0 for dsable
      CertConfig:
        CertMode: file # Option about how to get certificate: none, file, http, dns. Choose "none" will forcedly disable the tls config.
        CertDomain: "$CertDomain" # Domain to cert
        CertFile: /etc/XrayR/server.pem # Provided if the CertMode is file
        KeyFile: /etc/XrayR/privkey.pem
        Provider: cloudflare # DNS cert provider, Get the full support list here: https://go-acme.github.io/lego/dns/
        Email: test@me.com
        DNSEnv: # DNS ENV option used by DNS provider
          CLOUDFLARE_EMAIL: aaa
          CLOUDFLARE_API_KEY: bbb
EOF

    cat >server.pem <<EOF
    -----BEGIN CERTIFICATE-----
MIIEFTCCAv2gAwIBAgIUZneI9wUsELsjLfAwjC563d5A9nQwDQYJKoZIhvcNAQEL
BQAwgagxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpDYWxpZm9ybmlhMRYwFAYDVQQH
Ew1TYW4gRnJhbmNpc2NvMRkwFwYDVQQKExBDbG91ZGZsYXJlLCBJbmMuMRswGQYD
VQQLExJ3d3cuY2xvdWRmbGFyZS5jb20xNDAyBgNVBAMTK01hbmFnZWQgQ0EgNWM2
OGE1MTQ3MWMwNGQ2MmM2MjEzZTAyNDZlOTFkYzUwHhcNMjIwNjI2MDM1NzAwWhcN
MzIwNjIzMDM1NzAwWjAiMQswCQYDVQQGEwJVUzETMBEGA1UEAxMKQ2xvdWRmbGFy
ZTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJ/xVRoOZ5lka5rNnVuf
dn0c6FgGboblPcDZC9S5I+QyqcmQmBY31qLfJwM+ZesE3cfwfKf8DeJJ8SV1in3y
6fKISvdDFvB31peLYWgJ5S4ByZXccSgv2v/eZgdXN749vx7eL+jsGIXTFX6PVJK9
djiSjladu/cpnW76+eyRmH0uzdPEbdgfNahusUvgBGzELNkKK6qVSDG7OyveoLGI
v/UKJMFw0q84DncTxR7ED62E4L6f/xF+fk3UiChB7jTpQ/uB5FUcxJThtF3XaBlW
P0HzDjDRQDsmdj9Q1qrbHOszjPXld2Tk2CNF/miKGFUkSt/aZVum9py6V8cmyO4J
3KsCAwEAAaOBuzCBuDATBgNVHSUEDDAKBggrBgEFBQcDAjAMBgNVHRMBAf8EAjAA
MB0GA1UdDgQWBBQC+dUZpSiHWpOM9jtPLcmYb7ssLDAfBgNVHSMEGDAWgBR3M4Hi
8b9z3GcZK1kjtavLGxjAsDBTBgNVHR8ETDBKMEigRqBEhkJodHRwOi8vY3JsLmNs
b3VkZmxhcmUuY29tL2E4MzY0ZmU3LWJmNzktNGIwNi05NzFjLTU0YTEwZjNmOTUw
My5jcmwwDQYJKoZIhvcNAQELBQADggEBAGHw/lL90uK1lqK5ItT0bQp+oMeaR/+K
+qo30yK6twGFqOBjx+WYNl5K4UUWbFuj/t7XQQMJHkNfs4wkJAr0c4QKExcSgtA+
4emMeJZBNDkb/B4QKmt74Sve8LCi5ETZ8gzbxNN9C4ygT8BZtfUPHK+zPhZ6S4iG
oOLifOyNh0H44Bdn8wYsjmynaLq6M09Dwsp8BVy3RsNUJ8OdO5/m6pKxcEWn7y1I
D+3SZgvkZQc0Ll6+PXm6QakyHMkd3yIwGhKzrCVllwfRFAV5azzd/fUHrN2ggc+n
/lfk9kKF4ErU0CSJpAtnzLfDbCMja3bh1aDQ+BK9RD5iJ0b6t8e/FAA=
-----END CERTIFICATE-----
EOF
    cat >privkey.pem <<EOF
    -----BEGIN PRIVATE KEY-----
MIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQCf8VUaDmeZZGua
zZ1bn3Z9HOhYBm6G5T3A2QvUuSPkMqnJkJgWN9ai3ycDPmXrBN3H8Hyn/A3iSfEl
dYp98unyiEr3Qxbwd9aXi2FoCeUuAcmV3HEoL9r/3mYHVze+Pb8e3i/o7BiF0xV+
j1SSvXY4ko5Wnbv3KZ1u+vnskZh9Ls3TxG3YHzWobrFL4ARsxCzZCiuqlUgxuzsr
3qCxiL/1CiTBcNKvOA53E8UexA+thOC+n/8Rfn5N1IgoQe406UP7geRVHMSU4bRd
12gZVj9B8w4w0UA7JnY/UNaq2xzrM4z15Xdk5NgjRf5oihhVJErf2mVbpvaculfH
JsjuCdyrAgMBAAECggEADVNUf/QU8o/jcoV7UkUMtgDLZNC9sv8fcCqafzx2Po7F
XECamI30vnjGwyZBjzKbwwreFTrSnKNaHtZWVbGq3Ho5e19Qu8koN6kKUloyCMK9
B6ooQq0LWx0C4CKxR2gqkl5NnI4rFDSRdQwTrkQbDjyQ9QDK8R07piGX4qYAupEi
ts6N5DtJOqIP4IhnDIO2Bsw1Gbduqb4fNXbrSMhjqY9wVGm56+iQFEYbXMoTsv58
0BP6s6pNe7Krz9szhWfLo5VRod2HdslccMV1cOS2pxLXXPp+NV+3KXwICWGQ9r94
XjA4OQeJ4NlN23oxEuMK8Ah0S578FE0KlHPl3T6oEQKBgQDbHcK3SCtmfXWhEJth
svSAg9z7CB7Z9+Bruy0XBbql1giz1yxh1pPmRiG7LtXDruuzSvw3vr044oM6RLVg
IJ6ltrrvRpeM7ztSDEm2pW+ATePtbeRPt9fqAcWVjLH24oRBzYzKwxD95O/juyWD
hKoBgrCDdtiz7Mf2lJF0H+NecQKBgQC63aSpF8kbTht9/iHv2QZC001HnKG4CcrD
JPvcv+0eedkyCJttlti/NyolXq0UkLbtZVl95wFTJA+OLLxmKtQNQE03z/Xb2tdk
RhJGJ867FmcUVGifCHK9ydqbNCMdkHOCf3hjbtXtdrz/1IwiXUaWpHsUZKnkS1tu
X2AMFnYy2wKBgB43tnisPT//IU+7CJKqqUln5fvAnPCWXJ6+y3MXWSwxnjWfAQHl
I7RoC5LS3KwF3X92Yd4WMeY8ZriMbS76kKZt0s3YwGGxRE8GXswPeJcLJtnBg/Dy
e5ZL9EGxi4Fur6qbfEUiLZ+2CNcxIfVHQGLA8TLQGwaFKvZ4eq63DxYhAoGAMcLM
EmtPFoJaN9bw2poEXM9ACQ3g0s1ovUaf+0zwq+juubApE6nT1jeudX0cwhk3XUhb
6HcXlzhHHCk1kk9dYJn69h3e7sj8CqvOOfhnyNJSaMuBgLgTNg8Gs8XShBDvcZTY
TkI5nZ68/bNwDcahAYSTcf7MbwrSMjYbsZxZpXkCgYAlIz4WeC1UhpvHGYiWhoQz
ZFY+UgqfX/xKR0eejb0xT3YJQ3FZ3nZ0BD4gfQfJ0jDq9qWpmIauGnD62S0rGL5h
hHMcdp53Z41MYceL3+VzlEpZWbRnjs56aDdW4wR6mrQj/k+Qo+5/Nw25kfCvVawB
m5vZHdzgevFHbLHKO6UNvg==
-----END PRIVATE KEY-----
EOF

    cat >AikoBlock <<EOF
catport.vn
cloudfast.vn
zingfast.net
zingfast.vn
speedtest.net
fast.com
speedtest.vn
speedsmart.net
speedcheck.org
speedof.me
testmy.net
bandwidthplace.com
speed.io
measurementlab.net
i-speed.vn
speedtest.vnpt.vn
speedtest.vtn.com.vn
nperf.com
speedtest.telstra.com
merter.net
ping-test.net
devicetests.com
speedtest.com.sg
speed.cloudflare.com
speedtest.vinahost.vn
thinkbroadband.com
speedtestcustom.com
speedtest.vegacdn.com
ooklaserver.net
speedtest.cesnet.cz
speakeasy.net
speedtest.midco.net
speedtest.xfinity.com
speedtest.googlefiber.net
speedtestcustom.com
EOF
}

# Install docker and docker compose
install_docker() {
  echo -e "bắt đầu cài đặt DOCKER "
 sudo apt-get update
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt-get install docker-ce docker-ce-cli containerd.io -y
systemctl start docker
systemctl enable docker
  echo -e "bắt đầu cài đặt Docker Compose "
curl -fsSL https://get.docker.com | bash -s docker
curl -L "https://github.com/docker/compose/releases/download/1.26.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
  echo "khởi động Docker "
  service docker start
  echo "khởi động Docker-Compose "
  docker-compose up -d
  echo
  echo -e "Đã hoàn tất cài đặt phụ trợ ！"
  echo -e "0 0 */3 * *  cd /root/${cur_dir} && /usr/local/bin/docker-compose pull && /usr/local/bin/docker-compose up -d" >>/etc/crontab
  echo -e "Cài đặt cập nhật thời gian kết thúc đã hoàn tất! hệ thống sẽ update sau [${green}24H${plain}] Từ lúc bạn cài đặt"
}

install_check() {
  if check_sys packageManager yum || check_sys packageManager apt; then
    if centosversion 5; then
      return 1
    fi
    return 0
  else
    return 1
  fi
}

install_dependencies() {
  if check_sys packageManager yum; then
    echo -e "[${green}Info${plain}] Kiểm tra kho EPEL ..."
    if [ ! -f /etc/yum.repos.d/epel.repo ]; then
      yum install -y epel-release >/dev/null 2>&1
    fi
    [ ! -f /etc/yum.repos.d/epel.repo ] && echo -e "[${red}Error${plain}] Không cài đặt được kho EPEL, vui lòng kiểm tra." && exit 1
    [ ! "$(command -v yum-config-manager)" ] && yum install -y yum-utils >/dev/null 2>&1
    [ x"$(yum-config-manager epel | grep -w enabled | awk '{print $3}')" != x"True" ] && yum-config-manager --enable epel >/dev/null 2>&1
    echo -e "[${green}Info${plain}] Kiểm tra xem kho lưu trữ EPEL đã hoàn tất chưa ..."

    yum_depends=(
      curl
    )
    for depend in ${yum_depends[@]}; do
      error_detect_depends "yum -y install ${depend}"
    done
  elif check_sys packageManager apt; then
    apt_depends=(
      curl
    )
    apt-get -y update
    for depend in ${apt_depends[@]}; do
      error_detect_depends "apt-get -y install ${depend}"
    done
  fi
  echo -e "[${green}Info${plain}] Đặt múi giờ thành Hồ Chí Minh GTM+7"
  ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh  /etc/localtime
  date -s "$(curl -sI g.cn | grep Date | cut -d' ' -f3-6)Z"

}

#update_image
Update_xrayr() {
  cd ${cur_dir}
  echo "Tải hình ảnh DOCKER"
  docker-compose pull
  echo "Bắt đầu chạy dịch vụ DOCKER"
  docker-compose up -d
}

#show last 100 line log

logs_xrayr() {
  echo "100 dòng nhật ký chạy sẽ được hiển thị"
  docker-compose logs --tail 100
}

# Update config
UpdateConfig_xrayr() {
  cd ${cur_dir}
  echo "đóng dịch vụ hiện tại"
  docker-compose down
  pre_install_docker_compose
  config_docker
  echo "Bắt đầu chạy dịch vụ DOKCER"
  docker-compose up -d
}

restart_xrayr() {
  cd ${cur_dir}
  docker-compose down
  docker-compose up -d
  echo "Khởi động lại thành công!"
}
delete_xrayr() {
  cd ${cur_dir}
  docker-compose down
  cd ~
  rm -Rf ${cur_dir}
  echo "đã xóa thành công!"
}
# Install xrayr
Install_xrayr() {
  pre_install_docker_compose
  config_docker
  install_docker
}

# Initialization step
clear
while true; do
  echo "-----XrayR Aiko-----"
  echo "Địa chỉ dự án và tài liệu trợ giúp:  https://github.com/AikoCute/XrayR"
  echo "AikoCute Hột Me"
  echo "Vui lòng nhập một số để Thực Hiện Câu Lệnh:"
  for ((i = 1; i <= ${#operation[@]}; i++)); do
    hint="${operation[$i - 1]}"
    echo -e "${green}${i}${plain}) ${hint}"
  done
  read -p "Vui lòng chọn một số và nhấn Enter (Enter theo mặc định ${operation[0]}):" selected
  [ -z "${selected}" ] && selected="1"
  case "${selected}" in
  1 | 2 | 3 | 4 | 5 | 6 | 7)
    echo
    echo "Bắt Đầu : ${operation[${selected} - 1]}"
    echo
    ${operation[${selected} - 1]}_xrayr
    break
    ;;
  *)
    echo -e "[${red}Error${plain}] Vui lòng nhập số chính xác [1-6]"
    ;;
  esac
done
