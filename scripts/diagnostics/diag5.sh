#!/system/bin/sh
# 终极定位 apk 的 Permission denied。须 root。
# 策略:给 chroot 装 strace(用 apk 的本地缓存装不了,改用静态 wget 下 apk-tools 调试)
# 退一步:先测 O_TMPFILE 假设 + 用 apk 的 --cache-dir 改缓存位置试探
ALPINE=/data/alpine

mkdir -p $ALPINE/dev/pts $ALPINE/tmp
chmod 1777 $ALPINE/tmp
mountpoint -q $ALPINE/proc    || mount -t proc proc $ALPINE/proc
mountpoint -q $ALPINE/sys     || mount -t sysfs sysfs $ALPINE/sys
mountpoint -q $ALPINE/dev     || mount -o bind /dev $ALPINE/dev
mountpoint -q $ALPINE/dev/pts || mount -t devpts devpts $ALPINE/dev/pts
echo "nameserver 8.8.8.8" > $ALPINE/etc/resolv.conf

ENVCLEAN="env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin HOME=/root TERM=xterm TMPDIR=/tmp"

echo "==================== 假设A: apk 缓存到 tmpfs(/dev/shm 或 /tmp 是 tmpfs) ===================="
echo "把 apk 缓存目录指到一个 tmpfs(绕开 f2fs):"
# 在 chroot 内挂一个 tmpfs 到 /var/cache/apk
mkdir -p $ALPINE/var/cache/apk
mount -t tmpfs tmpfs $ALPINE/var/cache/apk 2>&1 && echo "  tmpfs 挂载到 var/cache/apk OK" || echo "  tmpfs 挂载失败"
$ENVCLEAN chroot "$ALPINE" /bin/sh -c "apk update --allow-untrusted" 2>&1
umount $ALPINE/var/cache/apk 2>/dev/null
echo

echo "==================== 假设B: 整个 /tmp 用 tmpfs,缓存指 /tmp ===================="
mount -t tmpfs tmpfs $ALPINE/tmp 2>&1 && echo "  tmpfs 挂到 /tmp OK" || echo "  /tmp tmpfs 失败"
chmod 1777 $ALPINE/tmp
$ENVCLEAN chroot "$ALPINE" /bin/sh -c "apk update --allow-untrusted --cache-dir /tmp" 2>&1
echo

echo "==================== 假设C: 看 apk 是不是卡在 mmap(用 cat 直接读 APKINDEX) ===================="
# fetch 能成功说明网络OK。手动下 APKINDEX 到 tmpfs,看 apk 能否解析本地文件
$ENVCLEAN chroot "$ALPINE" /bin/sh -c "
  cd /tmp
  wget -q http://mirrors.tuna.tsinghua.edu.cn/alpine/v3.21/main/aarch64/APKINDEX.tar.gz -O APKINDEX.tar.gz 2>&1
  echo '  下载结果:'; ls -la /tmp/APKINDEX.tar.gz 2>&1
  echo '  尝试解压(测 musl tar + mmap):'
  tar tzf /tmp/APKINDEX.tar.gz 2>&1 | head -3
"
umount $ALPINE/tmp 2>/dev/null
echo

echo "==================== 假设D: dmesg 看内核有没有拒绝记录(avc/seccomp) ===================="
dmesg 2>/dev/null | tail -30 | grep -iE "avc|denied|seccomp|apk" || echo "  dmesg 无相关记录(或无权读 dmesg)"
echo
echo "==================== 完成 ===================="
