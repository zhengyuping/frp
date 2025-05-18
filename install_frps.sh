#!/bin/bash

# 定义frp版本和GitHub仓库信息
FRP_VERSION="v0.62.1"
GITHUB_REPO="zhengyuping/frp"

# frps 配置文件内容
# 使用用户提供的 token 和端口
FRPS_CONFIG="bindPort = 15443
token = \"qwqynO85rynQ0SqM\"

# 其他可选配置，根据需要添加
# dashboardPort = 7500
# dashboardUser = \"admin\"
# dashboardPwd = \"admin\"
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
        ;;
esac

# 从用户的 GitHub 仓库下载 frp 压缩包
# 注意：此脚本假设您的 GitHub 仓库中已包含适用于目标系统的 frp 压缩包 (frp_${FRP_VERSION#v}_linux_${FRP_ARCH}.tar.gz)
# 并且直接从 raw.githubusercontent.com 下载二进制文件可能不如从 GitHub Release 页面稳定
DOWNLOAD_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main/frp_${FRP_VERSION#v}_linux_${FRP_ARCH}.tar.gz"
INSTALL_DIR="/usr/local/frp"
CONFIG_DIR="/etc/frp"
SERVICE_FILE="/etc/systemd/system/frps.service" # 服务端使用 frps.service

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

echo "正在从您的GitHub仓库下载frp服务端压缩包 (${FRP_ARCH})..."
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

# 检测是否支持 systemd
if command -v systemctl &> /dev/null && systemctl is-system-running &> /dev/null; then
    USE_SYSTEMD=true
    echo "检测到系统使用 systemd."
else
    USE_SYSTEMD=false
    echo "未检测到系统使用 systemd."
fi

# 停止frps服务（如果正在运行且支持systemd）
if [ "$USE_SYSTEMD" = true ] && command -v systemctl &> /dev/null; then
    if systemctl is-active --quiet frps; then
        echo "正在停止frps服务..."
        systemctl stop frps
        # 等待服务停止
        sleep 5
    fi
fi

cp /tmp/frp_extract/frps ${INSTALL_DIR}/frps # 复制 frps 可执行文件
if [ $? -ne 0 ]; then
    echo "复制frps可执行文件失败。"
    exit 1
fi

echo "正在配置frps..."
mkdir -p ${CONFIG_DIR}
# 将嵌入的配置文件内容写入文件
echo "${FRPS_CONFIG}" > ${CONFIG_DIR}/frps.toml # 服务端使用 frps.toml
CONFIG_FILE="frps.toml" # 配置文件固定为 frps.toml
echo "已创建 frps.toml 配置文件"

echo "正在设置文件权限..."
chmod +x ${INSTALL_DIR}/frps
chmod 644 ${CONFIG_DIR}/${CONFIG_FILE}

# 设置开机启动（如果支持systemd）
if [ "$USE_SYSTEMD" = true ] && command -v systemctl &> /dev/null; then
    echo "正在创建systemd服务文件..."
    cat << EOF > ${SERVICE_FILE}
[Unit]
Description = Frp Server Service
After = network.target

[Service]
Type = simple
User = nobody
Restart = on-failure
RestartSec = 5s
ExecStart = ${INSTALL_DIR}/frps -c ${CONFIG_DIR}/${CONFIG_FILE}

[Install]
WantedBy = multi-user.target
EOF
    chmod 664 ${SERVICE_FILE}
    echo "正在启用并启动frps服务..."
    systemctl daemon-reload
    systemctl enable frps
    systemctl start frps
    echo "frps服务端安装并启动成功！"
    echo "您可以使用 'systemctl status frps' 查看服务状态。"
else
    echo "系统不支持 systemd，请手动启动 frps 并设置开机自启。"
    echo "frps 可执行文件路径: ${INSTALL_DIR}/frps"
    echo "frps 配置文件路径: ${CONFIG_DIR}/${CONFIG_FILE}"
    echo "手动启动命令示例: nohup ${INSTALL_DIR}/frps -c ${CONFIG_DIR}/${CONFIG_FILE} &"
fi

# 清理临时文件
rm -rf /tmp/frp.tar.gz /tmp/frp_extract
