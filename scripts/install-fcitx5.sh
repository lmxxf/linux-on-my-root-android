#!/bin/bash
# 在 Ubuntu chroot 内装 fcitx5 中文输入法，并集成进 VNC 启动脚本
# 用法（Ubuntu 内）: bash /root/install-fcitx5.sh
set -e
info() { echo "[*] $1"; }

export DEBIAN_FRONTEND=noninteractive

info "更新软件源 ..."
apt-get update

info "安装 fcitx5 + 拼音引擎 ..."
apt-get install -y --no-install-recommends \
    fcitx5 fcitx5-chinese-addons fcitx5-config-qt \
    fcitx5-frontend-gtk3 fcitx5-frontend-qt5 \
    fonts-noto-cjk

# fcitx5 输入法 profile：默认启用键盘 + 拼音
info "配置 fcitx5 默认输入法（键盘 + 拼音）..."
mkdir -p /root/.config/fcitx5
cat > /root/.config/fcitx5/profile << 'PROFILE'
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

# 把输入法环境变量 + 自启动写进 start-vnc.sh（如果还没有）
info "集成输入法到 VNC 启动脚本 ..."
if ! grep -q "GTK_IM_MODULE=fcitx" /root/start-vnc.sh 2>/dev/null; then
    # 在 Xvfb 启动后、startxfce4 之前插入输入法环境和启动
    # 简单做法：重写一个集成版 start-vnc.sh
    cat > /root/start-vnc.sh << 'VNCSCRIPT'
#!/bin/bash
# 启动 VNC 桌面（含 fcitx5 中文输入法）。用法: bash /root/start-vnc.sh [分辨率]
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

Xvfb ${DISPLAY_NUM} -screen 0 ${RESOLUTION}x24 &
sleep 2
export DISPLAY=${DISPLAY_NUM}
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p $XDG_RUNTIME_DIR; chmod 700 $XDG_RUNTIME_DIR

# ── 中文输入法环境（关键，必须在桌面/应用启动前设）──
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export INPUT_METHOD=fcitx
export SDL_IM_MODULE=fcitx
export GLFW_IM_MODULE=ibus

# 启动 fcitx5 守护进程
fcitx5 -d --replace 2>/dev/null
sleep 1

# 启动 XFCE 桌面
dbus-launch --exit-with-session startxfce4 &
sleep 3
if ! pgrep -f xfwm4 >/dev/null 2>&1; then
    echo "[!] startxfce4 未起，退回最小桌面"
    xfwm4 &
    sleep 1
    xfce4-terminal &
fi
sleep 1

x11vnc -display ${DISPLAY_NUM} -forever -shared -rfbport ${VNC_PORT} -bg -nopw -noshm -xkb

echo "[*] VNC 已启动，分辨率 ${RESOLUTION}，端口 ${VNC_PORT}"
echo "[*] 中文输入：Ctrl+Space 切换中/英，候选框选字"
echo "[*] 停止: bash /root/stop-vnc.sh"
VNCSCRIPT
    chmod +x /root/start-vnc.sh
    echo "[*] start-vnc.sh 已更新（集成 fcitx5）"
else
    echo "[*] start-vnc.sh 已包含输入法配置，跳过"
fi

info "========================================"
info "  fcitx5 中文输入法安装完成！"
info ""
info "  重启 VNC 桌面使输入法生效："
info "    bash /root/stop-vnc.sh"
info "    bash /root/start-services.sh 1920x1080"
info ""
info "  使用：在任意输入框按 Ctrl+Space 切换中/英文"
info "  候选词：数字键选字，空格选第一个"
info ""
info "  如需调整：运行 fcitx5-config-qt（图形配置）"
info "========================================"
