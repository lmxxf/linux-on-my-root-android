#!/bin/bash
# 修复 fcitx5 环境变量没传到桌面会话的问题。在 Ubuntu chroot 内跑。
# 用法: bash /root/fix-fcitx-env.sh
set -e
info() { echo "[*] $1"; }

# 1) 全局环境变量：写进 /etc/environment（所有进程继承，最可靠）
info "写入 /etc/environment ..."
# 先删掉可能存在的旧的错误值（fcitx5）
sed -i '/_IM_MODULE/d; /XMODIFIERS/d; /INPUT_METHOD/d' /etc/environment 2>/dev/null || true
cat >> /etc/environment << 'EOF'
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
INPUT_METHOD=fcitx
SDL_IM_MODULE=fcitx
EOF

# 2) ~/.xprofile（X 会话启动时读取）
info "写入 /root/.xprofile ..."
cat > /root/.xprofile << 'EOF'
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export INPUT_METHOD=fcitx
export SDL_IM_MODULE=fcitx
EOF

# 3) 重写 start-vnc.sh，确保用正确的值 fcitx（不是 fcitx5），
#    并且在 startxfce4 之前 export，让会话继承
info "重写 start-vnc.sh（修正 IM module 值为 fcitx）..."
cat > /root/start-vnc.sh << 'VNCSCRIPT'
#!/bin/bash
RESOLUTION=${1:-1920x1080}
DISPLAY_NUM=:1
VNC_PORT=5900

pkill -f "Xvfb ${DISPLAY_NUM}" 2>/dev/null
pkill -f "x11vnc.*${DISPLAY_NUM}" 2>/dev/null
pkill -f xfwm4 2>/dev/null
pkill -f xfce4 2>/dev/null
pkill -f fcitx5 2>/dev/null
sleep 1

mkdir -p /run/dbus
[ -e /run/dbus/pid ] || dbus-daemon --system --fork 2>/dev/null

# ── 中文输入法环境（正确值是 fcitx，不是 fcitx5）──
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export INPUT_METHOD=fcitx
export SDL_IM_MODULE=fcitx

Xvfb ${DISPLAY_NUM} -screen 0 ${RESOLUTION}x24 &
sleep 2
export DISPLAY=${DISPLAY_NUM}
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p $XDG_RUNTIME_DIR; chmod 700 $XDG_RUNTIME_DIR

# 启动 XFCE（会继承上面 export 的输入法变量）
dbus-launch --exit-with-session startxfce4 &
sleep 3
if ! pgrep -f xfwm4 >/dev/null 2>&1; then
    echo "[!] startxfce4 未起，退回最小桌面"
    xfwm4 &
    sleep 1
    xfce4-terminal &
fi
sleep 1

# fcitx5 守护进程（在桌面起来后，确保 attach 到会话）
fcitx5 -d --replace 2>/dev/null
sleep 1

x11vnc -display ${DISPLAY_NUM} -forever -shared -rfbport ${VNC_PORT} -bg -nopw -noshm -xkb

echo "[*] VNC 已启动，分辨率 ${RESOLUTION}，端口 ${VNC_PORT}"
echo "[*] 中文输入：Ctrl+Space 切换。手机 RealVNC 用扩展键盘点 Ctrl 再点空格"
echo "[*] 停止: bash /root/stop-vnc.sh"
VNCSCRIPT
chmod +x /root/start-vnc.sh

info "========================================"
info "  环境变量已修复（GTK/QT_IM_MODULE=fcitx）"
info "  重启桌面生效："
info "    bash /root/stop-vnc.sh"
info "    bash /root/start-services.sh 1920x1080"
info "  然后手机重连，按 Ctrl+Space 切中文"
info "========================================"
