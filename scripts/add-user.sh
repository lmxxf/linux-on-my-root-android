#!/bin/bash
# 在 Ubuntu chroot 内创建普通用户，配 sudo + 输入法，并把 VNC 桌面切到该用户运行。
# 用法（Ubuntu chroot 内）: bash /root/add-user.sh [用户名]
#   不传用户名默认 lmxxf
set -e
info() { echo "[*] $1"; }

USERNAME="${1:-lmxxf}"

# ── 1. 建用户 ──
if id "$USERNAME" >/dev/null 2>&1; then
    info "用户 $USERNAME 已存在，跳过创建"
else
    info "创建用户 $USERNAME ..."
    # 非交互建用户（不问全名等信息），登录 shell 用 bash
    adduser --disabled-password --gecos "" --shell /bin/bash "$USERNAME"
fi

# ── 2. sudo 权限 ──
info "加入 sudo 组 ..."
usermod -aG sudo "$USERNAME"
# 确保 sudo 已装（base 可能没装）
command -v sudo >/dev/null 2>&1 || { apt-get update && apt-get install -y sudo; }

# ── 3. 输入法环境（用户级 .xprofile）──
info "配置 $USERNAME 的中文输入法环境 ..."
HOMEDIR="/home/$USERNAME"
cat > "$HOMEDIR/.xprofile" << 'EOF'
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export INPUT_METHOD=fcitx
export SDL_IM_MODULE=fcitx
EOF
chown "$USERNAME:$USERNAME" "$HOMEDIR/.xprofile"

# ── 4. 重写 start-services.sh：VNC 桌面以该用户身份运行 ──
info "更新 start-services.sh，桌面将以 $USERNAME 身份运行 ..."
cat > /root/start-services.sh << STARTALL
#!/bin/bash
# 一键启动 SSH(2222) + VNC 桌面（桌面以用户 $USERNAME 运行）
# SSH 用账户密码登录（lmxxf 或 root 都行），桌面默认 $USERNAME

echo "[*] 启动 SSH（端口 2222）..."
mkdir -p /run/sshd
[ -f /etc/ssh/ssh_host_ed25519_key ] || ssh-keygen -A >/dev/null 2>&1
pgrep -x sshd >/dev/null 2>&1 || /usr/sbin/sshd -p 2222

echo "[*] 启动 VNC 桌面（用户 $USERNAME）..."
# 切到该用户跑 VNC（-l 加载用户环境，含 .xprofile）
su - $USERNAME -c "bash /home/$USERNAME/start-vnc.sh \$1" -- "\${1:-1920x1080}"
STARTALL
chmod +x /root/start-services.sh

# ── 5. 给该用户一份 start-vnc.sh（用户级，跑在自己的 runtime dir）──
info "生成 $USERNAME 的 start-vnc.sh ..."
cat > "$HOMEDIR/start-vnc.sh" << VNCSCRIPT
#!/bin/bash
RESOLUTION=\${1:-1920x1080}
DISPLAY_NUM=:1
VNC_PORT=5900

pkill -u $USERNAME -f "Xvfb \${DISPLAY_NUM}" 2>/dev/null
pkill -u $USERNAME -f "x11vnc.*\${DISPLAY_NUM}" 2>/dev/null
pkill -u $USERNAME -f xfwm4 2>/dev/null
pkill -u $USERNAME -f fcitx5 2>/dev/null
sleep 1

mkdir -p /run/dbus
[ -e /run/dbus/pid ] || dbus-daemon --system --fork 2>/dev/null

export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export INPUT_METHOD=fcitx
export SDL_IM_MODULE=fcitx

Xvfb \${DISPLAY_NUM} -screen 0 \${RESOLUTION}x24 &
sleep 2
export DISPLAY=\${DISPLAY_NUM}
export XDG_RUNTIME_DIR=/tmp/runtime-$USERNAME
mkdir -p \$XDG_RUNTIME_DIR; chmod 700 \$XDG_RUNTIME_DIR

fcitx5 -d --replace 2>/dev/null
sleep 1

dbus-launch --exit-with-session startxfce4 &
sleep 3
if ! pgrep -u $USERNAME -f xfwm4 >/dev/null 2>&1; then
    echo "[!] startxfce4 未起，退回最小桌面"
    xfwm4 &
    sleep 1
    xfce4-terminal &
fi
sleep 1

x11vnc -display \${DISPLAY_NUM} -forever -shared -rfbport \${VNC_PORT} -bg -nopw -noshm -xkb

echo "[*] VNC 已启动（用户 $USERNAME），分辨率 \${RESOLUTION}，端口 \${VNC_PORT}"
echo "[*] 中文输入：Ctrl+Space"
VNCSCRIPT
chown "$USERNAME:$USERNAME" "$HOMEDIR/start-vnc.sh"
chmod +x "$HOMEDIR/start-vnc.sh"

info "========================================"
info "  用户 $USERNAME 创建完成！"
info ""
info "  设置密码（必须，SSH/sudo 登录用）："
info "    passwd $USERNAME"
info ""
info "  重启桌面（以 $USERNAME 身份运行）："
info "    bash /root/stop-vnc.sh 2>/dev/null; pkill -u $USERNAME Xvfb 2>/dev/null"
info "    bash /root/start-services.sh 1920x1080"
info ""
info "  之后：SSH 用 $USERNAME 登录，桌面也是 $USERNAME，要 root 用 sudo"
info "========================================"
