#!/system/bin/sh
# 检查 VNC + 桌面 + fcitx 整体状态。安卓 root 下跑。
UBUNTU=/data/ubuntu
USERNAME="${1:-lmxxf}"
CENV="env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

echo "==================== chroot 是否还挂着 ===================="
mountpoint -q $UBUNTU && echo "/data/ubuntu 挂着(chroot 在)" || echo "!!! /data/ubuntu 没挂(手机可能重启过,需重新 ubuntu-enter.sh)"
echo

echo "==================== 5900 端口监听 ===================="
$CENV chroot $UBUNTU /bin/bash -c "ss -tlnp 2>/dev/null | grep 5900 || echo '!!! 没有进程监听 5900'"
echo

echo "==================== 关键进程 ===================="
$CENV chroot $UBUNTU /bin/bash -c "
  echo -n 'Xvfb:   '; pgrep -a Xvfb || echo 无
  echo -n 'x11vnc: '; pgrep -a x11vnc || echo 无
  echo -n 'xfwm4:  '; pgrep -u $USERNAME -a xfwm4 || echo 无
  echo -n 'fcitx5: '; pgrep -u $USERNAME -a fcitx5 || echo 无
"
echo

echo "==================== $USERNAME fcitx5 profile 当前内容(看有没有 pinyin) ===================="
$CENV chroot $UBUNTU /bin/bash -c "grep -E 'DefaultIM|pinyin|Name=' /home/$USERNAME/.config/fcitx5/profile 2>/dev/null || echo '无 profile'"
echo
echo "==================== 完成 ===================="
