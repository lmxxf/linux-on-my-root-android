# Linux on (rooted) Android

在已 **root** 的 Android 设备上，通过 **chroot** 运行完整的 **Ubuntu 24.04 桌面**（XFCE4 + VNC + Firefox + 中文输入法），共享 Android 内核，**零虚拟化开销**。

把一台 24G 内存的安卓旗舰变成随身 ARM Linux 工作站。

---

## 原理

| 项目 | 说明 |
|------|------|
| 宿主系统 | Android（Linux 内核，本项目实测 6.6.66 / Android 15） |
| 客户系统 | Ubuntu 24.04 LTS（aarch64，glibc） |
| 隔离方式 | chroot（**非虚拟机、非容器**） |
| 性能损耗 | 无（共享内核，程序通过原生 syscall 直达内核） |
| 安装位置 | `/data/ubuntu` |
| 桌面 | XFCE4 + Xvfb + x11vnc |
| 浏览器 | Firefox（Mozilla 官方 arm64 tarball，不走 snap） |
| 输入法 | fcitx5 + 拼音（Ctrl+Space 切换） |

> **为什么是 chroot 而不是虚拟机？** chroot 只替换用户态文件（rootfs），内核仍是 Android 的。程序发的是 Linux syscall，Android 内核原生听得懂，所以零开销。代价是必须 root（chroot 系统调用需要权限）。
>
> **为什么不能装 Windows？** Windows 程序发的是 NT API，不是 Linux syscall，Android 内核听不懂。chroot 对 Windows 完全无效，虚拟机又太慢。安卓上没有可用的 Windows 方案。

---

## 环境要求

- **已 root 的 Android 设备**（aarch64）。本项目用 **KernelSU** 实测，Magisk/APatch 同理。
- root 已授权给 adb shell（KernelSU app → 超级用户 → 给 **Shell** 打开授权）。
- PC 装好 `adb`，USB 连上设备，`adb devices` 能看到。
- 设备能上网（装软件包要从 Ubuntu 源下载）。
- 设备系统时间正确（时间偏差会导致 SSL 证书验证失败）。

> **挂 VPN 注意**：境外出口 IP 访问国内镜像源（清华/中科大）会被 **403 Forbidden** 拒绝，apt/apk 会把它误报成 `Permission denied`。本项目默认用**官方源**（`ports.ubuntu.com`），不挑 IP，挂 VPN 也能装。

---

## 准备文件

两个大文件不在仓库里，需自行下载放到 `linux-on-android/` 目录下：

**1. Ubuntu base rootfs（必需，~29MB）**

```bash
# 在能上网的机器（WSL/Linux）上下载，文件名重命名为 ubuntu-base-24.04-arm64.tar.gz
curl -L -o ubuntu-base-24.04-arm64.tar.gz \
  "https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.4-base-arm64.tar.gz"
```
> 版本点位（24.04.4）可能更新，目录 https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ 里挑最新的 `*-base-arm64.tar.gz`。

**2. Firefox arm64（可选，~71MB，不装浏览器可跳过）**

```bash
curl -L -o firefox-aarch64.tar.xz \
  "https://download.mozilla.org/?product=firefox-latest-ssl&os=linux64-aarch64&lang=zh-CN"
```

---

## 一键安装

```powershell
# Windows PowerShell，cd 到 linux-on-android 目录
powershell -ExecutionPolicy Bypass -File .\deploy.ps1
```

自动完成：检查 root → 装 Ubuntu base → 装 XFCE4 桌面 + VNC → 装 Firefox → 装 fcitx5 中文输入法 → 配端口转发。

**可选参数：**

| 参数 | 说明 |
|------|------|
| `-SkipDesktop` | 只装命令行 Ubuntu，不装桌面 |
| `-SkipFirefox` | 不装 Firefox |
| `-SkipFcitx`   | 不装中文输入法 |
| `-Resolution 2560x1440` | VNC 分辨率（默认 1920x1080） |

```powershell
# 例：只要命令行 Ubuntu
powershell -ExecutionPolicy Bypass -File .\deploy.ps1 -SkipDesktop
```

---

## 启动与连接

部署完成后，**启动桌面**（每次开机后需手动启动一次）：

```bash
adb shell
su
sh /data/local/tmp/ubuntu-enter.sh      # 进入 Ubuntu chroot
passwd                                    # 首次：设 root 密码（SSH 登录用）
bash /root/start-services.sh 1920x1080    # 启动 SSH(2222) + VNC 桌面
```

**连接（PC 端口转发已由 deploy.ps1 配好）：**

```
VNC: 客户端连 127.0.0.1:5900
SSH: ssh root@127.0.0.1 -p 2222
```

> **手机本机 VNC**：手机上的 VNC 客户端（RealVNC / AVNC / bVNC）直接连 `127.0.0.1:5900` 即可，不用端口转发。
>
> **中文输入**：桌面里任意输入框按 **Ctrl+Space** 切换中/英。手机 VNC 客户端用扩展键盘点 Ctrl 再点空格。

**手动控制端口转发（PowerShell）：**

```powershell
adb forward tcp:2222 tcp:2222   # SSH
adb forward tcp:5900 tcp:5900   # VNC
adb forward --list              # 查看
adb forward --remove-all        # 取消全部
```

---

## 卸载

> **绝对不要直接 `rm -rf /data/ubuntu`**：挂载点（/proc /sys /dev）没卸载会顺着 bind mount 删到宿主系统的 /sys 和 /dev！用安全清理脚本：

