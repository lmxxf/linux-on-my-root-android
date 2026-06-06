#!/bin/bash
# 在 Ubuntu chroot 内装 Firefox（Mozilla 官方 arm64 tarball，不走 snap）
# 用法（Ubuntu 内）: bash /root/install-firefox.sh
# 前置: firefox-aarch64.tar.xz 已放到 /root/ 下

set -e
info() { echo "[*] $1"; }

TARBALL=/root/firefox-aarch64.tar.xz
[ -f "$TARBALL" ] || { echo "[!] 未找到 $TARBALL，先 push 进来"; exit 1; }

export DEBIAN_FRONTEND=noninteractive

info "安装 Firefox 运行依赖库 ..."
apt-get update
# Firefox 运行需要的 GTK/X11/音视频库（Ubuntu base 默认没装全）
apt-get install -y --no-install-recommends \
    libgtk-3-0 libdbus-glib-1-2 libxt6 libx11-xcb1 libxcb1 \
    libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libgbm1 \
    libasound2t64 libpci3 libegl1 libgl1 \
    libxcb-shm0 libxcb-render0 fonts-noto-cjk xz-utils

info "解压 Firefox 到 /opt ..."
mkdir -p /opt
tar xJf "$TARBALL" -C /opt
[ -x /opt/firefox/firefox ] || { echo "[!] 解压后未找到 /opt/firefox/firefox"; exit 1; }

info "创建启动器 /usr/local/bin/firefox ..."
# chroot 里没有用户命名空间沙箱，必须关沙箱，否则启动崩
cat > /usr/local/bin/firefox << 'LAUNCHER'
#!/bin/bash
export MOZ_DISABLE_CONTENT_SANDBOX=1
export MOZ_DISABLE_GMP_SANDBOX=1
exec /opt/firefox/firefox --no-sandbox "$@"
LAUNCHER
chmod +x /usr/local/bin/firefox

# XFCE 应用菜单里的图标
info "创建桌面菜单项 ..."
mkdir -p /usr/share/applications
cat > /usr/share/applications/firefox.desktop << 'DESKTOP'
[Desktop Entry]
Name=Firefox
Comment=Web Browser
Exec=/usr/local/bin/firefox %u
Icon=/opt/firefox/browser/chrome/icons/default/default128.png
Terminal=false
Type=Application
Categories=Network;WebBrowser;
DESKTOP

info "========================================"
info "  Firefox 安装完成！"
info "  命令行启动:   firefox"
info "  桌面里:       应用菜单 -> Firefox"
info "  （chroot 环境已自动加 --no-sandbox）"
info "========================================"
