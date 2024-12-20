#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# 检查 root 权限
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用 root 用户运行此脚本！\n" && exit 1

# 检测操作系统
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

# 检测架构
arch=$(uname -m)
if [[ $arch == "x86_64" ]]; then
    if grep -q "v3" /proc/cpuinfo; then
        arch="amd64v3"
    else
        arch="amd64"
    fi
else
    echo -e "${red}当前架构 $arch 不支持，仅支持 amd64 和 amd64v3！${plain}"
    exit 1
fi

echo -e "架构: ${green}${arch}${plain}"

# 安装必要的依赖
install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl unzip tar crontabs socat -y
    else
        apt update -y
        apt install wget curl unzip tar cron socat -y
    fi
}

# 检查服务状态
check_status() {
    if [[ ! -f /etc/systemd/system/next-server.service ]]; then
        return 2
    fi
    temp=$(systemctl status next-server | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

# 下载并安装 next-server
install_next_server() {
    echo -e "${green}开始安装 next-server${plain}"

    # 下载 next-server 文件
    mkdir -p /usr/local/next-server/
    cd /usr/local/next-server/

    last_version=$(curl -Ls "https://api.github.com/repos/makeausername/NeXT-Server/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [[ ! -n "$last_version" ]]; then
        echo -e "${red}检测 next-server 版本失败，请稍后再试！${plain}"
        exit 1
    fi
    echo -e "检测到 next-server 最新版本：${last_version}，开始下载"

    wget -q -N --no-check-certificate -O /usr/local/next-server/next-server https://github.com/makeausername/NeXT-Server/releases/download/${last_version}/next-server-linux-${arch}
    if [[ $? -ne 0 ]]; then
        echo -e "${red}下载 next-server 失败，请检查网络连接或版本是否存在！${plain}"
        exit 1
    fi

    chmod +x /usr/local/next-server/next-server

    # 下载辅助脚本
    wget -q -N --no-check-certificate -O /usr/local/next-server/install.sh https://github.com/makeausername/next-server-release/raw/main/install.sh
    wget -q -N --no-check-certificate -O /usr/local/next-server/next-server.sh https://github.com/makeausername/next-server-release/raw/main/next-server.sh

    # 下载 systemd 文件
    wget -q -N --no-check-certificate -O /etc/systemd/system/next-server.service https://github.com/makeausername/next-server-release/raw/main/next-server.service

    # 设置权限
    chmod +x /usr/local/next-server/install.sh
    chmod +x /usr/local/next-server/next-server.sh

    # 配置服务
    systemctl daemon-reload
    systemctl enable next-server

    echo -e "${green}next-server ${last_version}${plain} 安装完成，已设置开机自启"
    cd $cur_dir
}

# 脚本使用说明
echo_usage() {
    echo "next-server 管理脚本使用方法: "
    echo "------------------------------------------"
    echo "install.sh              - 显示管理菜单 (功能更多)"
    echo "next-server.sh start    - 启动 next-server"
    echo "next-server.sh stop     - 停止 next-server"
    echo "next-server.sh restart  - 重启 next-server"
    echo "next-server.sh status   - 查看 next-server 状态"
    echo "next-server.sh enable   - 设置 next-server 开机自启"
    echo "next-server.sh disable  - 取消 next-server 开机自启"
    echo "------------------------------------------"
}

# 主执行逻辑
echo -e "${green}开始安装${plain}"
install_base
install_next_server
echo_usage
