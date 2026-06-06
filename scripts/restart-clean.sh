#!/system/bin/sh
# 彻底重置：杀所有 chroot 进程 + 卸载 + 修 fcitx profile + 标准启动。安卓 root 下跑。
# 用法: adb shell "su -c 'sh /data/local/tmp/restart-clean.sh [分辨率]'"
UBUNTU=/data/ubuntu
RES="${1:-1920x1080}"
USERNAME=lmxxf
CENV="env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root TERM=xterm-256color LANG=C.UTF-8"

echo "==================== 1. 杀掉所有残留 chroot 进程 ===================="
# 安全杀法：只杀「root 指向 /data/ubuntu」的进程（精确判断是 chroot 内进程）。
# 绝不在宿主层用 pkill -u <uid> 或 pkill <名字>——chroot 的 uid 可能撞 Android
# 的 system(uid 1000)，按 uid 杀会误伤 Android 导致手机重启；dbus-daemon 等
# 名字宿主也有，按名字杀同样危险。
killed=0
for pid in $(ls /proc 2>/dev/null | grep -E '^[0-9]+$'); do
    root=$(readlink /proc/$pid/root 2>/dev/null)
    if [ "$root" = "$UBUNTU" ]; then
        kill -9 "$pid" 2>/dev/null && killed=$((killed+1))
    fi
done
sleep 2
echo "进程已清理（杀掉 $killed 个 chroot 内进程）"
echo

echo "==================== 2. 卸载所有挂载点 ===================="
umount $UBUNTU/dev/pts 2>/dev/null
umount $UBUNTU/dev     2>/dev/null
umount $UBUNTU/proc    2>/dev/null
umount $UBUNTU/sys     2>/dev/null
# 卸 self-bind（可能多层）
n=0
while mountpoint -q "$UBUNTU" 2>/dev/null; do
    umount "$UBUNTU" 2>/dev/null || umount -l "$UBUNTU" 2>/dev/null || break
    n=$((n+1)); [ $n -gt 30 ] && break
done
echo "挂载已清理（self-bind 卸了 $n 层）"
echo

echo "==================== 3. 重新挂载（remount 去 nosuid + proc/sys/dev）===================="
mount --bind $UBUNTU $UBUNTU
mount -o remount,suid,dev,bind $UBUNTU
mkdir -p $UBUNTU/dev/pts
mount -t proc proc $UBUNTU/proc
mount -t sysfs sysfs $UBUNTU/sys
mount -o bind /dev $UBUNTU/dev
mount -t devpts devpts $UBUNTU/dev/pts
echo "nameserver 8.8.8.8" > $UBUNTU/etc/resolv.conf
echo "挂载完成"
echo

echo "==================== 4. 修 fcitx5 profile（此时 fcitx5 已停，不会被回写）===================="
mkdir -p $UBUNTU/home/$USERNAME/.config/fcitx5
cat > $UBUNTU/home/$USERNAME/.config/fcitx5/profile << 'PROFILE'
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=pinyin

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=pinyin
Layout=

[GroupOrder]
0=Default
PROFILE
# 归属 lmxxf
$CENV chroot $UBUNTU /bin/bash -c "chown -R $USERNAME:$USERNAME /home/$USERNAME/.config"
echo "profile 已设为 pinyin"
echo

echo "==================== 5. 启动 SSH + VNC 桌面（lmxxf 身份）===================="
$CENV chroot $UBUNTU /bin/bash -c "
    mkdir -p /run/sshd /run/dbus
    [ -f /etc/ssh/ssh_host_ed25519_key ] || ssh-keygen -A >/dev/null 2>&1
    pgrep -x sshd >/dev/null 2>&1 || /usr/sbin/sshd -p 2222
"
$CENV chroot $UBUNTU /bin/bash -c "su - $USERNAME -c 'bash /home/$USERNAME/start-vnc.sh $RES'"
echo
echo "==================== 完成！VNC 重连 127.0.0.1:5900，Ctrl+Space 切中文 ===================="
