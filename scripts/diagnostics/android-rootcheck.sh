#!/system/bin/sh
# Root-level capability check. MUST be run as root (su).
# Verifies the things chroot actually needs: mount, chroot, bind, proc/sys/dev.

echo "==================== AM I ROOT ===================="
id
echo

echo "==================== SELINUX (should not matter under su domain) ===================="
echo "[getenforce] $(getenforce)"
echo

echo "==================== MOUNT / BIND TEST ===================="
TESTDIR=/data/local/tmp/_mnt_test
SRC=/data/local/tmp/_mnt_src
mkdir -p "$TESTDIR" "$SRC"
echo "hello-from-bind" > "$SRC/marker"
if mount --bind "$SRC" "$TESTDIR" 2>&1; then
    if [ -f "$TESTDIR/marker" ]; then
        echo "[bind mount] OK -> $(cat $TESTDIR/marker)"
    else
        echo "[bind mount] mounted but marker missing"
    fi
    umount "$TESTDIR" 2>&1 && echo "[umount] OK"
else
    echo "[bind mount] FAILED"
fi
rm -rf "$TESTDIR" "$SRC"
echo

echo "==================== CHROOT TEST (mini busybox-free) ===================="
# Build a tiny chroot using the system's own /system/bin/sh statically? Not static.
# Instead just confirm chroot binary runs and can enter an existing dir with a shell.
# We point chroot at / with toybox sh just to confirm the syscall is permitted.
echo "[chroot self-test] running: chroot / /system/bin/sh -c 'echo INSIDE_CHROOT uid=\$(id -u)'"
chroot / /system/bin/sh -c 'echo INSIDE_CHROOT uid=$(id -u)' 2>&1
echo

echo "==================== PROC/SYS/DEV MOUNTABLE? ===================="
# These are what alpine-enter.sh binds. Test bind-mounting them into a scratch dir.
SCRATCH=/data/local/tmp/_chroot_scratch
mkdir -p "$SCRATCH/proc" "$SCRATCH/sys" "$SCRATCH/dev"
for fs in proc sys dev; do
    if mount --bind /$fs "$SCRATCH/$fs" 2>&1; then
        echo "[bind /$fs] OK"
        umount "$SCRATCH/$fs" 2>/dev/null
    else
        echo "[bind /$fs] FAILED"
    fi
done
rm -rf "$SCRATCH"
echo

echo "==================== /data/local/tmp EXEC (re-confirm as root) ===================="
T=/data/local/tmp/_x.sh
echo '#!/system/bin/sh' > "$T"
echo 'echo "  exec OK"' >> "$T"
chmod 755 "$T"
"$T" 2>&1 || echo "  exec FAILED $?"
rm -f "$T"
echo
echo "==================== DONE ===================="
