#!/bin/bash

# 定义frp版本和GitHub仓库信息
FRP_VERSION="v0.62.1"
GITHUB_REPO="zhengyuping/frp"

# 检查命令行参数
if [ "$#" -ne 2 ]; then
    echo "用法: $0 <local_port> <remote_port>"
    echo "示例: $0 22 3025"
    exit 1
fi

LOCAL_PORT="$1"
REMOTE_PORT="$2"

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
        FP_ARCH="arm"
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
DOWNLOAD_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main/frp_${FRP_VERSION#v}_linux_${FRP_ARCH}.tar.gz"
TEMP_DIR="/tmp/frp_install_$(date +%s)"
FRPC_CONFIG_FILE="${TEMP_DIR}/frpc.ini"

# 检查是否安装了wget和tar
if ! command -v wget &> /dev/null || ! command -v tar &> /dev/null; then
    echo "错误: 容器镜像中未找到 wget 或 tar 命令。请确保镜像包含这些工具。"
    exit 1
fi

echo "正在创建临时目录 ${TEMP_DIR}..."
mkdir -p ${TEMP_DIR}
if [ $? -ne 0 ]; then
    echo "创建临时目录失败。"
    exit 1
fi

echo "正在从您的GitHub仓库下载frp客户端压缩包 (${FRP_ARCH})..."
wget -O ${TEMP_DIR}/frp.tar.gz ${DOWNLOAD_URL}
if [ $? -ne 0 ]; then
    echo "下载frp压缩包失败，请检查您的GitHub仓库中是否存在 ${DOWNLOAD_URL} 文件以及网络连接。"
    echo "提示：直接从 raw.githubusercontent.com 下载二进制文件可能工作不稳定。"
    rm -rf ${TEMP_DIR}
    exit 1
fi

echo "正在解压文件..."
tar -xzf ${TEMP_DIR}/frp.tar.gz -C ${TEMP_DIR} --strip-components=1
if [ $? -ne 0 ]; then
    echo "解压失败。"
    rm -rf ${TEMP_DIR}
    exit 1
fi

echo "正在生成 frpc.ini 配置文件..."
# frpc 配置文件内容
FRPC_CONFIG="[common]
server_addr = 43.128.153.235
server_port = 15443
token = qwqynO85rynQ0SqM

[ssh]
type = tcp
local_ip = 127.0.0.1
local_port = ${LOCAL_PORT}
remote_port = ${REMOTE_PORT}
"

# 将配置文件内容写入文件
echo "${FRPC_CONFIG}" > ${FRPC_CONFIG_FILE}
if [ $? -ne 0 ]; then
    echo "写入 frpc.ini 配置文件失败。"
    rm -rf ${TEMP_DIR}
    exit 1
fi
echo "已创建 frpc.ini 配置文件: ${FRPC_CONFIG_FILE}"

echo "正在设置文件权限..."
chmod +x ${TEMP_DIR}/frpc
chmod 644 ${FRPC_CONFIG_FILE}

echo "正在启动 frpc 客户端..."
# 直接执行 frpc，不作为服务运行
${TEMP_DIR}/frpc -c ${FRPC_CONFIG_FILE}

# 注意：由于 frpc 会在前台运行，脚本会在这里阻塞。
# 如果 frpc 进程退出，脚本会继续执行清理步骤。
# 在容器中，通常希望主进程（这里是 frpc）在前台运行。

# 清理临时文件 (frpc 退出后执行)
echo "frpc 进程已退出，正在清理临时文件..."
rm -rf ${TEMP_DIR}
echo "清理完成。"
