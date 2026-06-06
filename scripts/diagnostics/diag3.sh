#!/system/bin/sh
# 精确诊断 apk 的 Permission denied 到底卡在 SELinux 还是 nosuid 还是别的。须 root。
ALPINE=/data/alpine

# 确保挂载齐全
mkdir -p $ALPINE/dev/pts
mountpoint -q $ALPINE/proc    || mount -t proc proc $ALPINE/proc
mountpoint -q $ALPINE/sys     || mount -t sysfs sysfs $ALPINE/sys
mountpoint -q $ALPINE/dev     || mount -o bind /dev $ALPINE/dev
mountpoint -q $ALPINE/dev/pts || mount -t devpts devpts $ALPINE/dev/pts
echo "nameserver 8.8.8.8" > $ALPINE/etc/resolv.conf

ENVCLEAN="env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin HOME=/root TERM=xterm"

echo "==================== 1) Enforcing 下 apk update ===================="
echo "[getenforce] $(getenforce)"
$ENVCLEAN chroot "$ALPINE" /bin/sh -c "apk update --allow-untrusted" 2>&1
echo

echo "==================== 2) 切 Permissive 再试 apk update ===================="
ORIG=$(getenforce)
setenforce 0 2>&1 && echo "[setenforce 0] -> now $(getenforce)" || echo "setenforce 失败"
$ENVCLEAN chroot "$ALPINE" /bin/sh -c "apk update --allow-untrusted" 2>&1
echo

echo "==================== 3) Permissive 下,apk 缓存目录写什么标签 ===================="
ls -laZ "$ALPINE/var/cache/apk/" 2>&1 | head -5
echo

echo "==================== 4) 直接 strace 式定位:手动复现 apk 的写动作 ===================="
# apk 写 APKINDEX 到 /var/cache/apk/,我们在 chroot 内模拟「创建+改属性」
$ENVCLEAN chroot "$ALPINE" /bin/sh -c '
  echo test > /var/cache/apk/_x 2>&1 && echo "  write OK" || echo "  write FAIL"
  chmod 644 /var/cache/apk/_x 2>&1 && echo "  chmod OK" || echo "  chmod FAIL"
  chown 0:0 /var/cache/apk/_x 2>&1 && echo "  chown OK" || echo "  chown FAIL"
  rm -f /var/cache/apk/_x
'
echo

# 恢复
if [ "$ORIG" = "Enforcing" ]; then setenforce 1 2>&1 && echo "[恢复 Enforcing]"; fi
echo "==================== 完成 ===================="
