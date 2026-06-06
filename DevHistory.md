# 开发踩坑记录（DevHistory）

记录 rooted Android 上 chroot 跑 Ubuntu 过程中碰到的坑。
**重点是那些现象有误导性、排查绕了弯路的**——以后再遇到类似报错，先来这查。

实测设备：OnePlus PJZ110 / Android 15 (SDK 35) / 内核 6.6.66-android15 / KernelSU `<LKM>` v2.1.2 / arm64-v8a / `/data` 是 f2fs。

---

## 坑 1：KernelSU 装了，但 `adb shell` 里 `su: not found`

**现象**：KernelSU app 显示"工作中"，但 `adb shell` 里执行 `su` 报 `inaccessible or not found`，扫 `/data/adb/ksu/bin/su` 等固定路径也都不存在。

**根因**：两个叠加——
1. **KernelSU LKM 模式**：su 是动态注入的，没有固定路径的 su 文件，按老版路径去扫扫不到。
2. **adb shell（uid 2000）默认不在 root 授权名单**：KernelSU 的"超级用户"列表里只有已授权的 app，`shell` 默认没勾。

**解法**：KernelSU app → 底部【超级用户】→ 找到 **Shell**（uid 2000）→ 打开授权开关。然后 `adb shell "su -c id"` 返回 `uid=0(root) ... context=u:r:su:s0` 即成功。

**判据**：先 `adb shell "su -c id"`，看到 `uid=0` 才往下走。

---

## 坑 2：chroot 进去后命令全 `not found`（id/touch 等）

**现象**：`chroot /data/ubuntu /bin/sh -c "id"` 报 `id: not found`；`touch` 也"失败"（报成 Permission denied，更误导）。但宿主层直接写文件 OK，文件系统没问题。

**根因**：**chroot 不会重置 PATH，继承了调用者的环境**。Android 的 `su` 给的 PATH 是 `/system/bin:/apex/...:/data/adb/ksu/bin` 全是**宿主路径**，chroot 内的 Ubuntu/Alpine 根本没这些目录，所以任何外部命令都找不到。

**判据**：进 chroot 后 `echo $PATH`，如果看到 `/apex`、`/system/bin`、`/data/adb` → 就是这个坑。

**解法**：**`env -i` 必须在 chroot 外面执行**，先清空宿主环境再调 chroot：
```sh
# 正确
env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root chroot /data/ubuntu /bin/bash ...
# 错误（env 会在新根里找不到自己，报 "exec env: No such file or directory"）
chroot /data/ubuntu env -i ... /bin/bash ...
```

---

## 坑 3（最坑）：apt/apk 报 `Permission denied`，其实是 HTTP 403

**现象**：`apk update` / `apt update` 报 `WARNING: ... Permission denied`，连重试都一样。

**排查弯路**（依次排除，全是错的）：
1. 以为是 SELinux → 临时 `setenforce 0`（Permissive）后**还是失败** → 排除 SELinux。
2. 以为是 `/data` 的 `nosuid` / f2fs 属性 → 手动 `touch`/`chmod`/`chown` 在 chroot 内**全部成功** → 排除文件系统。
3. 以为是 apk 缓存目录权限 → 手动建 `APKINDEX.*.tar.gz` 缓存文件**也成功** → 排除缓存。
4. 以为是 `O_TMPFILE` / mmap，把缓存换成 tmpfs → **还是失败** → 排除。

**真根因**：**镜像源对境外 IP 返回 HTTP 403**。手机挂着 VPN，出口 IP 是境外的，**清华 TUNA / 中科大 USTC 等教育网镜像对境外 IP 直接 403 Forbidden**（防境外蹭流量）。apk/apt 把 HTTP 403 错误**烂翻译成 "Permission denied"**。

**定位的关键一步**：手动 `wget` 同一个 URL → 直接看到 `HTTP/1.1 403 Forbidden`，真相大白。

**判据**：
- apt/apk 报 Permission denied 但文件系统操作都正常 → 怀疑网络层。
- 手动 `wget <源URL>/...` 看返回码。403 = 源拒绝你的 IP。
- 查出口 IP：`wget -q -O - http://ip.3322.net`，境外 IP + 国内镜像源 = 必 403。

**解法**：用**不挑 IP 的官方源**：
- Ubuntu arm64：`http://ports.ubuntu.com/ubuntu-ports`（注意 arm64 在 **ports**，不是 archive.ubuntu.com）
- Alpine：`http://dl-cdn.alpinelinux.org`
- 阿里云 `mirrors.aliyun.com` 也不挑 IP（实测 200）。
- 国内直连（不挂 VPN）才能用清华/中科大。

---

## 坑 4：`rm -rf /data/ubuntu` 删到宿主的 /sys /dev

**现象**：`rm -rf /data/alpine` 报一堆 `Operation not permitted`，删的文件名是 `.init.plt`、`.data`、`uevent`、`.note.Linux`、`initsize` ——**这些是内核 sysfs 节点，不是发行版文件**。

