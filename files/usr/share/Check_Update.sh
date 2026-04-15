#!/bin/bash
# zzXGP ROM Update Script (Custom for ImmortalWrt-XGP-Auto-Build)
# 支持 SHA256 校验与动态文件名匹配

# --- 1. 环境检测 ---
if [ ! -f "/etc/lenyu_version" ]; then
    echo -e "\n\033[31m 错误: 未检测到 zzXGP 固件标识，脚本退出… \033[0m\n"
    exit 0
fi

# --- 2. 预设参数 ---
REPO="qsyjc/immortalwrt-xgp-auto-build"
API_URL="https://api.github.com/repos/$REPO/releases/latest"
DOWNLOAD_DIR="/tmp/upgrade"
mkdir -p $DOWNLOAD_DIR && rm -f $DOWNLOAD_DIR/*

current_version=$(cat /etc/lenyu_version)

# --- 3. 获取云端 Release 信息 ---
echo -e "正在检查 zzXGP 云端更新..."
latest_release_json=$(wget -qO- -t1 -T5 "$API_URL")

if [ -z "$latest_release_json" ]; then
    echo -e "\033[31m 无法获取 GitHub 版本信息，请检查网络！\033[0m"
    exit 1
fi

# 提取 tag 名称作为云端版本号
cloud_version=$(echo "$latest_release_json" | grep '"tag_name":' | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/')

# 匹配包含 'istore-squashfs-sysupgrade.img.gz' 的文件名和下载地址
remote_file_name=$(echo "$latest_release_json" | grep -oE 'immortalWrt-.*istore-squashfs-sysupgrade\.img\.gz' | head -n 1)
remote_file_url=$(echo "$latest_release_json" | grep -oE "https://github.com/[^\"]*$remote_file_name" | head -n 1)

# 获取对应的 SHA256 (假设你的仓库在发布时会包含 sha256 校验文件或直接比对)
# 这里由于 Release 描述中通常有 sha256 文本，我们尝试从 JSON 文本中提取
remote_sha256=$(echo "$latest_release_json" | grep -A 1 "$remote_file_name" | grep "sha256" | sed -E 's/.*sha256:([a-f0-9]{64}).*/\1/')

# --- 4. 版本比对 ---
if [ "$current_version" == "$cloud_version" ]; then
    echo -e "\n\033[32m 本地 zzXGP 已经是最新版本 ($current_version)，无需升级！\033[0m\n"
    exit 0
fi

echo -e "发现新版本: \033[32m$cloud_version\033[0m"
echo -e "固件文件: $remote_file_name"

# --- 5. 下载固件 ---
echo -e "正在下载 zzXGP 固件镜像..."
wget -q --show-progress "$remote_file_url" -O "$DOWNLOAD_DIR/zzXGP_latest.img.gz"

# --- 6. 校验安全 (SHA256) ---
if [ -n "$remote_sha256" ]; then
    echo -e "正在执行 SHA256 安全校验..."
    echo "$remote_sha256  $DOWNLOAD_DIR/zzXGP_latest.img.gz" > "$DOWNLOAD_DIR/check.sha256"
    if ! sha256sum -c "$DOWNLOAD_DIR/check.sha256" >/dev/null 2>&1; then
        echo -e "\033[31m 校验失败！下载的文件可能不完整或已被篡改。\033[0m"
        exit 1
    fi
    echo -e "\033[32m SHA256 校验通过！\033[0m"
fi

# --- 7. Web 交互升级流程 ---
open_up()
{
    echo
    clear
    echo -e "\033[33m================================================\033[0m"
    echo -e "\033[32m           zzXGP 固件在线升级系统               \033[0m"
    echo -e "\033[33m================================================\033[0m"
    echo
    echo -e "  云端版本: $cloud_version"
    echo -e "  当前版本: $current_version"
    echo
    read -n 1 -p " 是否保留配置升级？(Y: 保留 / N: 清空重置): " num1
    echo
    case $num1 in
        Y|y)
            echo -e "\n\033[32m >>> 正在准备【保留配置】升级，系统即将重启… \033[0m\n"
            sleep 2
            sysupgrade "$DOWNLOAD_DIR/zzXGP_latest.img.gz"
            ;;
        N|n)
            echo -e "\n\033[31m >>> 正在准备【不保留配置】升级，系统将清空所有设置… \033[0m\n"
            sleep 2
            sysupgrade -n "$DOWNLOAD_DIR/zzXGP_latest.img.gz"
            ;;
        *)
            echo -e "\033[31m 输入错误，请输入 Y 或 N \033[0m"
            open_up
            ;;
    esac
}

# --- 8. 执行确认 ---
open_op()
{
    echo
    read -n 1 -p " 确认要执行升级流程吗？(Y/N): " num2
    echo
    case $num2 in
        Y|y)
            open_up
            ;;
        *)
            echo -e "\n\033[31m >>> 升级已取消。 \033[0m\n"
            exit 1
            ;;
    esac
}

open_op
exit 0
