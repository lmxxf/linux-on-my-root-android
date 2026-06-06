#!/system/bin/sh
# 抓 apk "Permission denied" 的真实 syscall。须 root。
ALPINE=/data/alpine

mkdir -p $ALPINE/dev/pts $ALPINE/tmp $ALPINE/var/cache/apk
chmod 1777 $ALPINE/tmp
mountpoint -q $ALPINE/proc    || mount -t proc proc $ALPINE/proc
mountpoint -q $ALPINE/sys     || mount -t sysfs sysfs $ALPINE/sys
mountpoint -q $ALPINE/dev     || mount -o bind /dev $ALPINE/dev
mountpoint -q $ALPINE/dev/pts || mount -t devpts devpts $ALPINE/dev/pts
echo "nameserver 8.8.8.8" > $ALPINE/etc/resolv.conf

ENVCLEAN="env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin HOME=/root TERM=xterm"

echo "==================== /tmp 存在? ===================="
ls -ld $ALPINE/tmp
echo

echo "==================== apk --verbose -v -v update（看详细哪步失败） ===================="
$ENVCLEAN chroot "$ALPINE" /bin/sh -c "apk update --allow-untrusted -v -v" 2>&1
echo

echo "==================== chroot 内有无 strace ===================="
$ENVCLEAN chroot "$ALPINE" /bin/sh -c "command -v strace || echo 'no strace'"
echo

echo "==================== 宿主 strace 抓 apk(若宿主有 strace) ===================="
if command -v strace >/dev/null 2>&1; then
    echo "[宿主有 strace,抓 apk 的失败 syscall]"
    $ENVCLEAN strace -f -e trace=open,openat,mmap,write,access -o /data/local/tmp/apk.strace chroot "$ALPINE" /bin/sh -c "apk update --allow-untrusted" 2>&1 | tail -5
    echo "--- strace 里 EACCES/EPERM 的行 ---"
    grep -E "EACCES|EPERM" /data/local/tmp/apk.strace | tail -20
else
    echo "宿主无 strace"
fi
echo

echo "==================== 手动验证:能否在 chroot 内创建 APKINDEX 缓存文件 ===================="
$ENVCLEAN chroot "$ALPINE" /bin/sh -c '
  echo "  尝试写 APKINDEX 缓存名:"
  touch "/var/cache/apk/APKINDEX.8b74877b.tar.gz" 2>&1 && echo "  创建 APKINDEX 缓存 OK" || echo "  创建 APKINDEX 缓存 FAIL"
  ls -la /var/cache/apk/
'
echo
echo "==================== 完成 ===================="
