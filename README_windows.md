# Windows 使用说明

> 本项目原本面向 Linux 桌面（`.deb` / `install.sh` / 桌面菜单项）。但它的 Python 层是纯跨平台的：
> 数据采集只用标准库，界面是 PyQt5 + `QPainter` 手绘、不依赖 Chromium。
> **所以在 Windows 上可以完整跑起来**，`run-win.bat` 就是为此准备的启动器。

## 快速开始

1. 确认本机有 Python 3.8 及以上：

   ```bat
   python -V
   ```

   没有的话去 <https://www.python.org/downloads/> 安装，**安装时勾选 “Add python.exe to PATH”**。
   （WorkBuddy 自带的 Python 也能用，`run-win.bat` 会自己找。）

2. 双击 `run-win.bat`。

3. 首次运行会自动准备环境，大约 1~3 分钟：

   ```
   [1/2] Creating Python environment ...
   [2/2] Installing PyQt5, about 60 MB, first run only ...
   ```

   装完面板会直接打开。以后每次双击就是一秒内出窗口，不再装东西。

## 方式二：单文件安装（`install-win.bat`）

如果只想「下载一个文件、双击、跑起来」，用 `install-win.bat`。它把整套流程包在一个文件里：

```
双击 install-win.bat
  → 找 Python 3.8+
  → 取源码（同目录有就用本地，没有就从 GitHub 下 zip）
  → 装到 %LOCALAPPDATA%\WorkBuddyTokenMonitor\app
  → 建虚拟环境 + 装 PyQt5（首次约 60 MB）
  → 桌面快捷方式
  → 启动面板
```

| 参数 | 作用 |
| --- | --- |
| `install-win.bat` | 完整安装并启动 |
| `--no-shortcut` | 不建桌面快捷方式 |
| `--no-run` | 只安装，不启动 |
| `--web` | 装好后启动 Web 面板而不是原生窗口 |

特点：

- **可重复运行**：装完再跑就是「更新/修复」，虚拟环境和已装的 PyQt5 会复用，不会重下。
- **离线可用**：把仓库文件夹和它放在一起，就直接用本地源码，不联网。
- **下载有兜底**：`curl` 优先，失败自动退回 PowerShell `Invoke-WebRequest`；两个 GitHub 地址依次尝试。
- **会自动打字体补丁**：如果源码里还没有字体验证逻辑（见下一节），安装器会就地把两个 Linux 字体名替换掉。

卸载：

```bat
rmdir /s /q "%LOCALAPPDATA%\WorkBuddyTokenMonitor"
```

删掉桌面快捷方式即可，`~/.workbuddy` 里的数据不受影响。

## 命令行用法

| 命令 | 作用 |
| --- | --- |
| `run-win.bat` | 打开原生桌面面板（默认） |
| `run-win.bat --web` | 启动本地服务并用浏览器打开 `http://127.0.0.1:8791` |
| `run-win.bat --stop` | 停掉 `--web` 模式启动的后台服务 |
| `run-win.bat --console` | 在前台控制台里运行，报错看得见（排障用） |

除上面四个开关外，其余参数原样透传给 `qt_app.py`，Linux 版支持的参数都能用：

```bat
run-win.bat --range 7d                          :: 今日 / yesterday / 7d / 30d / all
run-win.bat --model DeepSeek-V4.1-Flash         :: 启动时联动过滤某个模型
run-win.bat --demo                              :: 演示数据，不读真实记录
run-win.bat --shot out.png --range all          :: 离屏渲染一张截图后退出
```

换端口（`--web` 模式）：

```bat
set WB_MONITOR_PORT=9000
run-win.bat --web
```

## 它替你做了什么

原来的 `run.sh` 依赖一堆 Linux 专有工具，在 Windows 上完全用不了。对应关系：

| `run.sh` 依赖 | Windows 上的替代 |
| --- | --- |
| `bash` 脚本 | `run-win.bat`（纯 ASCII，无编码风险） |
| `nohup ... &` 后台起服务 | `start "" /b cmd /c` + 日志重定向 |
| `curl` 轮询 `/api/ping` 等就绪 | 同样用 `curl`（Win10 1803+ 自带），缺失时退化为等待 3 秒 |
| `notify-send` 报错提示 | 直接 `echo` + `pause`，双击窗口不会一闪而过 |
| `xdg-open` / Chrome `--app` | `start "" http://127.0.0.1:8791` 用默认浏览器 |
| `DISPLAY` / `WAYLAND_DISPLAY` 检查 | 无（Windows 没有这个概念） |
| `pkill` 停服务 | `netstat -ano` 找 PID + `taskkill` |
| `python3-pyqt5` 包 | `pip install PyQt5`（自动，带三个镜像回退） |

## 一个必须知道的坑：PyQt5 不能装在中文路径下

这是本次适配中唯一真正致命的坑，值得单独讲。

**现象**：环境装好后，一切看起来正常，但双击没有任何反应；或者 `python qt_app.py` 直接退出，
**退出码 `0xc0000409`，控制台一个字都不打印**，连 Qt 的调试日志都没有。

**原因**：Qt5 的 DLL 如果是从含中文（非 ASCII）的路径加载，在 `QApplication` 初始化阶段会 fail-fast。
事件查看器里只能看到 `故障模块 Qt5Core.dll`，不会告诉你真正原因。

**处理**：`run-win.bat` 把虚拟环境固定建在纯 ASCII 路径：

