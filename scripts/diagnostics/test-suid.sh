#!/system/bin/sh
# 测试能否让 chroot 内支持 suid（绕过 /data 的 nosuid），让 sudo 能用。须 root。
UBUNTU=/data/ubuntu

echo "==================== /data 挂载选项 ===================="
grep -E ' /data ' /proc/mounts
echo

echo "==================== 尝试 A: bind /data/ubuntu 到自身并 remount 去掉 nosuid ===================="
# 先 bind mount 根到自身（建立独立挂载点），再 remount 加 suid
mount --bind "$UBUNTU" "$UBUNTU" 2>&1 && echo "bind self OK" || echo "bind self FAIL"
mount -o remount,suid,dev,bind "$UBUNTU" 2>&1 && echo "remount suid OK" || echo "remount suid FAIL"
echo "[重看挂载]"
grep -E " $UBUNTU " /proc/mounts || echo "(无独立挂载点)"
echo

echo "==================== 验证 chroot 内 sudo 能否提权 ===================="
CENV="env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root"
mountpoint -q $UBUNTU/proc || mount -t proc proc $UBUNTU/proc
mountpoint -q $UBUNTU/dev  || mount -o bind /dev $UBUNTU/dev
$CENV chroot "$UBUNTU" /bin/bash -c "ls -l /usr/bin/sudo | head -1; su - lmxxf -c 'sudo -n true 2>&1 && echo SUDO_OK || echo SUDO_FAIL' 2>&1" 2>&1
echo

echo "==================== 还原（撤销自身 bind，避免重复挂载堆积）===================="
umount "$UBUNTU" 2>/dev/null && echo "已撤销 self-bind（如有）" || echo "无需撤销"
echo "==================== 完成 ===================="
