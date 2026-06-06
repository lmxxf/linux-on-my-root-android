#!/system/bin/sh
#
# Linux on Android — 一键安装脚本
# 在已 root（KernelSU/Magisk/APatch）的 Android 设备上通过 chroot 运行完整 Alpine Linux
#
# 用法（PC 端 PowerShell）:
#   adb push install.sh /data/local/tmp/install.sh
#   adb push alpine-minirootfs-3.21.3-aarch64.tar.gz /data/local/tmp/alpine-minirootfs.tar.gz
#   adb shell "su -c 'sh /data/local/tmp/install.sh'"
#

ALPINE_DIR="/data/alpine"
ALPINE_VERSION="3.21"
ROOTFS_FILE="/data/local/tmp/alpine-minirootfs.tar.gz"
ENTER_SCRIPT="/data/local/tmp/alpine-enter.sh"

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

# ── 前置检查 ──

[ "$(id -u)" -eq 0 ] || err "需要 root 权限。请用: adb shell \"su -c 'sh /data/local/tmp/install.sh'\""
[ "$(uname -m)" = "aarch64" ] || err "仅支持 aarch64 架构（当前 $(uname -m)）"

if [ -f "$ALPINE_DIR/etc/alpine-release" ]; then
    installed=$(cat "$ALPINE_DIR/etc/alpine-release")
    info "已安装 Alpine $installed，跳过安装"
    info "如需重装，先执行: adb shell \"su -c 'sh /data/local/tmp/uninstall.sh'\""
    info "入口脚本: adb shell \"su -c 'sh $ENTER_SCRIPT'\""
    exit 0
fi

# ── 检查 rootfs ──

[ -f "$ROOTFS_FILE" ] || err "未找到 $ROOTFS_FILE，请先推送:
  adb push alpine-minirootfs-3.21.3-aarch64.tar.gz $ROOTFS_FILE"

# ── 解压 ──

info "解压到 $ALPINE_DIR ..."
mkdir -p "$ALPINE_DIR"

# toybox tar 对 ./ 条目报错但实际能解压，忽略该错误
tar xzf "$ROOTFS_FILE" -C "$ALPINE_DIR" 2>/dev/null || true

[ -f "$ALPINE_DIR/etc/alpine-release" ] || err "解压失败，未找到 alpine-release"
info "Alpine $(cat "$ALPINE_DIR/etc/alpine-release") 解压完成"

# ── 基础配置 ──

info "配置 DNS 和软件源 ..."
echo "nameserver 8.8.8.8" > "$ALPINE_DIR/etc/resolv.conf"
# 注意：清华/中科大等教育网镜像对境外 IP 返回 403（防境外蹭流量）。
# 挂 VPN 时出口 IP 是境外的，必须用不挑 IP 的源：Alpine 官方 dl-cdn 或阿里云。
# apk 会把 HTTP 403 错误翻译成误导性的 "Permission denied"。
cat > "$ALPINE_DIR/etc/apk/repositories" << EOF
http://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/main
http://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/community
EOF

# ── 挂载 ──
# Android 不需要 OH 那套 eth0/eth1 路由修复——手机的 wlan/数据网由系统自己管路由。

info "挂载虚拟文件系统 ..."
mkdir -p "$ALPINE_DIR/dev/pts"
mountpoint -q "$ALPINE_DIR/proc"    || mount -t proc proc "$ALPINE_DIR/proc"
mountpoint -q "$ALPINE_DIR/sys"     || mount -t sysfs sysfs "$ALPINE_DIR/sys"
mountpoint -q "$ALPINE_DIR/dev"     || mount -o bind /dev "$ALPINE_DIR/dev"
mountpoint -q "$ALPINE_DIR/dev/pts" || mount -t devpts devpts "$ALPINE_DIR/dev/pts"

# ── 初始化包管理器 ──

# 关键：env -i 必须在 chroot 外面执行（先清空宿主环境，再调 chroot）。
# 否则 Android 的 su 会把 PATH=/system/bin:/apex/...:/data/adb/ksu/bin 带进 chroot，
# 导致 chroot 内找不到 apk 调用的外部命令（报错伪装成 Permission denied）。
# 写成 chroot ... env ... 是错的——env 会在新根里找不到自己。
ENVCLEAN="env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin HOME=/root TERM=xterm-256color"

info "更新软件源索引 ..."
retry $ENVCLEAN chroot "$ALPINE_DIR" /bin/sh -c "apk update --allow-untrusted" || err "apk update 失败（已重试 3 次），检查网络（手机能上网吗？时间对吗？）"

info "安装基础工具 ..."
retry $ENVCLEAN chroot "$ALPINE_DIR" /bin/sh -c "apk add --allow-untrusted bash curl htop tmux openssh" || err "apk add 失败（已重试 3 次）"

# ── 生成入口脚本 ──
# 注意：enter 脚本假设由 root 调起（adb shell "su -c 'sh ...enter.sh'"）

info "生成入口脚本: $ENTER_SCRIPT"
cat > "$ENTER_SCRIPT" << 'ENTER'
#!/system/bin/sh
ALPINE=/data/alpine

[ "$(id -u)" -eq 0 ] || { echo "[!] 需要 root: adb shell \"su -c 'sh /data/local/tmp/alpine-enter.sh'\""; exit 1; }
[ -d "$ALPINE/bin" ] || { echo "[!] Alpine 未安装，先运行 install.sh"; exit 1; }

mkdir -p $ALPINE/dev/pts
mountpoint -q $ALPINE/proc    || mount -t proc proc $ALPINE/proc
mountpoint -q $ALPINE/sys     || mount -t sysfs sysfs $ALPINE/sys
mountpoint -q $ALPINE/dev     || mount -o bind /dev $ALPINE/dev
mountpoint -q $ALPINE/dev/pts || mount -t devpts devpts $ALPINE/dev/pts

echo "nameserver 8.8.8.8" > $ALPINE/etc/resolv.conf

# 关键：env -i 在 chroot 外面执行，清空 Android 宿主环境
CENV="env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin HOME=/root TERM=xterm-256color"

# 自动启动 dropbear SSH（如果已安装且未运行），端口 2222
$CENV chroot $ALPINE /bin/sh -c "command -v dropbear >/dev/null 2>&1 && ! pidof dropbear >/dev/null 2>&1 && dropbear -R -p 2222 && echo '[*] SSH 已启动（端口 2222）'" 2>/dev/null

$CENV chroot $ALPINE /bin/sh -l
ENTER
chmod +x "$ENTER_SCRIPT"

# ── 清理 ──

rm -f "$ROOTFS_FILE"

# ── 完成 ──

info "========================================"
info "  安装完成！"
info "  进入 Linux:  adb shell \"su -c 'sh $ENTER_SCRIPT'\""
info "  安装软件:    apk add <包名>"
info "  占用空间:    约 $(du -sh "$ALPINE_DIR" 2>/dev/null | sed 's/[[:space:]].*//')"
info "========================================"
