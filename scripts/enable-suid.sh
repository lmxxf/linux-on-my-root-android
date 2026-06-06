#!/system/bin/sh
# 让 /data/ubuntu 支持 setuid（去掉 /data 继承的 nosuid），使 chroot 内 sudo/su 可用。须 root。
# 给已安装但 enter 脚本还没带 remount 的情况打补丁；新装的 ubuntu-enter.sh 已自动包含此逻辑。
# 用法: adb shell "su -c 'sh /data/local/tmp/enable-suid.sh'"
UBUNTU=/data/ubuntu

# 防重复堆叠：已是独立挂载点（含无 nosuid）就只 remount，不再叠 bind。
# 反复 mount --bind 会堆出几十层挂载，务必先判断。
if mountpoint -q "$UBUNTU" 2>/dev/null; then
    echo "[*] /data/ubuntu 已是独立挂载点，只 remount（不重复 bind）"
    mount -o remount,suid,dev,bind $UBUNTU 2>/dev/null
else
    echo "[*] 首次挂载：bind self + remount"
    mount --bind $UBUNTU $UBUNTU 2>/dev/null
    mount -o remount,suid,dev,bind $UBUNTU 2>/dev/null
fi

echo "[*] 当前 /data/ubuntu 挂载选项："
grep -E " $UBUNTU " /proc/mounts | sed 's/.*f2fs //; s/ 0 0//'

if grep -E " $UBUNTU " /proc/mounts | grep -q nosuid; then
    echo "[!] 仍含 nosuid，remount 未生效（该设备内核可能不允许）"
else
    echo "[*] nosuid 已去除，sudo 现在可用（需先 passwd 设密码）"
fi
