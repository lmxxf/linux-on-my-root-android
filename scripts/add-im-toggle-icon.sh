#!/bin/bash
# 在桌面放一个"中英切换"点击图标（调 fcitx5-remote -t）。在 Ubuntu chroot 内跑。
# 用法: bash /root/add-im-toggle-icon.sh [用户名]   默认 lmxxf
set -e
USERNAME="${1:-lmxxf}"
if [ "$USERNAME" = root ]; then HOMEDIR=/root; else HOMEDIR=/home/$USERNAME; fi
id "$USERNAME" >/dev/null 2>&1 || { echo "[!] 用户 $USERNAME 不存在"; exit 1; }

# 切换脚本（带提示当前状态）
mkdir -p "$HOMEDIR/.local/bin"
cat > "$HOMEDIR/.local/bin/im-toggle.sh" << 'TOGGLE'
#!/bin/bash
fcitx5-remote -t
s=$(fcitx5-remote)
case "$s" in
  2) msg="已切换：中文（拼音）" ;;
  1) msg="已切换：英文" ;;
  *) msg="fcitx5 未运行，正在启动..."; fcitx5 -d --replace 2>/dev/null ;;
esac
# 桌面通知（有 notify-send 就弹，没有就忽略）
command -v notify-send >/dev/null 2>&1 && notify-send -t 1000 "输入法" "$msg" || true
TOGGLE
chmod +x "$HOMEDIR/.local/bin/im-toggle.sh"

# 桌面图标
DESKTOP_DIR="$HOMEDIR/Desktop"
mkdir -p "$DESKTOP_DIR"
cat > "$DESKTOP_DIR/中英切换.desktop" << DESKTOP
[Desktop Entry]
Version=1.0
Type=Application
Name=中英切换
Comment=点击切换中文/英文输入（fcitx5）
Exec=$HOMEDIR/.local/bin/im-toggle.sh
Icon=input-keyboard
Terminal=false
Categories=Utility;
DESKTOP
chmod +x "$DESKTOP_DIR/中英切换.desktop"

# XFCE 桌面图标要标记为可信任才能双击直接运行
gio set "$DESKTOP_DIR/中英切换.desktop" metadata::xfce-exe-checksum "$(sha256sum "$DESKTOP_DIR/中英切换.desktop" | cut -d' ' -f1)" 2>/dev/null || true
gio set "$DESKTOP_DIR/中英切换.desktop" metadata::trusted true 2>/dev/null || true

chown -R "$USERNAME:$USERNAME" "$HOMEDIR/.local" "$DESKTOP_DIR" 2>/dev/null

echo "[*] 桌面已添加「中英切换」图标（用户 $USERNAME）"
echo "[*] 在 VNC 桌面双击它即可切换中/英"
echo "[*] 也可命令行切换：fcitx5-remote -t"
echo "[*] 首次双击若提示是否信任/执行，选「信任并启动」"
