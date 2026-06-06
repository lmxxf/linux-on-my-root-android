# Linux on (rooted) Android — 一键部署脚本（Windows PowerShell）
#
# 在已 root（KernelSU/Magisk/APatch）的 Android 设备上，通过 chroot 部署完整 Ubuntu 24.04 桌面。
#
# 前置：
#   1. Android 已 root，adb 已授予 root（KernelSU 里给 shell 授权）
#   2. PC 装好 adb，USB 连上手机，`adb devices` 能看到设备
#   3. 下载好 Ubuntu base rootfs 和 Firefox tarball（放本脚本同目录）：
#      - ubuntu-base-24.04-arm64.tar.gz  （见 README“准备文件”）
#      - firefox-aarch64.tar.xz          （可选，不装浏览器可跳过）
#
# 用法：
#   cd 到本脚本所在目录
#   powershell -ExecutionPolicy Bypass -File .\deploy.ps1
#
# 可选参数：
#   -SkipDesktop   只装命令行 Ubuntu，不装 XFCE 桌面
#   -SkipFirefox   不装 Firefox
#   -SkipFcitx     不装中文输入法
#   -Resolution    VNC 分辨率，默认 1920x1080

param(
    [switch]$SkipDesktop,
    [switch]$SkipFirefox,
    [switch]$SkipFcitx,
    [string]$Resolution = "1920x1080"
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$S = Join-Path $scriptDir "scripts"

function Info($m)  { Write-Host "[*] $m" -ForegroundColor Cyan }
function Warn($m)  { Write-Host "[!] $m" -ForegroundColor Yellow }
function Die($m)   { Write-Host "[x] $m" -ForegroundColor Red; exit 1 }

# push 文件到 /data/local/tmp，再 su cp 进 Ubuntu 的 /root（adb 无 root，不能直接写 /data/ubuntu）
function PushToUbuntuRoot($localPath, $name) {
    adb push $localPath "/data/local/tmp/$name" | Out-Null
    adb shell "su -c 'cp /data/local/tmp/$name /data/ubuntu/root/'" | Out-Null
}

# 在 Ubuntu chroot 内执行一个脚本（脚本须已在 /data/ubuntu/root/）
function RunInUbuntu($scriptName) {
    adb shell "su -c 'sh /data/local/tmp/ubuntu-enter-batch.sh /root/$scriptName'"
}

# ── 0. 环境检查 ──
Info "检查 adb 设备 ..."
$dev = (adb devices) | Select-String -Pattern "device$"
if (-not $dev) { Die "adb 没看到已授权设备。检查 USB 调试 + 授权弹窗。" }

Info "检查 root ..."
$rootCheck = (adb shell "su -c id") 2>&1
if ($rootCheck -notmatch "uid=0") {
    Die "su 拿不到 root（返回: $rootCheck）。在 KernelSU app 里给 shell 授权后重试。"
}

# 检查必需文件
$rootfs = Join-Path $scriptDir "ubuntu-base-24.04-arm64.tar.gz"
if (-not (Test-Path $rootfs)) {
    Die "缺少 rootfs: ubuntu-base-24.04-arm64.tar.gz`n    下载见 README“准备文件”一节。"
}

# ── 1. 推送脚本 ──
Info "推送安装脚本到设备 ..."
adb push (Join-Path $S "install-ubuntu.sh")       /data/local/tmp/install-ubuntu.sh       | Out-Null
adb push (Join-Path $S "safe-clean-ubuntu.sh")    /data/local/tmp/safe-clean-ubuntu.sh    | Out-Null

# 批处理版 enter 脚本：进 chroot 跑指定脚本后退出（非交互）
$batchEnter = @'
#!/system/bin/sh
UBUNTU=/data/ubuntu
mkdir -p $UBUNTU/dev/pts
mountpoint -q $UBUNTU/proc    || mount -t proc proc $UBUNTU/proc
mountpoint -q $UBUNTU/sys     || mount -t sysfs sysfs $UBUNTU/sys
mountpoint -q $UBUNTU/dev     || mount -o bind /dev $UBUNTU/dev
mountpoint -q $UBUNTU/dev/pts || mount -t devpts devpts $UBUNTU/dev/pts
echo "nameserver 8.8.8.8" > $UBUNTU/etc/resolv.conf
CENV="env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root TERM=xterm-256color LANG=C.UTF-8 DEBIAN_FRONTEND=noninteractive"
$CENV chroot $UBUNTU /bin/bash "$1"
'@
$batchEnterPath = Join-Path $env:TEMP "ubuntu-enter-batch.sh"
$batchEnter -replace "`r`n","`n" | Set-Content -NoNewline -Path $batchEnterPath -Encoding ASCII
adb push $batchEnterPath /data/local/tmp/ubuntu-enter-batch.sh | Out-Null

# ── 2. 推 rootfs + 装 Ubuntu ──
Info "推送 Ubuntu rootfs（29MB，约 10 秒）..."
adb push $rootfs /data/local/tmp/ubuntu-base.tar.gz | Out-Null

Info "安装 Ubuntu base（解压 + apt 装基础工具，约 1-2 分钟）..."
adb shell "su -c 'sh /data/local/tmp/install-ubuntu.sh'"

# ── 3. 桌面 ──
if (-not $SkipDesktop) {
    Info "安装 XFCE4 桌面 + VNC（几百 MB，几分钟）..."
    PushToUbuntuRoot (Join-Path $S "setup-desktop-ubuntu.sh") "setup-desktop-ubuntu.sh"
    RunInUbuntu "setup-desktop-ubuntu.sh"
} else { Warn "跳过桌面安装（-SkipDesktop）" }

# ── 4. Firefox ──
$firefox = Join-Path $scriptDir "firefox-aarch64.tar.xz"
if (-not $SkipFirefox -and -not $SkipDesktop) {
    if (Test-Path $firefox) {
        Info "安装 Firefox（Mozilla 官方 arm64）..."
        PushToUbuntuRoot $firefox "firefox-aarch64.tar.xz"
        PushToUbuntuRoot (Join-Path $S "install-firefox.sh") "install-firefox.sh"
        RunInUbuntu "install-firefox.sh"
    } else { Warn "未找到 firefox-aarch64.tar.xz，跳过 Firefox（下载见 README）" }
} else { Warn "跳过 Firefox" }

# ── 5. 中文输入法 ──
if (-not $SkipFcitx -and -not $SkipDesktop) {
    Info "安装 fcitx5 中文输入法 ..."
    PushToUbuntuRoot (Join-Path $S "install-fcitx5.sh") "install-fcitx5.sh"
    RunInUbuntu "install-fcitx5.sh"
    PushToUbuntuRoot (Join-Path $S "fix-fcitx-env.sh") "fix-fcitx-env.sh"
    RunInUbuntu "fix-fcitx-env.sh"
} else { Warn "跳过中文输入法" }

# ── 6. 端口转发 ──
Info "配置端口转发（SSH 2222 / VNC 5900）..."
adb forward tcp:2222 tcp:2222 | Out-Null
adb forward tcp:5900 tcp:5900 | Out-Null

# ── 完成 ──
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  部署完成！" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  启动桌面（手机端 / adb shell 内）：" -ForegroundColor White
Write-Host "    adb shell"
Write-Host "    su"
Write-Host "    sh /data/local/tmp/ubuntu-enter.sh"
Write-Host "    bash /root/start-services.sh $Resolution"
Write-Host ""
Write-Host "  设置 root 密码（首次，SSH 登录用）：进 Ubuntu 后执行 passwd"
Write-Host ""
Write-Host "  连接方式：" -ForegroundColor White
Write-Host "    VNC: 客户端连 127.0.0.1:5900（PC）或手机本机 127.0.0.1:5900"
Write-Host "    SSH: ssh root@127.0.0.1 -p 2222"
Write-Host ""
Write-Host "  中文输入：桌面里按 Ctrl+Space 切换中/英" -ForegroundColor White
Write-Host ""
