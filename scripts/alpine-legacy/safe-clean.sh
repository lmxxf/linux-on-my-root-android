#!/system/bin/sh
# 安全清理:先卸载所有挂载点,再删 /data/alpine。须 root。
# 直接 rm -rf /data/alpine 会顺着 bind mount 删到宿主 /sys /dev——绝对禁止。

ALPINE=/data/alpine

echo "==================== 当前挂载点 ===================="
grep "$ALPINE" /proc/mounts || echo "(无 alpine 相关挂载)"
echo

echo "==================== 卸载(从最深的先卸) ===================="
# devpts 在 dev 里面,必须先卸;顺序很重要
umount "$ALPINE/dev/pts" 2>&1 && echo "umount dev/pts OK" || echo "dev/pts: $?(可能本就没挂)"
umount "$ALPINE/dev"     2>&1 && echo "umount dev OK"     || echo "dev: $?"
umount "$ALPINE/proc"    2>&1 && echo "umount proc OK"    || echo "proc: $?"
umount "$ALPINE/sys"     2>&1 && echo "umount sys OK"     || echo "sys: $?"

# 兜底:如果还有残留挂载,强制 lazy umount
for m in $(grep "$ALPINE" /proc/mounts | cut -d' ' -f2 | sort -r); do
    echo "残留挂载 $m,强制 lazy umount"
    umount -l "$m" 2>&1
done
echo

echo "==================== 确认已无挂载 ===================="
if grep -q "$ALPINE" /proc/mounts; then
    echo "!!! 仍有挂载残留,禁止删除,请贴回输出:"
    grep "$ALPINE" /proc/mounts
    exit 1
else
    echo "已无挂载,可以安全删除"
fi
echo

echo "==================== 删除 /data/alpine ===================="
rm -rf "$ALPINE" 2>&1
if [ -d "$ALPINE" ]; then
    echo "删除后仍存在(可能有残留),ls:"
    ls -la "$ALPINE"
else
    echo "已彻底删除 /data/alpine"
fi
echo
echo "==================== 完成 ===================="
