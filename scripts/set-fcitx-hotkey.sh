#!/bin/bash
# 显式设置 fcitx5 中英切换键（写 config 文件）。在 Ubuntu chroot 内跑。
# 用法: bash /root/set-fcitx-hotkey.sh [用户名]   默认 lmxxf
# 设两个触发键：Ctrl+Space 和 左Shift（单键，手机 VNC 好发）
set -e
USERNAME="${1:-lmxxf}"
if [ "$USERNAME" = root ]; then HOMEDIR=/root; else HOMEDIR=/home/$USERNAME; fi
id "$USERNAME" >/dev/null 2>&1 || { echo "[!] 用户 $USERNAME 不存在"; exit 1; }

# 改 config 前必须停 fcitx5，否则运行中的 fcitx5 会回写覆盖。
# 用 -f 按命令行匹配，不用 -u <uid>（chroot 不隔离 PID，pkill -u 会误伤宿主同 uid 进程）。
pkill -f "fcitx5 -d" 2>/dev/null || true
sleep 1

mkdir -p "$HOMEDIR/.config/fcitx5"
cat > "$HOMEDIR/.config/fcitx5/config" << 'CONFIG'
[Hotkey]
# 切换启用/未启用输入法（中英切换）
TriggerKeys=
TriggerKeys[0]=Control+space
TriggerKeys[1]=Shift_L
# 关闭"按 Shift 仅当单独按下才触发"的额外限制（让单 Shift 直接生效）
EnumerateWithTriggerKeys=True
# 在输入法之间枚举切换
EnumerateForwardKeys=
EnumerateForwardKeys[0]=Control+space
EnumerateBackwardKeys=
EnumerateBackwardKeys[0]=Control+Shift+space

[Hotkey/AltTriggerKeys]
0=Shift_L

[Behavior]
# 默认输入状态：激活（直接能打中文）
ShareInputState=All
CONFIG

chown -R "$USERNAME:$USERNAME" "$HOMEDIR/.config"

echo "[*] $USERNAME 的 fcitx5 切换键已设："
echo "    - Ctrl+Space"
echo "    - 左 Shift（单键，手机 VNC 推荐用这个）"
echo "[*] 重启桌面后生效（在 root 下）："
echo "    pkill -f 'Xvfb :1' 2>/dev/null; bash /root/start-services.sh 1920x1080"
echo "[*] 或直接命令切换：fcitx5-remote -t"