```powershell
adb push scripts\safe-clean-ubuntu.sh /data/local/tmp/safe-clean-ubuntu.sh
adb shell "su -c 'sh /data/local/tmp/safe-clean-ubuntu.sh'"
```

它会先按正确顺序卸载所有挂载点，确认无挂载后才删除。

---

## 脚本说明（scripts/ 目录）

所有脚本都设计为**幂等**（重复执行安全，已装的跳过）。一键 `deploy.ps1` 就是按顺序编排它们。也可单独使用：

### 正式脚本

| 脚本 | 在哪跑 | 功能 |
|------|--------|------|
| `install-ubuntu.sh` | Android root shell | 解压 Ubuntu base 到 `/data/ubuntu`，配官方源，挂载 /proc /sys /dev，apt 装基础工具（curl/htop/tmux/openssh-server/sudo/nano），生成入口脚本 `ubuntu-enter.sh` |
| `setup-desktop-ubuntu.sh` | Ubuntu chroot 内 | apt 装 XFCE4 + Xvfb + x11vnc + 中文字体，生成 `start-vnc.sh` / `stop-vnc.sh` / `start-services.sh` |
| `install-firefox.sh` | Ubuntu chroot 内 | 装 Firefox 运行依赖库，解压官方 tarball 到 `/opt`，建启动器（chroot 必须 `--no-sandbox`）+ 桌面菜单项。需先把 `firefox-aarch64.tar.xz` 放到 `/root/` |
| `install-fcitx5.sh` | Ubuntu chroot 内 | 装 fcitx5 + 拼音引擎，配默认输入法，集成进 VNC 启动脚本 |
| `fix-fcitx-env.sh` | Ubuntu chroot 内 | 修复输入法环境变量（`GTK/QT_IM_MODULE=fcitx`）：写入 `/etc/environment` + `/root/.xprofile`，重写 `start-vnc.sh`。**Ctrl+Space 不生效时跑它** |
| `safe-clean-ubuntu.sh` | Android root shell | 安全卸载所有挂载点后删除 `/data/ubuntu`（卸载用，防误删宿主 /sys /dev） |

**单独跑 chroot 内脚本的通用方法**（脚本需先进到 Ubuntu 的 `/root/`）：

```powershell
# PC 端：push 到 tmp，再 su cp 进 Ubuntu（adb 无 root，不能直接写 /data/ubuntu）
adb push scripts\install-fcitx5.sh /data/local/tmp/install-fcitx5.sh
adb shell "su -c 'cp /data/local/tmp/install-fcitx5.sh /data/ubuntu/root/'"
```
```bash
# 设备端：进 Ubuntu 跑
adb shell
su
sh /data/local/tmp/ubuntu-enter.sh
bash /root/install-fcitx5.sh
```

### diagnostics/ — 诊断脚本

排查问题时用的一次性工具，记录了这套方案是怎么趟出来的：

| 脚本 | 功能 |
|------|------|
| `android-probe.sh` / `.ps1` | 探测设备：架构、root 方案、SELinux、`/data` 是否 noexec、chroot 工具、网络。**装之前先跑这个确认环境** |
| `android-rootcheck.sh` | 验证 root 下 chroot 真正需要的能力：bind mount、chroot 系统调用、/proc/sys/dev 可挂载 |
| `diag-perm.sh` ~ `diag6.sh` | apt/apk 报 “Permission denied” 的逐层排查（最终定位是镜像源对 VPN 境外 IP 返 403） |
| `check-fcitx.sh` | 检查 fcitx5 进程、桌面进程、输入法环境变量、官方诊断 |

### alpine-legacy/ — Alpine 旧方案（参考）

最初用 Alpine（musl）跑通的脚本。后来转 Ubuntu（glibc，软件生态好、预编译包兼容性强）。Alpine 体积更小（~8MB），内存极省，适合极简场景：

| 脚本 | 功能 |
|------|------|
| `install.sh` | Alpine minirootfs 版安装（apk + musl） |
| `safe-clean.sh` | Alpine 版安全卸载 |

> Alpine vs Ubuntu：内存/空间充裕（如本项目的 24G 机型）选 **Ubuntu**（glibc，AI/开发工具不踩 musl 兼容坑）；极度受限设备可选 Alpine。

---

## 常见问题

**Q: `su: not found` / chroot 失败？**
KernelSU/Magisk 里 root 没授权给 adb shell。打开管理器 app，给 **Shell**（uid 2000）授予 root。

**Q: apt 报 `Permission denied`？**
多半是挂 VPN 时镜像源对境外 IP 返 403。本项目已默认用官方 `ports.ubuntu.com` 源。若仍有问题，确认设备能访问 `ports.ubuntu.com`。

**Q: Ctrl+Space 切不出中文？**
跑 `fix-fcitx-env.sh`，然后重启桌面（`stop-vnc.sh` + `start-services.sh`），手机 VNC 重连。

**Q: Firefox 启动崩溃？**
chroot 下必须关沙箱，启动器已自动加 `--no-sandbox`。若缺库，按报错 `apt install` 对应 `lib*`。

**Q: 重启手机后桌面没了？**
chroot 不是开机自启的。重新 `sh /data/local/tmp/ubuntu-enter.sh` + `bash /root/start-services.sh` 即可。数据都在 `/data/ubuntu`，不会丢。

---

## License

MIT
