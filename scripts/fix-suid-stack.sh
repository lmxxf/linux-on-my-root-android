#!/system/bin/sh
# 清理堆叠的 self-bind 挂载，并正确地重新挂一次。须 root。
# 背景：enable-suid 被重复跑导致 /data/ubuntu 上叠了多层 bind 挂载。
UBUNTU=/data/ubuntu

echo "==================== 退出前提醒 ===================="
echo "确保所有 chroot 会话已退出（没有 shell 还在 /data/ubuntu 里）。"
echo

echo "==================== 先卸载 chroot 子挂载 ===================="
umount "$UBUNTU/dev/pts" 2>/dev/null && echo "dev/pts 卸载"
umount "$UBUNTU/dev"     2>/dev/null && echo "dev 卸载"
umount "$UBUNTU/proc"    2>/dev/null && echo "proc 卸载"
umount "$UBUNTU/sys"     2>/dev/null && echo "sys 卸载"
echo

echo "==================== 卸载所有堆叠的 self-bind（循环到干净）===================="
n=0
while mountpoint -q "$UBUNTU" 2>/dev/null || grep -q " $UBUNTU " /proc/mounts 2>/dev/null; do
    umount "$UBUNTU" 2>/dev/null || umount -l "$UBUNTU" 2>/dev/null || break
    n=$((n+1))
    if [ $n -gt 50 ]; then echo "[!] 卸了 50 层还没干净，停止"; break; fi
done
echo "共卸载 $n 层 self-bind"
echo

echo "==================== 确认 /data/ubuntu 已无独立挂载 ===================="
if grep -q " $UBUNTU " /proc/mounts 2>/dev/null; then
    echo "[!] 仍有残留："
    grep " $UBUNTU " /proc/mounts
else
    echo "干净，/data/ubuntu 现在跟随 /data（带 nosuid）"
fi
echo

echo "==================== 重新挂一次（bind + remount 去 nosuid）===================="
mount --bind "$UBUNTU" "$UBUNTU"
mount -o remount,suid,dev,bind "$UBUNTU"
echo "[*] 当前挂载选项（应只有一行，不含 nosuid）："
grep -E " $UBUNTU " /proc/mounts | sed 's/.* f2fs //; s/ 0 0//'
echo

if grep -E " $UBUNTU " /proc/mounts | grep -q nosuid; then
    echo "[!] 仍含 nosuid"
else
    echo "[*] nosuid 已去除。现在重新进 chroot，sudo 即可用。"
fi
echo "==================== 完成 ===================="
