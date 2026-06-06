#!/system/bin/sh
# 安全清理 Ubuntu:先卸载所有挂载点,再删 /data/ubuntu。须 root。
# 直接 rm -rf 会顺着 bind mount 删到宿主 /sys /dev——绝对禁止。
UBUNTU=/data/ubuntu

echo "==================== 当前挂载点 ===================="
grep "$UBUNTU" /proc/mounts || echo "(无 ubuntu 相关挂载)"
echo

echo "==================== 卸载(从最深的先卸) ===================="
umount "$UBUNTU/dev/pts" 2>&1 && echo "umount dev/pts OK" || echo "dev/pts: 跳过"
umount "$UBUNTU/dev"     2>&1 && echo "umount dev OK"     || echo "dev: 跳过"
umount "$UBUNTU/proc"    2>&1 && echo "umount proc OK"    || echo "proc: 跳过"
umount "$UBUNTU/sys"     2>&1 && echo "umount sys OK"     || echo "sys: 跳过"

for m in $(grep "$UBUNTU" /proc/mounts | cut -d' ' -f2 | sort -r); do
    echo "残留挂载 $m,强制 lazy umount"
    umount -l "$m" 2>&1
done
echo

echo "==================== 确认已无挂载 ===================="
if grep -q "$UBUNTU" /proc/mounts; then
    echo "!!! 仍有挂载残留,禁止删除:"
    grep "$UBUNTU" /proc/mounts
    exit 1
else
    echo "已无挂载,可以安全删除"
fi
echo

echo "==================== 删除 /data/ubuntu ===================="
rm -rf "$UBUNTU" 2>&1
[ -d "$UBUNTU" ] && { echo "仍存在:"; ls -la "$UBUNTU"; } || echo "已彻底删除 /data/ubuntu"
echo "==================== 完成 ===================="
