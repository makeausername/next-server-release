#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

version="v1.0.0"

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误: ${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
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
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
    fi
fi

# check architecture
arch=$(uname -m)
if [[ "$arch" == "x86_64" ]]; then
    cpu_arch="amd64"
elif [[ "$arch" == "x86_64-v3" ]]; then
    cpu_arch="amd64v3"
else
    echo -e "${red}未检测到支持的架构，仅支持 amd64 和 amd64v3！${plain}\n" && exit 1
fi

echo -e "${green}检测到的系统版本: ${release} ${os_version}, 架构: ${cpu_arch}${plain}\n"

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/makeausername/next-server-release/main/install.sh) $cpu_arch
    if [[ $? == 0 ]]; then
        echo -e "${green}next-server 安装成功！${plain}"
    else
        echo -e "${red}next-server 安装失败！${plain}" && exit 1
    fi
}

update() {
    echo && echo -n -e "输入指定版本(默认最新版): " && read version
    bash <(curl -Ls https://raw.githubusercontent.com/makeausername/next-server-release/main/install.sh) $cpu_arch $version
    if [[ $? == 0 ]]; then
        echo -e "${green}next-server 更新成功！${plain}"
    else
        echo -e "${red}next-server 更新失败！${plain}" && exit 1
    fi
}

config() {
    echo "next-server 在修改配置后会自动尝试重启"
    vi /etc/next-server/config.yml
    restart
}

uninstall() {
    echo -e "${yellow}确定要卸载 next-server 吗？[y/n]${plain}" && read yn
    if [[ "$yn" != "y" && "$yn" != "Y" ]]; then
        echo -e "${green}取消卸载。${plain}" && return
    fi
    systemctl stop next-server
    systemctl disable next-server
    rm /etc/systemd/system/next-server.service -f
    systemctl daemon-reload
    rm /etc/next-server/ -rf
    rm /usr/local/bin/next-server -f
    echo -e "${green}next-server 卸载成功。${plain}"
}

start() {
    systemctl start next-server
    echo -e "${green}next-server 已启动。${plain}"
}

stop() {
    systemctl stop next-server
    echo -e "${green}next-server 已停止。${plain}"
}

restart() {
    systemctl restart next-server
    echo -e "${green}next-server 已重启。${plain}"
}

status() {
    systemctl status next-server --no-pager -l
}

enable() {
    systemctl enable next-server
    echo -e "${green}next-server 已设置为开机自启。${plain}"
}

disable() {
    systemctl disable next-server
    echo -e "${green}next-server 已取消开机自启。${plain}"
}

install_bbr() {
    bash <(curl -L -s https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh)
    if [[ $? == 0 ]]; then
        echo -e "${green}BBR 安装成功，请重启服务器生效。${plain}"
    else
        echo -e "${red}BBR 安装失败，请检查网络连接。${plain}"
    fi
}

update_shell() {
    wget -O /usr/bin/next-server-manager -N --no-check-certificate https://raw.githubusercontent.com/makeausername/next-server-release/main/next-server.sh
    if [[ $? != 0 ]]; then
        echo -e "${red}更新脚本失败，请检查网络连接。${plain}"
    else
        chmod +x /usr/bin/next-server-manager
        echo -e "${green}脚本更新成功，请重新运行脚本。${plain}" && exit 0
    fi
}

show_menu() {
    echo -e "\n  ${green}next-server 管理脚本${plain}"
    echo -e "------------------------------------------"
    echo -e "${green}1.${plain} 安装 next-server"
    echo -e "${green}2.${plain} 更新 next-server"
    echo -e "${green}3.${plain} 卸载 next-server"
    echo -e "${green}4.${plain} 启动 next-server"
    echo -e "${green}5.${plain} 停止 next-server"
    echo -e "${green}6.${plain} 重启 next-server"
    echo -e "${green}7.${plain} 查看 next-server 状态"
    echo -e "${green}8.${plain} 设置 next-server 开机自启"
    echo -e "${green}9.${plain} 取消 next-server 开机自启"
    echo -e "${green}10.${plain} 修改配置"
    echo -e "${green}11.${plain} 安装 BBR"
    echo -e "${green}12.${plain} 更新脚本版本"
    echo -e "------------------------------------------"
    echo && read -p "请输入选择 [1-12]: " num

    case "$num" in
        1) install ;;
        2) update ;;
        3) uninstall ;;
        4) start ;;
        5) stop ;;
        6) restart ;;
        7) status ;;
        8) enable ;;
        9) disable ;;
        10) config ;;
        11) install_bbr ;;
        12) update_shell ;;
        *) echo -e "${red}请输入正确的数字 [1-12]${plain}" ;;
    esac
}

show_menu
