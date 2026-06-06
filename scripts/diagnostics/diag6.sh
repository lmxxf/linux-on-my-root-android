#!/system/bin/sh
# 真凶是 HTTP 403/网络层,不是文件权限。测多个镜像源找能用的。须 root。
ALPINE=/data/alpine

mkdir -p $ALPINE/dev/pts $ALPINE/tmp
chmod 1777 $ALPINE/tmp
mountpoint -q $ALPINE/proc    || mount -t proc proc $ALPINE/proc
mountpoint -q $ALPINE/sys     || mount -t sysfs sysfs $ALPINE/sys
mountpoint -q $ALPINE/dev     || mount -o bind /dev $ALPINE/dev
mountpoint -q $ALPINE/dev/pts || mount -t devpts devpts $ALPINE/dev/pts
echo "nameserver 8.8.8.8" > $ALPINE/etc/resolv.conf

ENVCLEAN="env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin HOME=/root TERM=xterm"

# 候选源:清华、中科大、阿里、官方
test_repo() {
    name="$1"; url="$2"
    echo "---------- 测试源: $name ----------"
    echo "$url"
    $ENVCLEAN chroot "$ALPINE" /bin/sh -c "
        cd /tmp
        echo '  [wget 测 APKINDEX 返回码]:'
        wget -S -O /tmp/idx.tar.gz '$url/main/aarch64/APKINDEX.tar.gz' 2>&1 | grep -E 'HTTP/|返回|saved|100%' | head -3
        if [ -s /tmp/idx.tar.gz ]; then
            echo '  下载成功,大小:' \$(ls -la /tmp/idx.tar.gz | awk '{print \$5}' 2>/dev/null || wc -c < /tmp/idx.tar.gz)
        else
            echo '  下载失败或空文件'
        fi
        rm -f /tmp/idx.tar.gz
    "
    echo
}

echo "==================== 当前手机网络环境 ===================="
echo "[出口IP测试]"
$ENVCLEAN chroot "$ALPINE" /bin/sh -c "wget -q -O - http://ip.3322.net 2>/dev/null || wget -q -O - http://members.3322.org/dyndns/getip 2>/dev/null || echo '取IP失败'"
echo

test_repo "清华 TUNA"   "http://mirrors.tuna.tsinghua.edu.cn/alpine/v3.21"
test_repo "中科大 USTC"  "http://mirrors.ustc.edu.cn/alpine/v3.21"
test_repo "阿里云"       "http://mirrors.aliyun.com/alpine/v3.21"
test_repo "Alpine官方"   "http://dl-cdn.alpinelinux.org/alpine/v3.21"
test_repo "清华HTTPS"    "https://mirrors.tuna.tsinghua.edu.cn/alpine/v3.21"

echo "==================== 完成:看哪个源能下成功 ===================="
