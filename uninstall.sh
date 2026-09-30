#!/usr/bin/env bash
# ==============================================================================
# 网易 UU 加速器 (Steam Deck / Linux) 一键卸载清理脚本
# 项目地址: https://github.com/NowLoadY/uudeck-linux
# ==============================================================================

set -e

GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
BOLD="\033[1m"
RESET="\033[0m"

info() { echo -e "${CYAN}[INFO]${RESET} $1"; }
ok()   { echo -e "${GREEN}[OK]${RESET} $1"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
err()  { echo -e "${RED}[ERROR]${RESET} $1"; }

if [ "$EUID" -ne 0 ]; then
    err "请使用 root 权限运行此脚本：sudo ./uninstall.sh"
    exit 1
fi

echo -e "${YELLOW}================================================================${RESET}"
echo -e "${BOLD}       确定要完全卸载网易 UU 加速器及其所有组件吗？             ${RESET}"
echo -e "${YELLOW}================================================================${RESET}"
if [ -t 0 ]; then
    read -rp "请输入 [y/N]: " confirm
    case "$confirm" in
        [yY][eE][sS]|[yY]) ;;
        *)
            info "已取消卸载。"
            exit 0
            ;;
    esac
fi

info "1. 停止并禁用 systemd 服务..."
if systemctl is-active --quiet uuplugin 2>/dev/null; then
    systemctl stop uuplugin 2>/dev/null || true
fi
if systemctl is-enabled --quiet uuplugin 2>/dev/null; then
    systemctl disable uuplugin 2>/dev/null || true
fi

info "2. 强制终止残留进程..."
pkill -9 -f xuplugin-guardian 2>/dev/null || true
pkill -9 -x uuplugin 2>/dev/null || true

info "3. 清理 systemd 服务文件..."
rm -f /etc/systemd/system/uuplugin.service
systemctl daemon-reload 2>/dev/null || true

info "4. 清理安装文件及兼容链接..."
rm -rf /home/uu
if [ -L /home/deck ]; then
    rm -f /home/deck
fi
rm -rf /tmp/uu /tmp/uu_steam_deck_install_*.log

info "5. 清理管理命令与快捷方式..."
rm -f /usr/local/bin/uudeck /usr/local/bin/uudeck-gui /usr/local/bin/uu
rm -f /usr/share/pixmaps/uuplugin.png
rm -f /usr/share/applications/uuplugin.desktop

# 清理当前用户的桌面快捷方式
ACTUAL_USER="${SUDO_USER:-$USER}"
if [ "$ACTUAL_USER" != "root" ] && [ -n "$ACTUAL_USER" ]; then
    USER_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
    rm -f "${USER_HOME}/桌面/网易UU加速器.desktop" "${USER_HOME}/Desktop/网易UU加速器.desktop"
    su - "$ACTUAL_USER" -c "rm -f ~/.local/share/applications/uuplugin.desktop ~/.local/share/icons/uuplugin.png 2>/dev/null || true"
fi

info "6. 清理 sudoers 免密配置..."
rm -f /etc/sudoers.d/uuplugin

update-desktop-database /usr/share/applications 2>/dev/null || true

echo ""
ok "网易 UU 加速器及所有相关组件已全部清理完毕！"
echo ""
