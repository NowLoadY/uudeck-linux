#!/usr/bin/env bash
# ==============================================================================
# 网易 UU 加速器 (Steam Deck / Linux) 一键安装与配置脚本
# 项目地址: https://github.com/NowLoadY/uudeck-linux
# ==============================================================================

set -e

GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
BOLD="\033[1m"
RESET="\033[0m"

REPO_RAW_URL="https://raw.githubusercontent.com/NowLoadY/uudeck-linux/main"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"

info() { echo -e "${CYAN}[INFO]${RESET} $1"; }
ok()   { echo -e "${GREEN}[OK]${RESET} $1"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
err()  { echo -e "${RED}[ERROR]${RESET} $1"; }

# 1. 检查 root 权限
if [ "$EUID" -ne 0 ]; then
    err "请使用 root 权限运行此脚本：sudo ./install.sh 或 sudo bash install.sh"
    exit 1
fi

info "开始安装与配置网易 UU 加速器 (Linux 版)..."

# 2. 检查依赖工具
for cmd in curl systemctl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        err "缺少必要依赖命令: $cmd，请先安装后重试。"
        exit 1
    fi
done

# 3. 建立 Steam Deck / Bazzite 兼容环境
# 原因：网易官方安装脚本针对 SteamOS (/home/deck) 编写。在标准 Ubuntu/Debian 下
# /bin/sh 为 dash，脚本第64行 ${str:0:6} 语法会导致 Bad substitution 终止。
info "配置 Linux 环境兼容映射..."
mkdir -p /home/uu/uu
chmod 755 /home/uu
if [ ! -e /home/deck ]; then
    ln -sfn /home/uu /home/deck
    ok "创建 /home/deck -> /home/uu 兼容链接成功"
fi

# 4. 下载并安装官方核心组件
info "下载网易官方核心加速组件..."
TMP_SCRIPT="/tmp/uudeck_install_official.sh"
curl -fsSL http://uudeck.com -o "$TMP_SCRIPT"

# 规避官方脚本末尾无终止循环等待扫码的问题，安装成功后统一交由我们的 uudeck 管理
sed -i 's/while \[ -f "\${QRFILE}" \]; do/for _ in 1; do/' "$TMP_SCRIPT" 2>/dev/null || true

info "执行核心组件安装..."
bash "$TMP_SCRIPT" || {
    warn "官方安装脚本返回非零，正在检查服务状态..."
}
rm -f "$TMP_SCRIPT"

# 5. 优化 systemd 守护进程停止机制（防止关机时超时 90s 等待）
SERVICE_FILE="/etc/systemd/system/uuplugin.service"
if [ -f "$SERVICE_FILE" ]; then
    info "优化 systemd 服务停机机制..."
    cat << 'EOF' > "$SERVICE_FILE"
[Unit]
Description=UU Plugin
Wants=network-online.target
After=network.target network-online.target

[Service]
Type=simple
ExecStart=/bin/sh /home/deck/uu/uuplugin_monitor.sh
ExecStop=-/bin/kill -TERM ${MAINPID}
ExecStop=-/usr/bin/pkill -TERM -x uuplugin
ExecStop=-/bin/sh -c 'while /usr/bin/pgrep -f "[x]uplugin-guardian" >/dev/null 2>&1; do sleep 0.2; done'
TimeoutStopSec=30

[Install]
WantedBy=default.target
EOF
    systemctl daemon-reload
    systemctl enable uuplugin
    systemctl restart uuplugin
    ok "uuplugin.service 开机自启配置完成"
fi

# 6. 安装管理命令行及图形启动器
info "安装控制台管理命令 (uudeck / uu)..."

fetch_file() {
    local rel_path="$1"
    local dest_path="$2"
    if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/$rel_path" ]; then
        cp -f "$SCRIPT_DIR/$rel_path" "$dest_path"
    else
        curl -fsSL "${REPO_RAW_URL}/${rel_path}" -o "$dest_path"
    fi
}

fetch_file "bin/uudeck" "/usr/local/bin/uudeck"
chmod 755 /usr/local/bin/uudeck
ln -sfn /usr/local/bin/uudeck /usr/local/bin/uu

fetch_file "bin/uudeck-gui" "/usr/local/bin/uudeck-gui"
chmod 755 /usr/local/bin/uudeck-gui
ok "管理脚本安装至 /usr/local/bin/uudeck"

# 7. 安装官方高清图标
info "安装应用图标..."
mkdir -p /usr/share/pixmaps
fetch_file "assets/uuplugin.png" "/usr/share/pixmaps/uuplugin.png"
chmod 644 /usr/share/pixmaps/uuplugin.png
ok "图标安装至 /usr/share/pixmaps/uuplugin.png"

# 8. 安装桌面快捷方式与系统应用菜单项
info "配置桌面快捷方式及系统启动器..."
mkdir -p /usr/share/applications
fetch_file "assets/uuplugin.desktop" "/usr/share/applications/uuplugin.desktop"
chmod 644 /usr/share/applications/uuplugin.desktop

# 为实际运行 sudo 的普通用户在桌面上创建快捷方式
ACTUAL_USER="${SUDO_USER:-$USER}"
if [ "$ACTUAL_USER" != "root" ] && [ -n "$ACTUAL_USER" ]; then
    USER_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
    for desk in "桌面" "Desktop"; do
        DESK_DIR="${USER_HOME}/${desk}"
        if [ -d "$DESK_DIR" ]; then
            DESK_FILE="${DESK_DIR}/网易UU加速器.desktop"
            cp -f /usr/share/applications/uuplugin.desktop "$DESK_FILE"
            chown "${ACTUAL_USER}:${ACTUAL_USER}" "$DESK_FILE"
            chmod 755 "$DESK_FILE"
            # 标记为可信任桌面文件（GNOME）
            su - "$ACTUAL_USER" -c "gio set '${DESK_FILE}' metadata::trusted true 2>/dev/null || true"
            ok "桌面快捷方式已生成: ${DESK_FILE}"
        fi
    done
fi

update-desktop-database /usr/share/applications 2>/dev/null || true

# 9. 配置 sudoers 免密规则（点击桌面图标与菜单控制时无需繁琐输入密码）
info "配置日常服务启停免密规则..."
SUDOERS_FILE="/etc/sudoers.d/uuplugin"
cat << 'EOF' > /tmp/sudoers_uuplugin_tmp
ALL ALL=(ALL) NOPASSWD: /usr/bin/systemctl start uuplugin, /usr/bin/systemctl stop uuplugin, /usr/bin/systemctl restart uuplugin, /usr/bin/systemctl status uuplugin, /usr/bin/systemctl is-active uuplugin, /bin/systemctl start uuplugin, /bin/systemctl stop uuplugin, /bin/systemctl restart uuplugin, /bin/systemctl status uuplugin, /bin/systemctl is-active uuplugin
EOF

if visudo -c -f /tmp/sudoers_uuplugin_tmp >/dev/null 2>&1; then
    mv /tmp/sudoers_uuplugin_tmp "$SUDOERS_FILE"
    chmod 0440 "$SUDOERS_FILE"
    ok "免密授权规则配置完成"
else
    rm -f /tmp/sudoers_uuplugin_tmp
    warn "sudoers 配置校验未通过，已跳过免密规则配置"
fi

echo ""
echo -e "${GREEN}================================================================${RESET}"
echo -e "${BOLD}      🎉 网易 UU 加速器 (Linux 版) 安装与配置成功！              ${RESET}"
echo -e "${GREEN}================================================================${RESET}"
echo -e "你可以通过以下方式使用加速器："
echo -e " 1. ${BOLD}桌面快捷方式${RESET}：双击桌面的【网易UU加速器】图标"
echo -e " 2. ${BOLD}终端快捷命令${RESET}：在终端输入 ${CYAN}uudeck${RESET} 或 ${CYAN}uu${RESET}"
echo -e " 3. ${BOLD}后台自启动${RESET}  ：开机自动启动，手机 App 连接同局域网即可识别"
echo -e "${GREEN}================================================================${RESET}"
echo ""

# 启动并显示一次管理面板/二维码
if [ -t 1 ]; then
    read -rp "是否立即打开加速器控制面板查看绑定二维码？[Y/n]: " show_now
    case "$show_now" in
        [nN][oO]|[nN])
            info "你可以稍后在终端运行 uudeck 查看二维码并绑定。"
            ;;
        *)
            /usr/local/bin/uudeck
            ;;
    esac
fi
