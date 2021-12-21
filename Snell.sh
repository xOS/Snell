#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#	System Required: CentOS/Debian/Ubuntu
#	Description: Snell 管理脚本
#	Version: 1.0.10
#	Author: 佩佩
#	WebSite: https://nan.ge
#=================================================

sh_ver="1.0.10"
filepath=$(cd "$(dirname "$0")"; pwd)
file_1=$(echo -e "${filepath}"|awk -F "$0" '{print $1}')
FOLDER="/etc/snell/"
FILE="/usr/local/bin/snell-server"
CONF="/etc/snell/config.conf"
Now_ver_File="/etc/snell/ver.txt"

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m" && Yellow_font_prefix="\033[0;33m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Yellow_font_prefix}[注意]${Font_color_suffix}"

check_root(){
	[[ $EUID != 0 ]] && echo -e "${Error} 当前非ROOT账号(或没有ROOT权限)，无法继续操作，请更换ROOT账号或使用 ${Green_background_prefix}sudo su${Font_color_suffix} 命令获取临时ROOT权限（执行后可能会提示输入当前账号的密码）。" && exit 1
}
#检查系统
check_sys(){
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
}

Installation_dependency(){
	if [[ ${release} == "centos" ]]; then
		yum update && yum install gzip wget curl unzip -y
	else
		apt-get update && apt-get install gzip wget curl unzip -y
	fi
	\cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
}

#检查系统内核版本
sysArch() {
    uname=$(uname -m)
    if [[ "$uname" == "i686" ]] || [[ "$uname" == "i386" ]]; then
        arch="i386"
    elif [[ "$uname" == *"armv7"* ]] || [[ "$uname" == "armv6l" ]]; then
        arch="armv7l"
    elif [[ "$uname" == *"armv8"* ]] || [[ "$uname" == "aarch64" ]]; then
        arch="aarch64"
    else
        arch="amd64"
    fi    
}

check_installed_status(){
	[[ ! -e ${FILE} ]] && echo -e "${Error} Snell 没有安装，请检查 !" && exit 1
}

