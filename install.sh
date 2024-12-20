#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# Check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# Check OS and architecture
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    os=$ID
else
    echo -e "${red}无法检测操作系统，请联系脚本作者！${plain}\n" && exit 1
fi

arch=$(uname -m)
if [[ $arch == "x86_64" ]]; then
    arch="amd64"
elif [[ $arch == "amd64v3" ]]; then
    arch="amd64v3"
else
    echo -e "${red}仅支持 amd64 或 amd64v3 架构！${plain}\n" && exit 1
fi

echo "操作系统: $os"
echo "架构: $arch"

install_base() {
    if [[ $os == "centos" ]]; then
        yum install epel-release -y
        yum install wget curl unzip tar crontabs socat -y
    else
        apt update -y
        apt install wget curl unzip tar cron socat -y
    fi
}

install_bbr() {
    echo -e "${green}开始安装BBR加速...${plain}"
    if [[ $os == "centos" ]]; then
        yum install -y kernel-ml kernel-ml-devel
        grub2-set-default 0
        echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
        sysctl -p
    else
        apt install -y linux-image-$(uname -r) linux-headers-$(uname -r)
        echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
        sysctl -p
    fi
    echo -e "${green}BBR加速安装完成，请重启系统使其生效！${plain}"
}

install_next_server() {
    if [[ -e /usr/local/next-server/ ]]; then
        rm /usr/local/next-server/ -rf
    fi

    mkdir /usr/local/next-server/ -p
    cd /usr/local/next-server/

    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/makeausername/NeXT-Server/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}检测 NeXT-Server 版本失败，可能是超出 Github API 限制，请稍后再试，或手动指定版本安装${plain}"
            exit 1
        fi
        echo -e "检测到 NeXT-Server 最新版本：${last_version}，开始安装"
        wget -q -N --no-check-certificate -O /usr/local/next-server/next-server-linux.zip https://github.com/makeausername/NeXT-Server/releases/download/${last_version}/next-server-linux-${arch}.zip
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 NeXT-Server 失败，请确保你的服务器能够下载 Github 的文件${plain}"
            exit 1
        fi
    else
        if [[ $1 == v* ]]; then
            last_version=$1
        else
            last_version="v"$1
        fi
        url="https://github.com/makeausername/NeXT-Server/releases/download/${last_version}/next-server-linux-${arch}.zip"
        echo -e "开始安装 NeXT-Server ${last_version}"
        wget -q -N --no-check-certificate -O /usr/local/next-server/next-server-linux.zip ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 NeXT-Server ${last_version} 失败，请确保此版本存在${plain}"
            exit 1
        fi
    fi

    unzip next-server-linux.zip
    rm next-server-linux.zip -f
    chmod +x next-server

    # Install service and scripts
    wget -q -N --no-check-certificate -O /etc/systemd/system/next-server.service https://github.com/makeausername/next-server-release/raw/main/next-server.service
    wget -q -N --no-check-certificate -O /usr/bin/next-server https://github.com/makeausername/next-server-release/raw/main/next-server.sh
    chmod +x /usr/bin/next-server

    systemctl daemon-reload
    systemctl enable next-server
    systemctl start next-server

    echo -e "${green}NeXT-Server ${last_version}${plain} 安装完成，已设置开机自启"
    cd $cur_dir
    rm -f install.sh

    echo -e ""
    echo "NeXT-Server 管理脚本使用方法: "
    echo "------------------------------------------"
    echo "next-server             - 显示管理菜单"
    echo "next-server start       - 启动 NeXT-Server"
    echo "next-server stop        - 停止 NeXT-Server"
    echo "next-server restart     - 重启 NeXT-Server"
    echo "next-server status      - 查看 NeXT-Server 状态"
    echo "next-server enable      - 设置 NeXT-Server 开机自启"
    echo "next-server disable     - 取消 NeXT-Server 开机自启"
    echo "next-server log         - 查看 NeXT-Server 日志"
    echo "next-server update      - 更新 NeXT-Server"
    echo "next-server update x.x.x - 更新 NeXT-Server 指定版本"
    echo "next-server uninstall   - 卸载 NeXT-Server"
    echo "------------------------------------------"
}

echo -e "${green}开始安装${plain}"
install_base
install_bbr
install_next_server $1
