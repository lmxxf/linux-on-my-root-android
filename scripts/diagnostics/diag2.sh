#!/system/bin/sh
# 二次诊断:chroot 内环境到底瘸在哪。须 root。
ALPINE=/data/alpine

echo "==================== /bin 内容 ===================="
ls -la "$ALPINE/bin/" 2>&1 | head -30
echo

echo "==================== busybox 是否存在 ===================="
ls -la "$ALPINE/bin/busybox" 2>&1
echo

echo "==================== 宿主层在 apk 目录写(已知 OK,再确认) ===================="
touch "$ALPINE/var/cache/apk/_h2" 2>&1 && echo HOST_OK && rm -f "$ALPINE/var/cache/apk/_h2" || echo HOST_FAIL
echo

echo "==================== chroot 内用绝对路径 busybox touch ===================="
chroot "$ALPINE" /bin/busybox sh -c '/bin/busybox touch /var/cache/apk/_b 2>&1 && echo BB_TOUCH_OK && /bin/busybox rm -f /var/cache/apk/_b || echo BB_TOUCH_FAIL'
echo

echo "==================== chroot 内 PATH 和 mount 视角 ===================="
chroot "$ALPINE" /bin/busybox sh -c 'echo PATH=$PATH; /bin/busybox mount 2>/dev/null | /bin/busybox grep -E " / |/var" || echo "(no mount info)"'
echo

echo "==================== chroot 内写到 /tmp 和 /root(对比不同目录) ===================="
chroot "$ALPINE" /bin/busybox sh -c '/bin/busybox touch /tmp/_t 2>&1 && echo TMP_OK || echo TMP_FAIL; /bin/busybox touch /root/_r 2>&1 && echo ROOT_OK || echo ROOT_FAIL'
echo
echo "==================== 完成 ===================="