```
%LOCALAPPDATA%\WorkBuddyTokenMonitor\venv
```

而**项目本身放在中文目录是没问题的**（本项目就放在 `…\系统工具\workbuddy-token-monitor`，实测正常）。
只要别把虚拟环境建在中文目录里（例如 `项目\.venv`）就行。

**自检方法**：

```bat
run-win.bat --console
```

能看到输出说明正常；如果无输出直接返回，用 `echo %errorlevel%` 看到 `-1073740791`（即 `0xc0000409`），
就是踩到这个坑了。

## 字体：为什么 Windows 上原来又细又像宋体

原代码里字体是硬编码的 Linux 字体：

```python
f = QFont("Droid Sans Fallback")   # 正文
f = QFont("DejaVu Sans")           # 数字
```

Windows 上这两个字体都不存在，Qt 会**静默回退**——实测回退到了「宋体」（衬线体，横细竖粗）。
所以面板上的中文看起来发细、发灰，和 Linux 截图差别明显。

现在的处理（`qt_app.py` 内的 `_font_family`）：

1. 按候选列表挑一个本机真实存在的字体：
   `Droid Sans Fallback` → `Noto Sans SC` → `Source Han Sans SC` → `Microsoft YaHei UI` → `Microsoft YaHei` → `PingFang SC`
2. 如果不是原生 Droid，就把「常规」字重从 400 抬到 **Medium (500)**，抵消替代字体笔画偏细的问题。
   标题的 DemiBold 不受影响。

实测在 Windows 上解析到 `Noto Sans SC`（思源黑体），和 Linux 的 Droid 同属黑体系，观感一致。

想强行指定字体：

```bat
set WB_FONT=Microsoft YaHei UI
set WB_NUM_FONT=Consolas
run-win.bat
```

## 文件与目录

| 路径 | 说明 |
| --- | --- |
| `run-win.bat` | 源码目录内的启动器（新增） |
| `install-win.bat` | 单文件安装器（新增） |
| `README_windows.md` | 本文档（新增） |
| `.runtime\ui.json` | 字号、刷新间隔等界面偏好，删掉恢复默认 |
| `.runtime\server-win.log` | `--web` 模式的服务日志 |
| `%LOCALAPPDATA%\WorkBuddyTokenMonitor\venv` | 运行时虚拟环境，可随时整目录删除 |

`.runtime/` 和 `*.log` 已在 `.gitignore` 里，不会污染 `git status`。

## 常见问题

**双击后什么都没发生？**
用 `run-win.bat --console` 跑一遍，错误会留在窗口里。最常见的是没装 Python。

**提示 `Python 3.8+ was not found`？**
装 Python 并勾选 Add to PATH；或者确认 `where python` 能定位到解释器。
（Microsoft Store 的 python 占位符也会被识别出来并跳过，脚本会自动尝试 `py -3` 和 WorkBuddy 自带 Python。）

**PyQt5 装不上（卡在 Installing 或报网络错误）？**
脚本会依次尝试 阿里云 → 清华 → 官方 PyPI。三个都失败通常是公司网络限制，两个选择：

- 给 pip 配代理：在 `%APPDATA%\pip\pip.ini` 写
  ```ini
  [global]
  index-url = https://mirrors.aliyun.com/pypi/simple
  ```
- 或者直接放弃原生窗口，用 `run-win.bat --web` —— 服务端只用标准库，不需要装任何东西。

**为什么打开的是浏览器，不是原生窗口？**
说明 PyQt5 没装上，脚本自动降级到 Web 模式（和 Linux 版 `run.sh` 的行为一致）。

**面板里数据是空的？**
确认 `%USERPROFILE%\.workbuddy\projects` 下有 `*.jsonl` 会话记录，且当前用户有读权限。
这个工具只读该目录和 `%USERPROFILE%\.workbuddy\workbuddy.db`，不修改、不上传。

**端口 8791 被占用？**
`set WB_MONITOR_PORT=9000` 后重新运行。

**中文显示正常吗？**
正常。代码里写的是 Linux 字体 `Droid Sans Fallback`、`DejaVu Sans`，Windows 上没有这两个字体，
Qt 会自动回退到系统字体，实测无方框、无乱码，也不需要改代码。

**想开机自启？**
把 `run-win.bat` 的快捷方式放进 `shell:startup`（Win+R 输入 `shell:startup`）。
建议配合 `--web` 模式，常驻内存约 30 MB，不占前台。

## 与 Linux 版的功能差异

| 功能 | Windows |
| --- | --- |
| 原生桌面面板（PyQt5） | ✅ 可用 |
| 悬浮小窗（置顶卡片） | ✅ 可用 |
| Web 面板 + 快照导出 | ✅ 可用 |
| 时间范围 / 模型过滤 / 字号 / 吞吐窗口 | ✅ 可用 |
| `install.sh` 桌面菜单项 | ❌ 不适用（`.desktop` 文件是 Linux 概念） |
| `build_deb.sh` / `release.sh` | ❌ 不适用（deb 打包与 Linux 发版流程） |
| `stop.sh` (`pkill`) | ❌ 用 `run-win.bat --stop` |
| `setup_token.sh` | ❌ 不适用（GitHub 发版用，与运行无关） |

## 卸载 / 重置

```bat
rmdir /s /q "%LOCALAPPDATA%\WorkBuddyTokenMonitor"
```

只删运行时环境，**不会**碰 `~/.workbuddy` 里的任何数据。删完再双击 `run-win.bat` 会重新装一遍。
