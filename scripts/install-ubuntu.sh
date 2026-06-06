#!/system/bin/sh
#
# Ubuntu on Android — 一键安装脚本（chroot + glibc）
# 在已 root（KernelSU/Magisk/APatch）的 Android 设备上 chroot 运行 Ubuntu 24.04
#
# 用法（PC 端 PowerShell）:
#   adb push install-ubuntu.sh /data/local/tmp/install-ubuntu.sh
#   adb push ubuntu-base-24.04-arm64.tar.gz /data/local/tmp/ubuntu-base.tar.gz
#   adb shell "su -c 'sh /data/local/tmp/install-ubuntu.sh'"
#

UBUNTU_DIR="/data/ubuntu"
ROOTFS_FILE="/data/local/tmp/ubuntu-base.tar.gz"
ENTER_SCRIPT="/data/local/tmp/ubuntu-enter.sh"

info() { echo "[*] $1"; }
err()  {
    printf '\033[1;31m' >&2
    echo "" >&2
    echo "################################################################" >&2
    echo "##  [安装失败] $1" >&2
    echo "##  脚本已停止，未完成安装。请排查上面这一步的错误。" >&2
    echo "################################################################" >&2
    printf '\033[0m' >&2
    exit 1
}
retry() {
    n=0; max=3
    while [ $n -lt $max ]; do
        "$@" && return 0
        n=$((n+1))
        printf '\033[1;33m[!] 失败，重试 %s/%s ...\033[0m\n' "$n" "$max" >&2
        sleep 2
    done
    return 1
}

# 关键：env -i 在 chroot 外执行，清空 Android 宿主污染的 PATH/环境
ENVCLEAN="env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root TERM=xterm-256color DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8"

# ── 前置检查 ──

[ "$(id -u)" -eq 0 ] || err "需要 root 权限。请用: adb shell \"su -c 'sh /data/local/tmp/install-ubuntu.sh'\""
[ "$(uname -m)" = "aarch64" ] || err "仅支持 aarch64 架构（当前 $(uname -m)）"

if [ -f "$UBUNTU_DIR/etc/os-release" ]; then
    info "已安装 Ubuntu（$(grep PRETTY_NAME $UBUNTU_DIR/etc/os-release | cut -d'\"' -f2)），跳过安装"
    info "如需重装，先执行: adb shell \"su -c 'sh /data/local/tmp/uninstall-ubuntu.sh'\""
    info "入口脚本: adb shell \"su -c 'sh $ENTER_SCRIPT'\""
    exit 0
fi

# ── 检查 rootfs ──

[ -f "$ROOTFS_FILE" ] || err "未找到 $ROOTFS_FILE，请先推送:
  adb push ubuntu-base-24.04-arm64.tar.gz $ROOTFS_FILE"

# ── 解压 ──

info "解压 Ubuntu base 到 $UBUNTU_DIR ..."
mkdir -p "$UBUNTU_DIR"
tar xzf "$ROOTFS_FILE" -C "$UBUNTU_DIR" 2>/dev/null || true
[ -f "$UBUNTU_DIR/etc/os-release" ] || err "解压失败，未找到 os-release"
info "$(grep PRETTY_NAME $UBUNTU_DIR/etc/os-release | cut -d'\"' -f2) 解压完成"

# ── 基础配置 ──

info "配置 DNS 和软件源 ..."
echo "nameserver 8.8.8.8" > "$UBUNTU_DIR/etc/resolv.conf"
echo "nameserver 1.1.1.1" >> "$UBUNTU_DIR/etc/resolv.conf"

# arm64 的 Ubuntu 包在 ports.ubuntu.com（不是 archive.ubuntu.com）。
# 用官方 ports 源，不挑 VPN 出口 IP（清华/中科大对境外 IP 返回 403）。
# Ubuntu 24.04 用新版 deb822 格式的 sources（.sources 文件）。
mkdir -p "$UBUNTU_DIR/etc/apt/sources.list.d"
cat > "$UBUNTU_DIR/etc/apt/sources.list.d/ubuntu.sources" << 'EOF'
Types: deb
URIs: http://ports.ubuntu.com/ubuntu-ports
Suites: noble noble-updates noble-backports noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
# 清掉可能存在的旧式 sources.list 避免重复
: > "$UBUNTU_DIR/etc/apt/sources.list" 2>/dev/null || true

