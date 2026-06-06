#!/system/bin/sh
# 诊断 apk 在 chroot 内写文件被 Permission denied 的根因。须 root 跑。

ALPINE=/data/alpine

echo "==================== 挂载属性 ===================="
grep -E ' /data ' /proc/mounts
echo

echo "==================== apk 缓存目录 SELinux 标签 ===================="
ls -laZ "$ALPINE/var/cache/apk/" 2>&1
echo

echo "==================== 宿主直接写(不进 chroot) ===================="
if touch "$ALPINE/var/cache/apk/_host_test" 2>&1; then
    echo "HOST_WRITE_OK"
    rm -f "$ALPINE/var/cache/apk/_host_test"
else
    echo "HOST_WRITE_FAIL"
fi
echo

echo "==================== chroot 内写 ===================="
chroot "$ALPINE" /bin/sh -c 'id; if touch /var/cache/apk/_chroot_test 2>/dev/null; then echo CHROOT_WRITE_OK; rm -f /var/cache/apk/_chroot_test; else echo CHROOT_WRITE_FAIL; fi'
echo

echo "==================== chroot 内 SELinux 上下文 ===================="
chroot "$ALPINE" /bin/sh -c 'cat /proc/self/attr/current 2>/dev/null || echo "no attr"'
echo

echo "==================== 测试:临时 permissive 后能否写 ===================="
ORIG=$(getenforce)
echo "当前 SELinux: $ORIG"
setenforce 0 2>/dev/null && echo "已临时设 permissive" || echo "setenforce 失败"
chroot "$ALPINE" /bin/sh -c 'if touch /var/cache/apk/_p_test 2>/dev/null; then echo PERMISSIVE_WRITE_OK; rm -f /var/cache/apk/_p_test; else echo PERMISSIVE_WRITE_FAIL; fi'
# 恢复原状
if [ "$ORIG" = "Enforcing" ]; then setenforce 1 2>/dev/null && echo "已恢复 Enforcing"; fi
echo

echo "==================== 安全补丁 ===================="
getprop ro.build.version.security_patch
echo
echo "==================== 诊断完成 ===================="
