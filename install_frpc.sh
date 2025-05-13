#!/bin/bash

# 定义frp版本、下载链接和GitHub仓库信息
FRP_VERSION="v0.62.1"
GITHUB_REPO="zhengyuping/frp"
# 根据系统架构判断下载文件名
ARCH=$(uname -m)
case ${ARCH} in
    x86_64)
        FRP_ARCH="amd64"
        ;;
    aarch64)
        FRP_ARCH="arm64"
        ;;
    armv7l)
        FRP_ARCH="arm"
        ;;
    *)
        echo "不支持的系统架构: ${ARCH}"
        exit 1
        ;;\nesac

# 从 GitHub Release 页面下载 frp 二进制文件
DOWNLOAD_URL="https://github.com/fatedier/frp/releases/download/${FRP_VERSION}/frp_${FRP_VERSION#v}_linux_${FRP_ARCH}.tar.gz"
INSTALL_DIR="/usr/local/frp"
CONFIG_DIR="/etc/frp"
SERVICE_FILE="/etc/systemd/system/frpc.service"
# 从用户的 GitHub 仓库下载配置文件
GITHUB_RAW_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main"

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
  echo "请以root用户运行此脚本"
  exit 1
fi

# 检查是否安装了wget和tar
if ! command -v wget &> /dev/null || ! command -v tar &> /dev/null; then
    echo "请先安装wget和tar: apt update && apt install -y wget tar"
    exit 1
fi

echo "正在下载frp客户端 ${FRP_VERSION}..."
wget -O /tmp/frp.tar.gz ${DOWNLOAD_URL}
if [ $? -ne 0 ]; then
    echo "下载失败，请检查版本和网络连接。下载地址: ${DOWNLOAD_URL}"
    echo "提示：frp 二进制文件应从 GitHub Release 页面下载，而不是 raw.githubusercontent.com。"
    exit 1
fi

echo "正在解压文件..."
mkdir -p /tmp/frp_extract
tar -xzf /tmp/frp.tar.gz -C /tmp/frp_extract --strip-components=1
if [ $? -ne 0 ]; then
    echo "解压失败。"
    exit 1
fi

echo "正在安装frp到 ${INSTALL_DIR}..."
mkdir -p ${INSTALL_DIR}
cp /tmp/frp_extract/frpc ${INSTALL_DIR}/frpc
if [ $? -ne 0 ]; then
    echo "复制frpc可执行文件失败。"
    exit 1
fi

echo "正在配置frpc..."
mkdir -p ${CONFIG_DIR}
# 从GitHub下载配置文件，优先下载frpc.ini
echo "正在从GitHub下载配置文件..."
wget -O ${CONFIG_DIR}/frpc.ini ${GITHUB_RAW_URL}/frpc.ini
if [ $? -eq 0 ]; then
    CONFIG_FILE="frpc.ini"
    echo "已下载 frpc.ini"
else
    echo "下载 frpc.ini 失败，尝试下载 frpc.toml..."
    wget -O ${CONFIG_DIR}/frpc.toml ${GITHUB_RAW_URL}/frpc.toml
    if [ $? -eq 0 ]; then
        CONFIG_FILE="frpc.toml"
        echo "已下载 frpc.toml"
    else
        echo "未找到 frpc.ini 或 frpc.toml 配置文件在 GitHub 仓库中。"
        exit 1
    fi
fi


echo "正在创建systemd服务文件..."
cat << EOF > ${SERVICE_FILE}
[Unit]
Description = Frp Client Service
After = network.target

[Service]
Type = simple
User = nobody
Restart = on-failure
RestartSec = 5s
ExecStart = ${INSTALL_DIR}/frpc -c ${CONFIG_DIR}/${CONFIG_FILE}

[Install]
WantedBy = multi-user.target
EOF

echo "正在设置文件权限..."
chmod +x ${INSTALL_DIR}/frpc
chmod 644 ${CONFIG_DIR}/${CONFIG_FILE}
chmod 664 ${SERVICE_FILE}

echo "正在启用并启动frpc服务..."
systemctl daemon-reload
systemctl enable frpc
systemctl start frpc

echo "frpc客户端安装并启动成功！"
echo "您可以使用 'systemctl status frpc' 查看服务状态。"

# 清理临时文件
rm -rf /tmp/frp.tar.gz /tmp/frp_extract
