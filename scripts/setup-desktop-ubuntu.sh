#!/bin/bash
#
# Ubuntu on Android — XFCE4 桌面 + VNC 部署（在 Ubuntu chroot 内执行）
#
# 用法（先进 Ubuntu）:
#   adb shell -> su -> sh /data/local/tmp/ubuntu-enter.sh
#   然后在 Ubuntu 内: bash /data/local/tmp/setup-desktop-ubuntu.sh
#
# 安装：XFCE4 桌面 + Xvfb + x11vnc + 中文字体 + Firefox
# 输入法策略：Linux 端【不装】fcitx/ibus，中文靠 VNC 客户端传 Windows 本地输入法的字符。
#

info() { echo "[*] $1"; }
err()  { echo "[!] $1" >&2; exit 1; }

[ -f /etc/os-release ] && grep -q Ubuntu /etc/os-release || err "请先进入 Ubuntu chroot 环境"
info "$(grep PRETTY_NAME /etc/os-release | cut -d'\"' -f2) 检测到"

export DEBIAN_FRONTEND=noninteractive

info "更新软件源索引 ..."
apt-get update || err "apt update 失败，检查网络（挂 VPN 时确认能访问 ports.ubuntu.com）"

# XFCE4 桌面 + VNC 栈 + 中文字体 + 浏览器
# dbus-x11: chroot 下 D-Bus 需要;
# xfonts-base: 基础字体; fonts-noto-cjk: 中文显示
PACKAGES="xfce4 xfce4-terminal xfwm4 dbus-x11 xvfb x11vnc \
fonts-noto-cjk fonts-noto-cjk-extra xfonts-base \
firefox-esr dconf-cli x11-xserver-utils"

info "安装桌面软件包（较大，约几百 MB，挂 VPN 走官方源）..."
apt-get install -y --no-install-recommends $PACKAGES || {
    # firefox-esr 在 ports 可能没有，退回不装浏览器，其余照装
    echo "[!] 完整包失败，尝试去掉 firefox 重装..."
    PACKAGES_NOFF="xfce4 xfce4-terminal xfwm4 dbus-x11 xvfb x11vnc fonts-noto-cjk fonts-noto-cjk-extra xfonts-base dconf-cli x11-xserver-utils"
    apt-get install -y --no-install-recommends $PACKAGES_NOFF || err "桌面软件包安装失败"
}

# ── VNC 启动脚本 ──
info "生成 VNC 启动脚本 /root/start-vnc.sh ..."
mkdir -p /root/.vnc
cat > /root/start-vnc.sh << 'VNCSCRIPT'
#!/bin/bash
# 启动 VNC 桌面。用法: bash /root/start-vnc.sh [分辨率]
RESOLUTION=${1:-1920x1080}
DISPLAY_NUM=:1
VNC_PORT=5900

# 清理旧进程
pkill -f "Xvfb ${DISPLAY_NUM}" 2>/dev/null
pkill -f "x11vnc.*${DISPLAY_NUM}" 2>/dev/null
pkill -f xfwm4 2>/dev/null
pkill -f xfce4 2>/dev/null
sleep 1

# D-Bus（XFCE 需要）
mkdir -p /run/dbus
[ -e /run/dbus/pid ] || dbus-daemon --system --fork 2>/dev/null

# 虚拟显示
Xvfb ${DISPLAY_NUM} -screen 0 ${RESOLUTION}x24 &
sleep 2
export DISPLAY=${DISPLAY_NUM}
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p $XDG_RUNTIME_DIR; chmod 700 $XDG_RUNTIME_DIR

# 启动完整 XFCE 会话（chroot 下用 startxfce4，失败退回 xfwm4+终端）
dbus-launch --exit-with-session startxfce4 &
sleep 3
if ! pgrep -f xfwm4 >/dev/null 2>&1; then
    echo "[!] startxfce4 未起，退回最小桌面"
    xfwm4 &
    sleep 1
    xfce4-terminal &
fi
sleep 1

# x11vnc：-nopw 无密码（端口转发后只本机可达，安全）
# 不传 -rfbauth，局域网外不暴露
x11vnc -display ${DISPLAY_NUM} -forever -shared -rfbport ${VNC_PORT} -bg -nopw -noshm -xkb

echo "[*] VNC 已启动，分辨率 ${RESOLUTION}，端口 ${VNC_PORT}"
echo "[*] PC 端: adb forward tcp:5900 tcp:5900，VNC 客户端连 127.0.0.1:5900"
echo "[*] 停止: bash /root/stop-vnc.sh"
VNCSCRIPT
chmod +x /root/start-vnc.sh

# ── 停止脚本 ──
cat > /root/stop-vnc.sh << 'STOPSCRIPT'
#!/bin/bash
pkill -f x11vnc 2>/dev/null
pkill -f xfce4 2>/dev/null
pkill -f xfwm4 2>/dev/null
pkill -f Xvfb 2>/dev/null
echo "[*] VNC 已停止"
STOPSCRIPT
chmod +x /root/stop-vnc.sh

# ── 一键启动 SSH + VNC ──
cat > /root/start-services.sh << 'STARTALL'
#!/bin/bash
# 一键启动 SSH(2222) + VNC 桌面
echo "[*] 启动 SSH（端口 2222）..."
mkdir -p /run/sshd
[ -f /etc/ssh/ssh_host_ed25519_key ] || ssh-keygen -A >/dev/null 2>&1
pgrep -x sshd >/dev/null 2>&1 || /usr/sbin/sshd -p 2222
echo "[*] 启动 VNC 桌面 ..."
bash /root/start-vnc.sh "$@"
STARTALL
chmod +x /root/start-services.sh

info "========================================"
info "  桌面部署完成！"
info ""
info "  设置 root 密码（SSH 登录用）: passwd"
info ""
info "  一键启动 SSH + VNC 桌面:"
info "    bash /root/start-services.sh 1920x1080"
info ""
info "  PC 端口转发（PowerShell）:"
info "    adb forward tcp:2222 tcp:2222   # SSH"
info "    adb forward tcp:5900 tcp:5900   # VNC"
info ""
info "  VNC 客户端连 127.0.0.1:5900"
info "  SSH: ssh root@127.0.0.1 -p 2222"
info ""
info "  中文输入：用 Windows 本地输入法打字，VNC 客户端传字符进 Linux"
info "  （TigerVNC/RealVNC 客户端默认支持，无需在 Linux 装输入法）"
info "========================================"
