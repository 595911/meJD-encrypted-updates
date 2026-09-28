#!/usr/bin/env bash
set -euo pipefail

[[ "$(uname -s)" == Darwin ]] || { echo '请在 macOS 终端运行。' >&2; exit 1; }
[[ -n "${MEJD_UPDATE_KEY_BASE64:-}" ]] || { echo '命令缺少首次安装码。' >&2; exit 1; }
case "$(uname -m)" in
  arm64) target='darwin-arm64' ;;
  x86_64) target='darwin-amd64' ;;
  *) echo '不支持此 Mac CPU 架构。' >&2; exit 1 ;;
esac
base='https://raw.githubusercontent.com/595911/meJD-encrypted-updates/main/bootstrap/v1'
umask 077
stage="$(mktemp -d "${TMPDIR:-/tmp}/mejd-public-install.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
curl -fsSL "$base/$target/mejd-updater" -o "$stage/mejd-updater"
curl -fsSL "$base/$target/mejd-updater.sha256" -o "$stage/mejd-updater.sha256"
expected="$(tr -d '\r\n' < "$stage/mejd-updater.sha256")"
[[ "$expected" =~ ^[0-9a-f]{64}$ ]] || { echo '安装程序摘要格式错误。' >&2; exit 1; }
actual="$(shasum -a 256 "$stage/mejd-updater" | awk '{print $1}')"
[[ "$actual" == "$expected" ]] || { echo '安装程序摘要不匹配。' >&2; exit 1; }
chmod 700 "$stage/mejd-updater"
"$stage/mejd-updater" --install-latest
"$stage/mejd-updater" --verify
if [[ "${MEJD_INSTALL_HEADLESS:-}" == 1 ]]; then exit 0; fi
load_dir="$HOME/.local/share/mejd-package-update/extension"
printf '%s' "$load_dir" | pbcopy
open -a 'Google Chrome' 'chrome://extensions' || true
open -R "$load_dir" || true
echo "Chrome 加载目录已复制到剪贴板：$load_dir"
echo '请开启开发者模式，点击“加载已解压的扩展程序”，选该目录。已有同 ID 扩展时先核对其数据，不要直接卸载。'