**根因**：安装时把 `/proc`、`/sys`、`/dev` **bind mount 到了 `/data/ubuntu/` 下**。直接 `rm -rf` 会**顺着 bind mount 删进宿主的 /sys 和 /dev**。幸好内核虚拟文件大多受保护（Operation not permitted），没造成实际损害。

**判据**：rm 报错的文件名像内核节点（uevent / .note.* / 各种 ELF section 名）→ 立刻停手，说明在删挂载点里的东西。

**解法**：**永远先卸载挂载点，再删**。用 `safe-clean-ubuntu.sh`：按 `dev/pts → dev → proc → sys` 顺序 umount（devpts 在 dev 里，必须先卸），确认 `/proc/mounts` 里无该路径后才 `rm -rf`。删完重启手机让内核重建 /dev /sys 节点最稳。

---

## 坑 5：adb 没 root，push 不进 /data/ubuntu

**现象**：`adb push xxx /data/ubuntu/root/` 报 `couldn't create file: Permission denied`。

**根因**：`adb push` 以 uid 2000 (shell) 身份运行，而 `/data/ubuntu` 是 root 建的，shell 进不去。`/data/local/tmp` 之所以能 push，是因为它是专门给 adb shell 用的全局可写目录。

**解法**：两步——先 push 到 `/data/local/tmp`，再用 `su` cp 进去：
```powershell
adb push xxx.sh /data/local/tmp/xxx.sh
adb shell "su -c 'cp /data/local/tmp/xxx.sh /data/ubuntu/root/'"
```

---

## 坑 6：chroot 内脚本 `No such file or directory`

**现象**：进了 chroot 后跑 `bash /data/local/tmp/xxx.sh` 报文件不存在，但文件明明 push 进去了。

**根因**：进了 chroot 后，`/data/local/tmp` 是**宿主路径**，chroot 内的 Ubuntu 看不见（它的根是 `/data/ubuntu`）。chroot 隔离的本质。

**解法**：脚本要放到 chroot 内能看到的路径，即宿主的 `/data/ubuntu/root/`（chroot 内是 `/root/`）。见坑 5 的 push 方法。

---

## 坑 7：fcitx5 进程在跑，但 Ctrl+Space 切不出中文

**现象**：`pgrep fcitx5` 有进程，桌面也起来了，但按 Ctrl+Space 没反应。`fcitx5-diagnose` 报 `XMODIFIERS is not set`、`QT_IM_MODULE 请设为 fcitx`。

**根因**：两个——
1. **环境变量没传到桌面会话**：fcitx5 守护进程起了，但 XFCE 和应用进程没拿到 `GTK_IM_MODULE`/`QT_IM_MODULE`/`XMODIFIERS`，应用不知道要找 fcitx。
2. **值写错**：诊断里出现 `GTK_IM_MODULE=fcitx5` —— 正确值是 **`fcitx`**（不带 5）。fcitx5 这个软件的 IM module 名仍是 `fcitx`。

**解法**：`fix-fcitx-env.sh` ——
- 写进 `/etc/environment`（全局，所有进程继承，最可靠）
- 写进 `/root/.xprofile`（X 会话启动读取）
- start-vnc.sh 里在 `startxfce4` **之前** export 正确的值
- 改完重启桌面（stop-vnc + start-services），VNC 重连。

---

## Firefox 相关

- **firefox-esr 在 ports 源没有**：arm64 的 Firefox 走 snap，chroot 里没 snapd 跑不了。解法：用 **Mozilla 官方 arm64 tarball**（`os=linux64-aarch64`，注意是这个 os 参数，`linux-aarch64`/`linux-arm64` 都 404）。
- **chroot 里 Firefox 必须 `--no-sandbox`**：chroot 没有用户命名空间沙箱，不关沙箱会崩。启动器已自动加。

---

## 通用排查心法（这次总结的）

1. **报错措辞会骗人**：apk/apt 的 "Permission denied" 实际是 HTTP 403；"command not found" 可能是 PATH 污染。**别被表面措辞带跑，逐层隔离。**
2. **逐层隔离法**：文件系统问题？→ 手动 touch/chmod/chown 试。网络问题？→ 手动 wget 看返回码。权限问题？→ 看 uid 和 SELinux context。一层层排除，别一上来就猜。
3. **底层能力先验证**：装发行版前先用 `android-rootcheck.sh` 确认 chroot/mount/bind 都 OK。底层通了，后面的坑都在应用层（源、PATH、环境变量），范围小很多。
4. **chroot 的两个隔离本质**：① PATH/环境不重置会带进宿主污染（坑 2）；② 宿主路径在 chroot 内看不见（坑 6）。记住这两点，一半的坑能预判。
5. **挂 VPN 改一切**：出口 IP 变境外，所有国内镜像源行为都变（403）。排查网络问题先确认 VPN 状态和出口 IP。
