#!/bin/bash

# 定义frp版本和GitHub仓库信息
FRP_VERSION="v0.62.1"
GITHUB_REPO="zhengyuping/frp"

# frpc 配置文件内容 (嵌入在脚本中)
# 请根据您的实际需求修改以下内容
FRPC_CONFIG="[common]
server_addr = 43.128.153.235
server_port = 15443
token = qwqynO85rynQ0SqM

[ssh]
type = tcp
local_ip = 127.0.0.1
local_port = 22
remote_port = 3023
"

# 根据系统架构判断下载文件名后缀
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
    loongarch64) # 对应 loong64
        FRP_ARCH="loong64"
        ;;
    mips) # 对应 mips
        FRP_ARCH="mips"
        ;;
    mips64) # 对应 mips64
        FRP_ARCH="mips64"
        ;;
    mips64el) # 对应 mips64le
        FRP_ARCH="mips64le"
        ;;
    mipsel) # 对应 mipsle
        FRP_ARCH="mipsle"
        ;;
    riscv64) # 对应 riscv64
        FRP_ARCH="riscv64"
        ;;
    *)
        echo "不支持的系统架构: ${ARCH}"
        echo "支持的架构有: x86_64 (amd64), aarch64 (arm64), armv7l (arm), loongarch64 (loong64), mips (mips), mips64 (mips64), mips64el (mips64le), mipsel (mipsle), riscv64 (riscv64)"
        exit 1
        ;;esac

# 从用户的 GitHub 仓库下载 frp 压缩包
# 注意：此脚本假设您的 GitHub 仓库中已包含适用于目标系统的 frp 压缩包 (frp_${FRP_VERSION#v}_linux_${FRP_ARCH}.tar.gz)
# 并且直接从 raw.githubusercontent.com 下载二进制文件可能不如从 GitHub Release 页面稳定
DOWNLOAD_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main/frp_${FRP_VERSION#v}_linux_${FRP_ARCH}.tar.gz"
INSTALL_DIR="/usr/local/frp"
CONFIG_DIR="/etc/frp"
SERVICE_FILE="/etc/systemd/system/frpc.service"

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

echo "正在从您的GitHub仓库下载frp客户端压缩包 (${FRP_ARCH})..."
wget -O /tmp/frp.tar.gz ${DOWNLOAD_URL}
if [ $? -ne 0 ]; then
    echo "下载frp压缩包失败，请检查您的GitHub仓库中是否存在 ${DOWNLOAD_URL} 文件以及网络连接。"
    echo "提示：直接从 raw.githubusercontent.com 下载二进制文件可能工作不稳定。"
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
# 停止frpc服务（如果正在运行）
if systemctl is-active --quiet frpc; then
    echo "正在停止frpc服务..."
    systemctl stop frpc
    # 等待服务停止
    sleep 5
fi
cp /tmp/frp_extract/frpc ${INSTALL_DIR}/frpc
if [ $? -ne 0 ]; then
    echo "复制frpc可执行文件失败。"
    exit 1
fi

echo "正在配置frpc..."
mkdir -p ${CONFIG_DIR}
# 将嵌入的配置文件内容写入文件
echo "${FRPC_CONFIG}" > ${CONFIG_DIR}/frpc.ini
CONFIG_FILE="frpc.ini" # 配置文件固定为 frpc.ini
echo "已创建 frpc.ini 配置文件"


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
