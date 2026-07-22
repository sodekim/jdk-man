# jdk-man

Windows JDK 版本管理工具。一个轻量的 PowerShell 7+ 模块，让你在多个 JDK 安装之间快速切换。

## 功能

- **会话级切换** — `jdk use` 仅影响当前终端窗口，关闭即恢复
- **持久化默认版本** — `jdk default` 写入用户级 `JAVA_HOME`，重启后依然生效
- **版本注册与移除** — `jdk add` / `jdk remove` 管理已安装的 JDK
- **Tab 补全** — 输入 `jdk use <Tab>` 自动列出已配置的版本
- **活跃版本标记** — `jdk list` 中用 `*` 标记当前生效的版本

## 环境要求

- Windows 10 / 11
- [PowerShell 7+](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows)（`pwsh`）

## 安装

```powershell
Install-Module -Name jdk-man
```

安装后 `jdk` 命令即可直接使用（模块自动加载，无需重启或手动导入）。

## 使用

### 注册 JDK

```powershell
jdk add 17 D:\sdk\jdk\jdk-17.0.18+8
```

路径必须包含 `bin\java.exe`，否则会被拒绝。注册完成后会提示是否将其设为默认版本。

### 列出已配置版本

```powershell
jdk list
```

输出示例：

```
Available JDK versions (from C:\Users\sodekim\AppData\Local\jdk-man\jdk-config.json):
* 17 - D:\sdk\jdk\jdk-17.0.18+8 [OK]
  8  - D:\sdk\jdk\jdk8u482-b08  [OK]
```

`*` 表示当前会话的活跃版本，`[MISSING]` 表示路径已失效。

### 临时切换（当前会话）

```powershell
jdk use 8
```

仅修改当前终端窗口的 `JAVA_HOME` 和 `PATH`，关闭窗口后自动恢复。

### 设置默认版本（永久）

```powershell
jdk default 17
```

将用户级 `JAVA_HOME` 持久化为指定版本，并确保用户 `PATH` 中包含 `%JAVA_HOME%\bin`。新开的终端窗口将自动使用该版本。

### 移除版本

```powershell
jdk remove 8
```

从配置中删除指定版本。如果该版本恰好是当前 `JAVA_HOME`，会输出警告但不阻止删除。

### 查看帮助

```powershell
jdk          # 无参数时显示帮助
Get-Help jdk # PowerShell 原生帮助
```

## 配置文件

配置存储在 `%LOCALAPPDATA%\jdk-man\jdk-config.json`，格式为扁平的 JSON 键值对：

```json
{"17":"D:\\sdk\\jdk\\jdk-17.0.18+8","8":"D:\\sdk\\jdk\\jdk8u482-b08"}
```

- **键**：自定义的版本标识（如 `8`、`17`、`21`、`graalvm-21`）
- **值**：JDK 根目录的绝对路径

首次运行任意命令时，配置文件会自动创建为 `{}`。

## 命令速查

| 命令 | 说明 |
|---|---|
| `jdk list` | 列出所有已配置版本及状态 |
| `jdk use <ver>` | 当前会话临时切换 |
| `jdk default <ver>` | 永久设置用户级默认版本 |
| `jdk add <ver> <path>` | 注册一个 JDK 安装路径 |
| `jdk remove <ver>` | 从配置中移除一个版本 |
