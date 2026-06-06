#!/system/bin/sh
# 纯查询：确认 chroot 内 lmxxf 的 uid 是否撞 Android system(uid 1000)。安卓 root 下跑。
# 不做任何杀进程操作，安全。
UBUNTU=/data/ubuntu
CENV="env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

mountpoint -q $UBUNTU 2>/dev/null || { echo "chroot 没挂，先 ubuntu-enter.sh"; }

echo "==================== chroot 内 lmxxf 的 uid ===================="
$CENV chroot $UBUNTU /bin/bash -c "id lmxxf" 2>/dev/null
LMXUID=$($CENV chroot $UBUNTU /bin/bash -c "id -u lmxxf" 2>/dev/null)
echo
echo "lmxxf uid = $LMXUID"
if [ "$LMXUID" = "1000" ]; then
    echo ">>> 危险：uid=1000 与 Android 的 system 用户相同！"
    echo ">>> 后果：宿主层 pkill -u 1000 / pkill -u lmxxf 会杀 Android system_server，手机重启。"
    echo ">>> 规则：只在 chroot 内 pkill；宿主层只用 readlink /proc/PID/root 精确判断后 kill PID。"
else
    echo ">>> uid 不是 1000，相对安全。"
fi
echo
echo "==================== 完成（本脚本无杀进程操作）===================="