# ── 挂载 ──

info "挂载虚拟文件系统 ..."
mkdir -p "$UBUNTU_DIR/dev/pts"
mountpoint -q "$UBUNTU_DIR/proc"    || mount -t proc proc "$UBUNTU_DIR/proc"
mountpoint -q "$UBUNTU_DIR/sys"     || mount -t sysfs sysfs "$UBUNTU_DIR/sys"
mountpoint -q "$UBUNTU_DIR/dev"     || mount -o bind /dev "$UBUNTU_DIR/dev"
mountpoint -q "$UBUNTU_DIR/dev/pts" || mount -t devpts devpts "$UBUNTU_DIR/dev/pts"

# ── 初始化 apt ──

info "更新软件源索引（apt update）..."
retry $ENVCLEAN chroot "$UBUNTU_DIR" /bin/bash -c "apt-get update" || err "apt update 失败（已重试 3 次）。挂 VPN 时确认能访问 ports.ubuntu.com"

info "安装基础工具（apt install）..."
retry $ENVCLEAN chroot "$UBUNTU_DIR" /bin/bash -c "apt-get install -y --no-install-recommends curl htop tmux openssh-server sudo nano ca-certificates locales iproute2 iputils-ping" || err "apt install 失败（已重试 3 次）"

# ── 生成入口脚本 ──

info "生成入口脚本: $ENTER_SCRIPT"
cat > "$ENTER_SCRIPT" << 'ENTER'
#!/system/bin/sh
UBUNTU=/data/ubuntu

[ "$(id -u)" -eq 0 ] || { echo "[!] 需要 root: adb shell \"su -c 'sh /data/local/tmp/ubuntu-enter.sh'\""; exit 1; }
[ -f "$UBUNTU/etc/os-release" ] || { echo "[!] Ubuntu 未安装，先运行 install-ubuntu.sh"; exit 1; }

# Android 的 /data 默认 nosuid，会让 chroot 内 sudo/su 等 setuid 程序失效。
# bind /data/ubuntu 到自身建立独立挂载点，再 remount 去掉 nosuid，让 sudo 能用。
if ! grep -q " $UBUNTU $UBUNTU" /proc/mounts 2>/dev/null && ! mountpoint -q "$UBUNTU"; then
    mount --bind $UBUNTU $UBUNTU 2>/dev/null
    mount -o remount,suid,dev,bind $UBUNTU 2>/dev/null
fi

mkdir -p $UBUNTU/dev/pts
mountpoint -q $UBUNTU/proc    || mount -t proc proc $UBUNTU/proc
mountpoint -q $UBUNTU/sys     || mount -t sysfs sysfs $UBUNTU/sys
mountpoint -q $UBUNTU/dev     || mount -o bind /dev $UBUNTU/dev
mountpoint -q $UBUNTU/dev/pts || mount -t devpts devpts $UBUNTU/dev/pts

echo "nameserver 8.8.8.8" > $UBUNTU/etc/resolv.conf

CENV="env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root TERM=xterm-256color LANG=C.UTF-8"

# 自动启动 sshd（端口 2222，避开 OH/系统占用的 22）
$CENV chroot $UBUNTU /bin/bash -c "
    mkdir -p /run/sshd
    [ -f /etc/ssh/ssh_host_ed25519_key ] || ssh-keygen -A >/dev/null 2>&1
    if ! pgrep -x sshd >/dev/null 2>&1; then
        /usr/sbin/sshd -p 2222 && echo '[*] SSH 已启动（端口 2222）'
    fi
" 2>/dev/null

$CENV chroot $UBUNTU /bin/bash -l
ENTER
chmod +x "$ENTER_SCRIPT"

# ── 清理 ──

rm -f "$ROOTFS_FILE"

# ── 完成 ──

info "========================================"
info "  安装完成！Ubuntu 24.04（glibc）"
info "  进入 Linux:  adb shell \"su -c 'sh $ENTER_SCRIPT'\""
info "  安装软件:    apt install <包名>"
info "  设置密码:    passwd（进去后执行，配 SSH 登录用）"
info "  占用空间:    约 $(du -sh "$UBUNTU_DIR" 2>/dev/null | sed 's/[[:space:]].*//')"
info "========================================"