check_pid(){
	PID=$(ps -ef| grep "snell-server "|awk '{print $2}')
}
check_new_ver(){
	new_ver=$(wget -qO- https://api.github.com/repos/surge-networks/snell/releases| grep "tag_name"| head -n 1| awk -F ":" '{print $2}'| sed 's/\"//g;s/,//g;s/ //g')
	new_beta=$(wget -qO- https://api.github.com/repos/surge-networks/snell/releases| grep "tag_name"| head -n 1| awk -F ":" '{print $2}'| sed 's/\"//g;s/,//g;s/ //g;s/b[0-9]//g')
	[[ -z ${new_ver} ]] && echo -e "${Error} Snell 最新版本获取失败！" && exit 1
	echo -e "${Info} 检测到 Snell 最新版本为 [ ${new_ver} ]"
}

check_ver_comparison(){
	now_ver=$(cat ${Now_ver_File})
	if [[ "${now_ver}" != "${new_ver}" ]]; then
		echo -e "${Info} 发现 Snell 已有新版本 [ ${new_ver} ]，旧版本 [ ${now_ver} ]"
		read -e -p "是否更新 ? [Y/n] :" yn
		[[ -z "${yn}" ]] && yn="y"
		if [[ $yn == [Yy] ]]; then
			check_pid
			[[ ! -z $PID ]] && kill -9 ${PID}
			\cp "${CONF}" "/tmp/config.conf"
			rm -rf ${FILE}
			Download
			mv "/tmp/config.conf" "${CONF}"
			Start
		fi
	else
		echo -e "${Info} 当前 Snell 已是最新版本 [ ${new_ver} ]" && exit 1
	fi
}
Download(){
	if [[ ! -e "${FOLDER}" ]]; then
		mkdir "${FOLDER}"
	else
		[[ -e "${FILE}" ]] && rm -rf "${FILE}"
	fi
	echo -e "${Info} 默认开始下载稳定版 Snell ……"
	wget --no-check-certificate -N "https://github.com/surge-networks/snell/releases/download/${new_ver}/snell-server-${new_ver}-linux-${arch}.zip"
	[[ ! -e "snell-server-${new_ver}-linux-${arch}.zip" ]] && echo -e "${Error} Snell 稳定版下载失败！准备请求测试版 Snell ……" && rm -rf "snell-server-${new_ver}-linux-${arch}.zip"
    	if [[ ! -e "snell-server-${new_ver}-linux-${arch}.zip" ]];then
		echo -e "${Info} 发现测试版 Snell ！开始下载测试版 Snell ……"
		wget --no-check-certificate -N "https://github.com/surge-networks/snell/releases/download/${new_ver}/snell-server-v${new_beta}-linux-${arch}.zip"
        unzip -o "snell-server-v${new_beta}-linux-${arch}.zip"
        [[ ! -e "snell-server" ]] && echo -e "${Error} Snell 压缩包解压失败 !" && rm -rf "snell-server-v${new_beta}-linux-${arch}.zip"
	    rm -rf "snell-server-v${new_beta}-linux-${arch}.zip"
	    chmod +x snell-server
	    mv snell-server "${FILE}"
	    echo "v${new_beta}" > ${Now_ver_File}
		if [[ ! -e "snell-server-v${new_beta}-linux-${arch}.zip" ]];then
		echo -e "${Info} 发现预览版 Snell ！开始下载预览版 Snell ……"
		wget --no-check-certificate -N "https://github.com/surge-networks/snell/releases/download/${new_ver}/snell-server-${new_beta}-linux-${arch}.zip"
        unzip -o "snell-server-${new_beta}-linux-${arch}.zip"
        [[ ! -e "snell-server" ]] && echo -e "${Error} Snell 压缩包解压失败 !" && rm -rf "snell-server-${new_beta}-linux-${arch}.zip"
	    rm -rf "snell-server-${new_beta}-linux-${arch}.zip"
	    chmod +x snell-server
	    mv snell-server "${FILE}"
	    echo "${new_ver}" > ${Now_ver_File}
		fi
	else
	unzip -o "snell-server-${new_ver}-linux-${arch}.zip"
	[[ ! -e "snell-server" ]] && echo -e "${Error} Snell 压缩包解压失败 !" && rm -rf "snell-server-${new_ver}-linux-${arch}.zip" && exit 1
	rm -rf "snell-server-${new_ver}-linux-${arch}.zip"
	chmod +x snell-server
	mv snell-server "${FILE}"
	echo "${new_ver}" > ${Now_ver_File}
    echo -e "${Info} Snell 主程序下载安装完毕！"
	fi
}
Service(){
	echo '
[Unit]
Description= Snell Service
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service
[Service]
LimitNOFILE=32767 
Type=simple
User=root
Restart=on-failure
RestartSec=5s
DynamicUser=true
ExecStart=/usr/local/bin/snell-server -c /etc/snell/config.conf
[Install]
WantedBy=multi-user.target' > /etc/systemd/system/snell-server.service
systemctl enable --now snell-server
	echo -e "${Info} Snell 服务配置完成 !"
}

Write_config(){
	cat > ${CONF}<<-EOF
[snell-server]
listen = ::0:${port}
ipv6 = ${ipv6}
psk = ${psk}
obfs = tls
obfs-host = ${host}
tfo = ${tfo}
version = 3
EOF
}
Read_config(){
	[[ ! -e ${CONF} ]] && echo -e "${Error} Snell 配置文件不存在 !" && exit 1
	ipv6=$(cat ${CONF}|grep 'ipv6 = '|awk -F 'ipv6 = ' '{print $NF}')
	port=$(cat ${CONF}|grep ':'|awk -F ':' '{print $NF}')
	psk=$(cat ${CONF}|grep 'psk = '|awk -F 'psk = ' '{print $NF}')
	host=$(cat ${CONF}|grep 'obfs-host = '|awk -F 'obfs-host = ' '{print $NF}')
	tfo=$(cat ${CONF}|grep 'tfo = '|awk -F 'tfo = ' '{print $NF}')
}
Set_port(){
	while true
		do
		echo -e "${Tip} 本步骤不涉及系统防火墙端口操作，请手动放行相应端口！"
		echo -e "请输入 Snell 端口 [1-65535]"
		read -e -p "(默认: 2345):" port
		[[ -z "${port}" ]] && port="2345"
		echo $((${port}+0)) &>/dev/null
		if [[ $? -eq 0 ]]; then
			if [[ ${port} -ge 1 ]] && [[ ${port} -le 65535 ]]; then
				echo && echo "=============================="
				echo -e "端口 : ${Red_background_prefix} ${port} ${Font_color_suffix}"
				echo "==============================" && echo
				break
			else
				echo "输入错误, 请输入正确的端口。"
			fi
		else
			echo "输入错误, 请输入正确的端口。"
		fi
		done
}

Set_ipv6(){
	echo -e "是否开启 IPv6 ？
==================================
${Green_font_prefix} 1.${Font_color_suffix} 开启  ${Green_font_prefix} 2.${Font_color_suffix} 关闭
=================================="
	read -e -p "(默认：1.开启)：" ipv6
	[[ -z "${ipv6}" ]] && ipv6="1"
	if [[ ${ipv6} == "1" ]]; then
		ipv6=true
	else
		ipv6=false
	fi
	echo && echo "=================================="
	echo -e "IPv6 开启状态：${Red_background_prefix} ${ipv6} ${Font_color_suffix}"
	echo "==================================" && echo
}

Set_psk(){
	echo "请输入 Snell 密钥 [0-9][a-z][A-Z]"
	read -e -p "(默认: 随机生成):" psk
	[[ -z "${psk}" ]] && psk=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
	echo && echo "=============================="
	echo -e "密钥 : ${Red_background_prefix} ${psk} ${Font_color_suffix}"
	echo "==============================" && echo
}

Set_host(){
	echo "请输入 Snell 域名 "
	read -e -p "(默认: bing.com):" host
	[[ -z "${host}" ]] && host=bing.com
	echo && echo "=============================="
	echo -e "	域名 : ${Red_background_prefix} ${host} ${Font_color_suffix}"
	echo "==============================" && echo
}

Set_tfo(){
	echo -e "是否开启 TCP Fast Open ？
==================================
${Green_font_prefix} 1.${Font_color_suffix} 开启  ${Green_font_prefix} 2.${Font_color_suffix} 关闭
=================================="
	read -e -p "(默认：1.开启)：" tfo
	[[ -z "${tfo}" ]] && tfo="1"
	if [[ ${tfo} == "1" ]]; then
		tfo=true
	else
		tfo=false
	fi
	echo && echo "=================================="
	echo -e "TCP Fast Open 开启状态：${Red_background_prefix} ${tfo} ${Font_color_suffix}"
	echo "==================================" && echo
}

Set(){
	check_installed_status
	echo && echo -e "你要做什么？
==============================
 ${Green_font_prefix}1.${Font_color_suffix}  修改 端口
 ${Green_font_prefix}2.${Font_color_suffix}  修改 密钥
 ${Green_font_prefix}3.${Font_color_suffix}  修改 域名
 ${Green_font_prefix}4.${Font_color_suffix}  开关 IPv6
 ${Green_font_prefix}5.${Font_color_suffix}  开关 TFO
==============================
 ${Green_font_prefix}6.${Font_color_suffix}  修改 全部配置" && echo
	read -e -p "(默认: 取消):" modify
	[[ -z "${modify}" ]] && echo "已取消..." && exit 1
	if [[ "${modify}" == "1" ]]; then
		Read_config
		Set_port
		Set_psk=${psk}
		Set_host=${host}
		Set_ipv6=${ipv6}
		Set_tfo=${tfo}
		Write_config
		Restart
	elif [[ "${modify}" == "2" ]]; then
		Read_config
		Set_psk
		Set_port=${port}
		Set_host=${host}
		Set_ipv6=${ipv6}
		Set_tfo=${tfo}
		Write_config
		Restart
	elif [[ "${modify}" == "3" ]]; then
		Read_config
		Set_host
		Set_port=${port}
		psk=${psk}
		Set_ipv6=${ipv6}
		Set_tfo=${tfo}
		Write_config
		Restart
	elif [[ "${modify}" == "4" ]]; then
		Read_config
		Set_host=${host}
		Set_port=${port}
		psk=${psk}
		Set_ipv6
		Set_tfo=${tfo}
		Write_config
		Restart
	elif [[ "${modify}" == "5" ]]; then
		Read_config
		Set_host=${host}
		Set_port=${port}
		psk=${psk}
		Set_ipv6=${ipv6}
		Set_tfo
		Write_config
		Restart
	elif [[ "${modify}" == "6" ]]; then
		Read_config
		Set_port
		Set_psk
		Set_host
		Set_ipv6
		Set_tfo
		Write_config
		Restart
	else
		echo -e "${Error} 请输入正确的数字(1-6)" && exit 1
	fi
    sleep 3s
    start_menu
}
Install(){
	check_root
	[[ -e ${FILE} ]] && echo -e "${Error} 检测到 Snell 已安装 !" && exit 1
	echo -e "${Info} 开始设置 配置..."
	Set_port
	Set_psk
	Set_host
	Set_ipv6
	Set_tfo
	echo -e "${Info} 开始安装/配置 依赖..."
	Installation_dependency
	echo -e "${Info} 开始下载/安装..."
	check_new_ver
	Download
	echo -e "${Info} 开始安装 服务脚本..."
	Service
	echo -e "${Info} 开始写入 配置文件..."
	Write_config
	echo -e "${Info} 所有步骤 安装完毕，开始启动..."
	Start
    sleep 3s
    start_menu
}
Start(){
	check_installed_status
	check_pid
	[[ ! -z ${PID} ]] && echo -e "${Info} Snell 已在运行 !" && exit 1
	systemctl start snell-server
	check_pid
	[[ ! -z ${PID} ]] && echo -e "${Info} Snell 启动成功 !"
    sleep 3s
    start_menu
}
Stop(){
	check_installed_status
	check_pid
	[[ -z ${PID} ]] && echo -e "${Error} Snell 没有运行，请检查 !" && exit 1
	systemctl stop snell-server
	echo -e "${Info} Snell 停止成功 !"
    sleep 3s
    start_menu
}
Restart(){
	check_installed_status
	check_pid
	[[ ! -z ${PID} ]] && systemctl stop snell-server
	systemctl restart snell-server
	check_pid
	[[ ! -z ${PID} ]]
	echo -e "${Info} Snell 重启完毕!"
	sleep 3s
	View
    start_menu
}
Update(){
	check_installed_status
	check_new_ver
	check_ver_comparison
	echo -e "${Info} Snell 更新完毕 !"
    sleep 3s
    start_menu
}
Uninstall(){
	check_installed_status
	echo "确定要卸载 Snell ? (y/N)"
	echo
	read -e -p "(默认: n):" unyn
	[[ -z ${unyn} ]] && unyn="n"
	if [[ ${unyn} == [Yy] ]]; then
		check_pid
		[[ ! -z $PID ]] && kill -9 ${PID}
        systemctl disable snell-server
		rm -rf "${FILE}"
		echo && echo "Snell 卸载完成 !" && echo
	else
		echo && echo "卸载已取消..." && echo
	fi
    sleep 3s
    start_menu
}
getipv4(){
	ipv4=$(wget -qO- -4 -t1 -T2 ipinfo.io/ip)
	if [[ -z "${ipv4}" ]]; then
		ipv4=$(wget -qO- -4 -t1 -T2 api.ip.sb/ip)
		if [[ -z "${ipv4}" ]]; then
			ipv4=$(wget -qO- -4 -t1 -T2 members.3322.org/dyndns/getip)
			if [[ -z "${ipv4}" ]]; then
				ipv4="IPv4_Error"
			fi
		fi
	fi
}
getipv6(){
	ip6=$(wget -qO- -6 -t1 -T2 ifconfig.co)
	if [[ -z "${ip6}" ]]; then
		ip6="IPv6_Error"
	fi
}

View(){
	check_installed_status
	Read_config
	getipv4
	getipv6
	clear && echo
	echo -e "Snell 配置信息："
	echo -e "—————————————————————————"
	[[ "${ipv4}" != "IPv4_Error" ]] && echo -e " 地址\t: ${Green_font_prefix}${ipv4}${Font_color_suffix}"
	[[ "${ip6}" != "IPv6_Error" ]] && echo -e " 地址\t: ${Green_font_prefix}${ip6}${Font_color_suffix}"
	echo -e " 端口\t: ${Green_font_prefix}${port}${Font_color_suffix}"
	echo -e " 密钥\t: ${Green_font_prefix}${psk}${Font_color_suffix}"
	echo -e " 域名\t: ${Green_font_prefix}${host}${Font_color_suffix}"
	echo -e " IPv6\t: ${Green_font_prefix}${ipv6}${Font_color_suffix}"
	echo -e " TFO\t: ${Green_font_prefix}${tfo}${Font_color_suffix}"
	echo -e "—————————————————————————"
	echo
	before_start_menu
}

Status(){
	echo -e "${Info} 获取 Snell-Server 活动日志 ……"
	echo -e "${Tip} 返回主菜单请按 q ！"
	systemctl status snell-server
	start_menu
}

Update_Shell(){
	echo -e "当前版本为 [ ${sh_ver} ]，开始检测最新版本..."
	sh_new_ver=$(wget --no-check-certificate -qO- "https://raw.githubusercontent.com/xOS/Snell/master/Snell.sh"|grep 'sh_ver="'|awk -F "=" '{print $NF}'|sed 's/\"//g'|head -1)
	[[ -z ${sh_new_ver} ]] && echo -e "${Error} 检测最新版本失败 !" && start_menu
	if [[ ${sh_new_ver} != ${sh_ver} ]]; then
		echo -e "发现新版本[ ${sh_new_ver} ]，是否更新？[Y/n]"
		read -p "(默认: y):" yn
		[[ -z "${yn}" ]] && yn="y"
		if [[ ${yn} == [Yy] ]]; then
			wget -O Snell.sh --no-check-certificate https://raw.githubusercontent.com/xOS/Snell/master/Snell.sh && chmod +x Snell.sh
			echo -e "脚本已更新为最新版本[ ${sh_new_ver} ] !"
			echo -e "3s后执行新脚本"
            sleep 3s
            bash Snell.sh
		else
			echo && echo "	已取消..." && echo
            sleep 3s
            start_menu
		fi
	else
		echo -e "当前已是最新版本[ ${sh_new_ver} ] !"
		sleep 3s
        start_menu
	fi
	sleep 3s
    	bash Snell.sh
}
before_start_menu() {
    echo && echo -n -e "${yellow}* 按回车返回主菜单 *${plain}" && read temp
    start_menu
}
exit_menu() {
    exit 1
}
start_menu(){
clear
check_root
check_sys
sysArch
action=$1
	echo && echo -e "  
==============================
Snell-Server 管理脚本 ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix}
==============================
 ${Green_font_prefix} 0.${Font_color_suffix} 升级脚本
——————————————————————————————
 ${Green_font_prefix} 1.${Font_color_suffix} 安装 Snell-Server
 ${Green_font_prefix} 2.${Font_color_suffix} 更新 Snell-Server
 ${Green_font_prefix} 3.${Font_color_suffix} 卸载 Snell-Server
——————————————————————————————
 ${Green_font_prefix} 4.${Font_color_suffix} 启动 Snell-Server
 ${Green_font_prefix} 5.${Font_color_suffix} 停止 Snell-Server
 ${Green_font_prefix} 6.${Font_color_suffix} 重启 Snell-Server
——————————————————————————————
 ${Green_font_prefix} 7.${Font_color_suffix} 设置 配置信息
 ${Green_font_prefix} 8.${Font_color_suffix} 查看 配置信息
 ${Green_font_prefix} 9.${Font_color_suffix} 查看 运行状态
——————————————————————————————
 ${Green_font_prefix} 10.${Font_color_suffix} 退出脚本
==============================" && echo
	if [[ -e ${FILE} ]]; then
		check_pid
		if [[ ! -z "${PID}" ]]; then
			echo -e " 当前状态: ${Green_font_prefix}已安装${Font_color_suffix} 并 ${Green_font_prefix}已启动${Font_color_suffix}"
		else
			echo -e " 当前状态: ${Green_font_prefix}已安装${Font_color_suffix} 但 ${Red_font_prefix}未启动${Font_color_suffix}"
		fi
	else
		echo -e " 当前状态: ${Red_font_prefix}未安装${Font_color_suffix}"
	fi
	echo
	read -e -p " 请输入数字 [0-10]:" num
	case "$num" in
		0)
		Update_Shell
		;;
		1)
		Install
		;;
		2)
		Update
		;;
		3)
		Uninstall
		;;
		4)
		Start
		;;
		5)
		Stop
		;;
		6)
		Restart
		;;
		7)
		Set
		;;
		8)
		View
		;;
		9)
		Status
		;;
		10)
		exit_menu
		;;
		*)
		echo "请输入正确数字 [0-10]"
		;;
	esac
}
start_menu
