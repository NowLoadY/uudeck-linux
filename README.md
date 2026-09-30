# uudeck-linux (网易 UU 加速器 Linux / Ubuntu 便捷安装与管理工具)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: Linux](https://img.shields.io/badge/Platform-Ubuntu%20%7C%20Debian%20%7C%20Linux-blue.svg)](https://ubuntu.com)

为 Ubuntu、Debian 等主流 Linux 发行版提供**网易 UU 主机加速器（Steam Deck 插件版）**的一键安装、环境修复、桌面快捷方式及交互式控制台管理工具。

---

## ❓ 为什么官方脚本在 Ubuntu 上会安装失败？

网易官方提供的安装命令为：
```bash
curl -s uudeck.com | sudo sh
```
在 **Ubuntu / Debian** 环境下通常会在 `30% 检查安装目录...` 处中断失败，原因如下：
1. **Shell 不兼容（Dash vs Bash）**：Ubuntu 默认的 `/bin/sh` 指向 **`dash`**（POSIX 标准 Shell），而官方脚本第 64 行使用了 Bash 专有的切片语法 `${str:0:6}`，导致 `dash` 报 `Bad substitution` 语法错误退出，造成安装目录变量为空。
2. **非 SteamOS 环境缺失用户目录**：官方脚本默认期望 `/home/deck` 目录存在；普通 Linux 系统用户名不是 `deck`，会进入上述未适配的兼容分支。
3. **报错静默重定向**：官方脚本将标准错误输出重定向至 `/tmp/*.log`，终端只看到进度中断，无法察觉真实错误。
4. **关机卡死问题**：原版 systemd 服务缺少针对守护进程 `xuplugin-guardian` 的停机定义，容易导致系统关机时出现 90 秒超时卡死。

本项目自动解决以上所有痛点，并提供更易用的桌面/终端管理支持。

---

## ✨ 功能特性

- ⚡ **一键修复与安装**：自动建立环境兼容映射，使用 Bash 解析，杜绝 `Bad substitution` 报错。
- 🖥️ **桌面快捷方式**：自带官方高清 Logo 图标，集成至桌面与系统应用菜单，双击即开。
- 📱 **便捷绑定**：控制台直接打印绑定二维码与局域网 IP，手机【网易UU主机加速器】App 扫码即连。
- 🛠️ **交互式管理面板 (`uudeck`)**：提供实时状态显示、二维码重新生成、服务重启/停止及日志查看。
- 🔑 **日常操作免密**：配置轻量 sudoers 规则，点击桌面图标启停服务无需繁琐输入 sudo 密码。
- 🛑 **关机优化**：优化 systemd 退出机制，避免系统重启或关机时因守护进程残留而挂起。

---

## 🚀 快速安装

### 方式一：一键命令安装（推荐）

打开终端，直接运行以下命令：

```bash
curl -fsSL https://raw.githubusercontent.com/NowLoadY/uudeck-linux/main/install.sh | sudo bash
```

### 方式二：克隆仓库安装

```bash
git clone https://github.com/NowLoadY/uudeck-linux.git
cd uudeck-linux
sudo ./install.sh
```

---

## 📖 使用指南

### 1. 桌面快捷方式（最简单）
* 在您的电脑**桌面**或**系统应用程序菜单**中找到 **【网易UU加速器】** 图标。
* **双击打开**，即可在终端窗口中查看当前状态与绑定二维码。

### 2. 终端控制台
在任意终端窗口中输入以下任一命令打开管理面板：
```bash
uudeck
# 或简写
uu
```

面板提供快捷功能菜单：
```text
================================================================
                   网易 UU 主机加速器 (Linux版)                 
================================================================
 服务状态: ● 正在运行 (Running)  (守护进程 PID: 25007)
 本机IP:   192.168.1.100
 设备UUID: 53b49a12-3fc7-404f-acca-e4d7a6980687
----------------------------------------------------------------
【手机 App 扫码绑定】
...（此处自动渲染绑定二维码）...
----------------------------------------------------------------
常用操作：
  [1] 刷新状态 / 重新读取二维码
  [2] 重启加速器服务 (重新生成绑定码)
  [3] 启动加速器服务
  [4] 停止加速器服务
  [5] 查看加速器运行日志
  [q] 退出本窗口 (加速服务仍会在后台继续运行)
----------------------------------------------------------------
```

### 3. 手机 App 绑定流程
1. 确保手机与电脑连接至**同一个 Wi-Fi / 局域网**；
2. 打开手机端的 **【网易UU主机加速器】App**；
3. 点击首页右上角 **【+】** 号选择扫码；
4. 扫描控制台显示的二维码完成绑定；
5. 绑定成功后，按 `q` 退出管理界面即可，加速服务将保持在后台运行。

---

## 🗑️ 卸载清理

如需完全卸载加速器及本项目所有配置文件，运行：

```bash
sudo ./uninstall.sh
```
或单行命令：
```bash
curl -fsSL https://raw.githubusercontent.com/NowLoadY/uudeck-linux/main/uninstall.sh | sudo bash
```

---

## 📄 开源许可

本项目遵循 [MIT License](LICENSE) 开源协议。
网易 UU、相关名称及商标归属于网易公司所有。
