#!/system/bin/sh
# 检查普通用户的 fcitx5 状态。安卓 root 下跑。
UBUNTU=/data/ubuntu
USERNAME="${1:-lmxxf}"
CENV="env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

echo "==================== $USERNAME 的 fcitx5 进程 ===================="
$CENV chroot $UBUNTU /bin/bash -c "pgrep -u $USERNAME -a fcitx5 || echo '!!! $USERNAME 下没有 fcitx5 进程'"
echo

echo "==================== $USERNAME 的 fcitx5 profile ===================="
$CENV chroot $UBUNTU /bin/bash -c "cat /home/$USERNAME/.config/fcitx5/profile 2>/dev/null || echo '!!! 无 profile 文件'"
echo

echo "==================== $USERNAME 的 .xprofile ===================="
$CENV chroot $UBUNTU /bin/bash -c "cat /home/$USERNAME/.xprofile 2>/dev/null || echo '!!! 无 .xprofile'"
echo

echo "==================== $USERNAME 的 start-vnc.sh 是否含 fcitx5 ===================="
$CENV chroot $UBUNTU /bin/bash -c "grep -n fcitx5 /home/$USERNAME/start-vnc.sh 2>/dev/null || echo '!!! start-vnc.sh 里没有 fcitx5 启动'"
echo

echo "==================== fcitx5 是否安装 ===================="
$CENV chroot $UBUNTU /bin/bash -c "which fcitx5"
echo "==================== 完成 ===================="
