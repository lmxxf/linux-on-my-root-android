#!/system/bin/sh
# 检查 fcitx5 状态。在安卓 root 下跑（chroot 进 Ubuntu 查）。
UBUNTU=/data/ubuntu
CENV="env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root DISPLAY=:1 XDG_RUNTIME_DIR=/tmp/runtime-root"

echo "==================== fcitx5 进程 ===================="
$CENV chroot $UBUNTU /bin/bash -c "pgrep -a fcitx5 || echo '!!! fcitx5 没在跑'"
echo

echo "==================== Xvfb / xfce 进程 ===================="
$CENV chroot $UBUNTU /bin/bash -c "pgrep -a Xvfb || echo 'Xvfb 没跑'; pgrep -a xfwm4 || echo 'xfwm4 没跑'"
echo

echo "==================== 输入法环境变量 ===================="
$CENV chroot $UBUNTU /bin/bash -c "echo GTK_IM_MODULE=\$GTK_IM_MODULE; echo QT_IM_MODULE=\$QT_IM_MODULE; echo XMODIFIERS=\$XMODIFIERS"
echo

echo "==================== fcitx5 是否安装 ===================="
$CENV chroot $UBUNTU /bin/bash -c "which fcitx5 && fcitx5 --version 2>/dev/null | head -1"
echo

echo "==================== fcitx5 诊断（官方自检工具）===================="
$CENV chroot $UBUNTU /bin/bash -c "command -v fcitx5-diagnose >/dev/null && fcitx5-diagnose 2>/dev/null | grep -iE 'running|pinyin|im_module|not set|error' | head -20 || echo '无 fcitx5-diagnose'"
echo
echo "==================== 完成 ===================="
