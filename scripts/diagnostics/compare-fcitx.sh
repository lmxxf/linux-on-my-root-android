#!/system/bin/sh
# 对比 root 和 lmxxf 的 fcitx5 配置，找出为啥 root 能切 lmxxf 不能。安卓 root 下跑。
UBUNTU=/data/ubuntu
CENV="env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

for U in root lmxxf; do
    if [ "$U" = root ]; then DIR=/root; else DIR=/home/$U; fi
    echo "==================== [$U] profile（输入法组）===================="
    $CENV chroot $UBUNTU /bin/bash -c "cat $DIR/.config/fcitx5/profile 2>/dev/null || echo '无 profile'"
    echo
    echo "==================== [$U] config（切换键等全局设置）===================="
    $CENV chroot $UBUNTU /bin/bash -c "cat $DIR/.config/fcitx5/config 2>/dev/null || echo '无 config（用默认）'"
    echo
    echo "========================================================="
    echo
done
echo "完成"
