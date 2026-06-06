#!/system/bin/sh
# Ubuntu chroot 入口脚本（带自动 remount 去 nosuid，使 sudo 可用）。须 root。
# 由 install-ubuntu.sh 自动生成此文件；此副本可单独推送覆盖旧版。
UBUNTU=/data/ubuntu

[ "$(id -u)" -eq 0 ] || { echo "[!] 需要 root: adb shell \"su -c 'sh /data/local/tmp/ubuntu-enter.sh'\""; exit 1; }
[ -f "$UBUNTU/etc/os-release" ] || { echo "[!] Ubuntu 未安装，先运行 install-ubuntu.sh"; exit 1; }

# Android 的 /data 默认 nosuid，会让 chroot 内 sudo/su 等 setuid 程序失效。
# bind /data/ubuntu 到自身建立独立挂载点，再 remount 去掉 nosuid，让 sudo 能用。
# 防重复堆叠：已是独立挂载点就跳过 bind。
if ! mountpoint -q "$UBUNTU" 2>/dev/null; then
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

# 自动启动 sshd（端口 2222，避开系统占用的 22）
$CENV chroot $UBUNTU /bin/bash -c "
    mkdir -p /run/sshd
    [ -f /etc/ssh/ssh_host_ed25519_key ] || ssh-keygen -A >/dev/null 2>&1
    if ! pgrep -x sshd >/dev/null 2>&1; then
        /usr/sbin/sshd -p 2222 && echo '[*] SSH 已启动（端口 2222）'
    fi
" 2>/dev/null

$CENV chroot $UBUNTU /bin/bash -l
