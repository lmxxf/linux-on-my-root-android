#!/system/bin/sh
# Android environment probe -- run inside adb shell. English-only output (Windows GBK safe).
# Tries hard to locate su / root. Prints what it can even without root.

echo "==================== BASIC ===================="
echo "[android]   $(getprop ro.build.version.release)  (SDK $(getprop ro.build.version.sdk))"
echo "[model]     $(getprop ro.product.model) / $(getprop ro.product.manufacturer)"
echo "[abi]       $(getprop ro.product.cpu.abi)"
echo "[uname]     $(uname -a)"
echo "[whoami]    $(id)"
echo

echo "==================== ROOT / SU LOOKUP ===================="
echo "[su in PATH]  $(command -v su 2>/dev/null || echo 'NOT in PATH')"
echo "[scan common su paths]"
for p in /system/bin/su /system/xbin/su /data/adb/ksu/bin/su /data/adb/ap/bin/su /debug_ramdisk/su /sbin/su; do
    if [ -e "$p" ]; then echo "    FOUND: $p"; else echo "    -     $p"; fi
done
echo "[KernelSU dir]  $([ -d /data/adb/ksu ] && echo 'YES /data/adb/ksu' || echo 'no')"
echo "[APatch dir]    $([ -d /data/adb/ap ]  && echo 'YES /data/adb/ap'  || echo 'no')"
echo "[Magisk dir]    $([ -d /data/adb/magisk ] && echo 'YES' || echo 'no')"
echo "[/data/adb ls]"
ls -la /data/adb 2>/dev/null | head -20 || echo "    cannot read /data/adb (no root yet)"
echo

echo "==================== SELINUX ===================="
echo "[getenforce]  $(getenforce 2>/dev/null || echo 'no getenforce cmd')"
echo "[selinuxfs]   $([ -e /sys/fs/selinux/enforce ] && cat /sys/fs/selinux/enforce 2>/dev/null || echo 'no selinuxfs / cannot read')"
echo

echo "==================== /data NOEXEC TEST (key!) ===================="
echo "[/data mount opts]"
grep -E ' /data ' /proc/mounts 2>/dev/null || mount 2>/dev/null | grep -E ' /data '
echo "[exec test in /data/local/tmp]"
T=/data/local/tmp/_exec_test.sh
echo '#!/system/bin/sh' > "$T" 2>/dev/null
echo 'echo "    -> EXECUTABLE (printed by the test script itself)"' >> "$T" 2>/dev/null
chmod 755 "$T" 2>/dev/null
"$T" 2>&1 || echo "    -> NOT executable (noexec or perm). exit=$?"
rm -f "$T"
echo

echo "==================== chroot TOOLS ===================="
echo "[chroot]    $(command -v chroot 2>/dev/null || echo 'no chroot cmd')"
echo "[busybox]   $(command -v busybox 2>/dev/null || echo 'no busybox')"
echo "[unshare]   $(command -v unshare 2>/dev/null || echo 'no unshare')"
echo "[mount cmd] $(command -v mount 2>/dev/null || echo 'no mount')"
echo

echo "==================== STORAGE ===================="
df -h /data 2>/dev/null || df /data 2>/dev/null
echo

echo "==================== NETWORK ===================="
echo "[dns]         $(getprop net.dns1) $(getprop net.dns2)"
echo "[resolv.conf] $(cat /etc/resolv.conf 2>/dev/null | tr '\n' ' ' || echo 'none')"
echo "[ping test]"
ping -c 2 dl-cdn.alpinelinux.org 2>&1 | tail -3 || echo "    ping failed"
echo
echo "==================== DONE: paste all output back ===================="
