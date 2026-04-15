#!/bin/bash
# Lenyu OpenWrt ROM Update Script (Optimized for luci-app-romupdate)
# 移除了 Passwall 逻辑及手动备份，保留纯净 ROM 升级流程

# --- 环境检测 ---
if [ ! -f "/etc/lenyu_version" ]; then
    echo -e "\n\033[31m 该脚本在非Lenyu固件上运行，为避免不必要的麻烦，准备退出… \033[0m\n"
    exit 0
fi

# --- 准备工作 ---
rm -f /tmp/cloud_ts_version
current_version=$(cat /etc/lenyu_version)

# --- 获取云端版本信息 ---
echo -e "正在检查云端最新版本..."
wget -qO- -t1 -T2 "https://api.github.com/repos/Lenyu2020/Actions-OpenWrt-x86/releases/latest" | \
grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | \
sed 's/\"//g;s/,//g;s/ //g;s/v//g' > /tmp/cloud_ts_version

if [ -s "/tmp/cloud_ts_version" ]; then
    new_version=$(cat /tmp/cloud_ts_version)
    cloud_version=$(echo "$new_version" | cut -d _ -f 1)
    cloud_kernel=$(echo "$new_version" | cut -d _ -f 2)
    
    # 定义下载链接
    BASE_URL="https://github.com/Lenyu2020/Actions-OpenWrt-x86/releases/download/${new_version}"
    # Legacy 下载地址
    DEV_URL="${BASE_URL}/openwrt_x86-64-${new_version}_dev_Lenyu.img.gz"
    MD5_URL="${BASE_URL}/openwrt_dev.md5"
    # UEFI 下载地址
    DEV_UEFI_URL="${BASE_URL}/openwrt_x86-64-${new_version}_uefi-gpt_dev_Lenyu.img.gz"
    MD5_UEFI_URL="${BASE_URL}/openwrt_dev_uefi.md5"
else
    echo -e "\033[31m 网络连接失败，请检查网络或重试！\033[0m"
    exit 1
fi

# --- 内核安全检查 ---
if [[ "$cloud_kernel" =~ "4.19" ]]; then
    echo -e "\n\033[31m 该脚本在Lenyu固件Sta版本上运行，目前只建议在Dev版本上运行，准备退出… \033[0m\n"
    exit 0
fi

# --- 引导模式判定与固件下载 ---
if [ ! -d /sys/firmware/efi ]; then
    # Legacy BIOS 模式逻辑
    if [ "$current_version" != "$cloud_version" ]; then
        echo -e "发现新版本: \033[32m$cloud_version\033[0m，正在准备 Legacy 镜像..."
        wget -P /tmp "$DEV_URL" -O /tmp/openwrt_upgrade.img.gz
        wget -P /tmp "$MD5_URL" -O /tmp/openwrt_upgrade.md5
        cd /tmp && md5sum -c openwrt_upgrade.md5
        if [ $? != 0 ]; then
            echo -e "\033[31m 文件校验失败，请检查网络重试…\033[0m"
            sleep 4 && exit 1
        fi
    else
        echo -e "\n\033[32m 本地已经是最新版本，无需升级！\033[0m\n"
        exit 0
    fi
else
    # UEFI GPT 模式逻辑
    if [ "$current_version" != "$cloud_version" ]; then
        echo -e "发现新版本: \033[32m$cloud_version\033[0m，正在准备 UEFI 镜像..."
        wget -P /tmp "$DEV_UEFI_URL" -O /tmp/openwrt_upgrade.img.gz
        wget -P /tmp "$MD5_UEFI_URL" -O /tmp/openwrt_upgrade.md5
        cd /tmp && md5sum -c openwrt_upgrade.md5
        if [ $? != 0 ]; then
            echo -e "\033[31m 文件校验失败，请检查网络重试…\033[0m"
            sleep 4 && exit 1
        fi
    else
        echo -e "\n\033[32m 本地已经是最新版本，无需升级！\033[0m\n"
        exit 0
    fi
fi

# --- 升级交互函数 (这是 Web 界面弹出 Y/N 交互的关键) ---
open_up()
{
    echo
    clear
    echo -e "\033[33m================================================\033[0m"
    echo -e "\033[32m          Lenyu ROM 在线升级 (luci-app-romupdate) \033[0m"
    echo -e "\033[33m================================================\033[0m"
    echo
    read -n 1 -p " 您是否要保留配置升级？(Y:保留 / N:清空): " num1
    echo
    case $num1 in
        Y|y)
            echo -e "\n\033[32m >>> 正在准备保留配置升级，请稍候，等待系统重启… \033[0m\n"
            sleep 3
            sysupgrade /tmp/openwrt_upgrade.img.gz
            ;;
        N|n)
            echo -e "\n\033[32m >>> 正在准备【不保留】配置升级，即将恢复出厂状态… \033[0m\n"
            sleep 3
            sysupgrade -n /tmp/openwrt_upgrade.img.gz
            ;;
        *)
            echo -e "\033[31m 错误：只能选择Y或N \033[0m"
            open_up
            ;;
    esac
}

# --- 入口确认 ---
open_op()
{
    echo
    read -n 1 -p " 确认要升级到新版本吗？(Y/N): " num2
    echo
    case $num2 in
        Y|y)
            open_up
            ;;
        *)
            echo -e "\n\033[31m >>> 您已选择取消升级，脚本执行结束。 \033[0m\n"
            exit 1
            ;;
    esac
}

open_op
exit 0
