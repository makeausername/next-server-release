#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

version="v1.0.0"

# 检查是否以 root 用户运行
[[ $EUID -ne 0 ]] && echo -e "${red}错误: ${plain} 必须使用 root 用户运行此脚本！\n" && exit 1

# 检查操作系统
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$ID
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

# 检查 CPU 架构
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    CPU_ARCH="amd64"
    if grep -q 'avx2' /proc/cpuinfo; then
        CPU_ARCH="amd64v3"
    fi
else
    echo -e "${red}不支持的 CPU 架构：${ARCH}，仅支持 amd64 或 amd64v3！${plain}\n" && exit 1
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [默认$2]: " temp
        temp=${temp:-$2}
    else
        read -p "$1 [y/n]: " temp
    fi
    [[ $temp == [Yy] ]] && return 0 || return 1
}

confirm_restart() {
    confirm "是否重启 next-server" "y"
    [[ $? == 0 ]] && restart || show_menu
}

before_show_menu() {
    echo && echo -n -e "${yellow}按回车返回主菜单: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/makeausername/next-server-release/main/install.sh)
    [[ $? == 0 ]] && ( [[ $# == 0 ]] && start || start 0 )
}

update() {
    [[ $# == 0 ]] && { echo && echo -n -e "输入指定版本(默认最新版): " && read version; } || version=$2
    bash <(curl -Ls https://raw.githubusercontent.com/makeausername/next-server-release/main/install.sh) $version
    if [[ $? == 0 ]]; then
        echo -e "${green}更新完成，已自动重启 next-server，请使用 next-server log 查看运行日志${plain}"
        exit
    fi
    [[ $# == 0 ]] && before_show_menu
}

config() {
    echo "next-server 在修改配置后会自动尝试重启"
    vi /etc/next-server/config.yml
    sleep 2
    check_status
    case $? in
        0) echo -e "next-server 状态: ${green}已运行${plain}" ;;
        1)
            echo -e "检测到您未启动 next-server 或自动重启失败，是否查看日志？[Y/n]" && echo
            read -e -p "(默认: y):" yn
            yn=${yn:-y}
            [[ $yn == [Yy] ]] && show_log
            ;;
        2) echo -e "next-server 状态: ${red}未安装${plain}" ;;
    esac
}

uninstall() {
    confirm "确定要卸载 next-server 吗?" "n"
    [[ $? != 0 ]] && { [[ $# == 0 ]] && show_menu; return 0; }
    systemctl stop next-server
    systemctl disable next-server
    rm -f /etc/systemd/system/next-server.service
    systemctl daemon-reload
    systemctl reset-failed
    rm -rf /etc/next-server/
    rm -rf /usr/local/next-server/
    echo ""
    echo -e "卸载成功，如需删除此脚本，运行 ${green}rm /usr/bin/next-server -f${plain}"
    echo ""
    [[ $# == 0 ]] && before_show_menu
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}next-server 已运行，无需再次启动。如需重启请选择重启${plain}"
    else
        systemctl start next-server
        sleep 2
        check_status
        [[ $? == 0 ]] && echo -e "${green}next-server 启动成功，请使用 next-server log 查看运行日志${plain}" || echo -e "${red}next-server 可能启动失败，请稍后查看日志${plain}"
    fi
    [[ $# == 0 ]] && before_show_menu
}

stop() {
    systemctl stop next-server
    sleep 2
    check_status
    [[ $? == 1 ]] && echo -e "${green}next-server 停止成功${plain}" || echo -e "${red}next-server 停止失败，请稍后查看日志${plain}"
    [[ $# == 0 ]] && before_show_menu
}

restart() {
    systemctl restart next-server
    sleep 2
    check_status
    [[ $? == 0 ]] && echo -e "${green}next-server 重启成功，请使用 next-server log 查看运行日志${plain}" || echo -e "${red}next-server 可能启动失败，请稍后查看日志${plain}"
    [[ $# == 0 ]] && before_show_menu
}

status() {
    systemctl status next-server --no-pager -l
    [[ $# == 0 ]] && before_show_menu
}

enable() {
    systemctl enable next-server
    [[ $? == 0 ]] && echo -e "${green}next-server 设置开机自启成功${plain}" || echo -e "${red}next-server 设置开机自启失败${plain}"
    [[ $# == 0 ]] && before_show_menu
}

disable() {
    systemctl disable next-server
    [[ $? == 0 ]] && echo -e "${green}next-server 取消开机自启成功${plain}" || echo -e "${red}next-server 取消开机自启失败${plain}"
    [[ $# == 0 ]] && before_show_menu
}

show_log() {
    journalctl -u next-server.service -e --no-pager -f
    [[ $# == 0 ]] && before_show_menu
}

install_bbr() {
    bash <(curl -L -s https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh)
}

update_shell() {
    wget -O /usr/bin/next-server -N --no-check-certificate https://raw.githubusercontent.com/makeausername/next-server-release/main/next-server.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}下载脚本失败，请检查网络连接${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/next-server
        echo -e "${green}升级脚本成功，请重新运行脚本${plain}" && exit 0
    fi
}

# 检查服务状态：0-运行，1-未运行，2-未安装
check_status() {
    [[ ! -f /etc/systemd/system/next-server.service ]] && return 2
    temp=$(systemctl status next-server | grep Active | awk '{print $3}' | tr -d '()')
    [[ "$temp" == "running" ]] && return 0 || return 1
}

check_enabled() {
    temp=$(systemctl is-enabled next-server)
    [[ "$temp" == "enabled" ]] && return 0 || return 1
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red}next-server 已安装，请不要重复安装${plain}"
        [[ $# == 0 ]] && before_show_menu
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red}请先安装 next-server${plain}"
        [[ $# == 0 ]] && before_show_menu
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
        0) echo -e "next-server 状态: ${green}已运行${plain}"; show_enable_status ;;
        1) echo -e "next-server 状态: ${yellow}未运行${plain}"; show_enable_status ;;
        2) echo -e "next-server 状态: ${red}未安装${plain}" ;;
    esac
}

show_enable_status() {
    check_enabled
    [[ $? == 0 ]] && echo -e "是否开机自启: ${green}是${plain}" || echo -e "是否开机自启: ${red}否${plain}"
}

show_next_server_version() {
    echo -n "next-server 版本："
    /usr/local/next-server/next-server version
    echo ""
    [[ $# == 0 ]] && before_show_menu
}

show_usage() {
    echo "next-server 管理脚本使用方法: "
    echo "------------------------------------------"
    echo "next-server              - 显示管理菜单 (功能更多)"
    echo "next-server start        - 启动 next-server"
    echo "next-server stop         - 停止 next-server"
    echo "next-server restart      - 重启 next-server"
    echo "next-server status       - 查看 next-server 状态"
    echo "next-server enable       - 设置 next-server 开机自启"
    echo "next-server disable      - 取消 next-server 开机自启"
    echo "next-server log          - 查看 next-server 日志"
    echo "next-server update       - 更新 next-server"
    echo "next-server update x.x.x - 更新 next-server 指定版本"
    echo "next-server install      - 安装 next-server"
    echo "next-server uninstall    - 卸载 next-server"
    echo "next-server version      - 查看 next-server 版本"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}next-server 后端管理脚本${plain}
--- https://github.com/makeausername/NeXT-Server ---
  ${green}0.${plain} 修改配置
——————————————
  ${green}1.${plain} 安装 next-server
  ${green}2.${plain} 更新 next-server
  ${green}3.${plain} 卸载 next-server
——————————————
  ${green}4.${plain} 启动 next-server
  ${green}5.${plain} 停止 next-server
  ${green}6.${plain} 重启 next-server
  ${green}7.${plain} 查看 next-server 状态
  ${green}8.${plain} 查看 next-server 日志
——————————————
  ${green}9.${plain} 设置 next-server 开机自启
 ${green}10.${plain} 取消 next-server 开机自启
——————————————
 ${green}11.${plain} 一键安装 BBR (最新内核)
 ${green}12.${plain} 查看 next-server 版本
 ${green}13.${plain} 升级维护脚本
 "
    show_status
    echo && read -p "请输入选择 [0-13]: " num

    case "${num}" in
        0) config ;;
        1) check_uninstall && install ;;
        2) check_install && update ;;
        3) check_install && uninstall ;;
        4) check_install && start ;;
        5) check_install && stop ;;
        6) check_install && restart ;;
        7) check_install && status ;;
        8) check_install && show_log ;;
        9) check_install && enable ;;
        10) check_install && disable ;;
        11) install_bbr ;;
        12) check_install && show_next_server_version ;;
        13) update_shell ;;
        *) echo -e "${red}请输入正确的数字 [0-13]${plain}" ;;
    esac
}

if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0 ;;
        "stop") check_install 0 && stop 0 ;;
        "restart") check_install 0 && restart 0 ;;
        "status") check_install 0 && status 0 ;;
        "enable") check_install 0 && enable 0 ;;
        "disable") check_install 0 && disable 0 ;;
        "log") check_install 0 && show_log 0 ;;
        "update") check_install 0 && update 0 $2 ;;
        "config") config $* ;;
        "install") check_uninstall 0 && install 0 ;;
        "uninstall") check_install 0 && uninstall 0 ;;
        "version") check_install 0 && show_next_server_version 0 ;;
        "update_shell") update_shell ;;
        *) show_usage ;;
    esac
else
    show_menu
fi
