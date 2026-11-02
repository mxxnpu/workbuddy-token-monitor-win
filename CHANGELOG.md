# 更新记录

## v1.1.2-win1 — 2026-11-02

首个 Windows 发行版，基于上游
[workbuddy-token-monitor](https://github.com/The-garden-of-sinner/workbuddy-token-monitor) v1.1.2。

### 新增

- `install-win.bat`：单文件安装器。双击完成「找 Python → 取源码 → 建虚拟环境 →
  装 PyQt5 → 建桌面快捷方式 → 启动」，可重复运行做更新/修复。
- `run-win.bat`：源码目录内的启动器，支持 `--web` / `--stop` / `--console`，
  其余参数透传 `qt_app.py`。
- `README_windows.md`：Windows 安装、排障与差异说明。

### 修复

- **字体过细**：上游硬编码 `Droid Sans Fallback` / `DejaVu Sans`，Windows 上两者都不存在，
  Qt 静默回退到「宋体」（衬线、笔画细）。现改为按候选链解析本机可用字体
  （`Noto Sans SC` → `Source Han Sans SC` → `Microsoft YaHei UI` → `PingFang SC`），
  非原生字体时把常规字重抬到 Medium，观感与 Linux 版一致。
  可用 `WB_FONT` / `WB_NUM_FONT` 环境变量覆盖。

### 移除

- Linux 专用脚本：`build_deb.sh`、`release.sh`、`setup_token.sh`、
  `install.sh`、`run.sh`、`stop.sh`。

### 已知限制

- PyQt5 不能装在含中文的路径下，否则 `QApplication` 初始化会以 `0xc0000409`
  fail-fast 且无任何提示。安装器与启动器均把虚拟环境放在 ASCII 路径。
- `.bat` 必须使用 CRLF 换行，仓库已通过 `.gitattributes` 强制。
