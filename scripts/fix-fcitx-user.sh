#!/bin/bash
# 给普通用户补全 fcitx5 配置（profile + 环境 + 自启）。在 Ubuntu chroot 内跑。
# 用法: bash /root/fix-fcitx-user.sh [用户名]   默认 lmxxf
set -e
info() { echo "[*] $1"; }

USERNAME="${1:-lmxxf}"
HOMEDIR="/home/$USERNAME"
id "$USERNAME" >/dev/null 2>&1 || { echo "[!] 用户 $USERNAME 不存在"; exit 1; }

# 1) fcitx5 profile（默认启用键盘 + 拼音）—— 之前只给了 root，没给普通用户
info "写 $USERNAME 的 fcitx5 profile ..."
mkdir -p "$HOMEDIR/.config/fcitx5"
cat > "$HOMEDIR/.config/fcitx5/profile" << 'PROFILE'
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=pinyin

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=pinyin
Layout=

[GroupOrder]
0=Default
PROFILE

# 2) .xprofile 环境变量（确保存在且正确）
info "写 $USERNAME 的 .xprofile ..."
cat > "$HOMEDIR/.xprofile" << 'EOF'
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export INPUT_METHOD=fcitx
export SDL_IM_MODULE=fcitx
EOF

# 3) 用户的 start-vnc.sh 里确保启动 fcitx5（以该用户身份）
info "检查 $USERNAME 的 start-vnc.sh 是否拉起 fcitx5 ..."
VNCSH="$HOMEDIR/start-vnc.sh"
if [ -f "$VNCSH" ] && ! grep -q "fcitx5 -d" "$VNCSH"; then
    # 在 export DISPLAY 之后插入 fcitx5 启动（简单起见在 Xvfb 段后追加重启逻辑由用户脚本已有则跳过）
    info "  start-vnc.sh 缺 fcitx5 启动，补上"
    sed -i '/export DISPLAY=/a fcitx5 -d --replace 2>/dev/null; sleep 1' "$VNCSH"
fi

# 4) 全部归属该用户
chown -R "$USERNAME:$USERNAME" "$HOMEDIR/.config" "$HOMEDIR/.xprofile" 2>/dev/null

info "========================================"
info "  $USERNAME 的 fcitx5 配置已补全"
info "  重启桌面生效（在 root 下）："
info "    pkill -f 'Xvfb :1' 2>/dev/null; bash /root/stop-vnc.sh 2>/dev/null"
info "    bash /root/start-services.sh 1920x1080"
info "  然后 VNC 重连，Ctrl+Space 切中文"
info "========================================"
