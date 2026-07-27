# Repository Guidelines

## Project Overview

`jdk-man` 是一个面向 Windows 的轻量级 JDK 版本管理器，基于 PowerShell 7+ 构建。通过单条命令 `jdk` 即可注册、切换和移除多个 JDK 安装——无需管理员权限、无需 shell 覆盖层、极简设计。

## Architecture & Data Flow

```
jdk <command> [args]
  │
  ├─→ Get-JdkConfig()          # 读取 %LOCALAPPDATA%\jdk-man\jdk-config.json → hashtable
  │
  ├─ list    → 遍历 config，检测 bin\java.exe 是否存在，格式化输出表格
  ├─ current → 读取 $env:JAVA_HOME，匹配 config 找到版本键，对比 User 注册表判断作用域
  ├─ use     → $env:JAVA_HOME = path → Update-SessionPath → java -version
  ├─ default → [Environment]::SetEnvironmentVariable("JAVA_HOME", path, "User")
  │           → Ensure-UserPathHasJavaBin → Update-SessionPath → java -version
  ├─ add    → config[$ver] = path → Set-JdkConfig → 可选设为 default
  └─ remove → config.Remove($ver) → Set-JdkConfig
```

**两条关键路径：**
- **Session scope**（`use`）：仅修改当前进程环境变量，终端关闭即失效。
- **User scope**（`default`）：通过 `[Environment]::SetEnvironmentVariable(..., "User")` 写入注册表，新终端自动生效。同时确保 `%JAVA_HOME%\bin` 位于用户 PATH 首部。
**无 build system、无依赖、无测试框架**——所有逻辑集中在单个 `.psm1` 文件（~340 行）中。

## Key Directories

| 路径 | 用途 |
|------|------|
| `jdk-man.psm1` | 全部逻辑：config I/O、PATH 操作、子命令、tab 补全 |
| `jdk-man.psd1` | 模块清单：版本、导出函数、元数据 |
| `publish.ps1` | 发布到 PSGallery 的辅助脚本 |
| `.github/copilot-instructions.md` | GitHub Copilot 代码生成指令 |
| `README.md` / `README.zh-CN.md` | 中英双语文档 |

## Development Commands

无 build、test、lint 命令。开发流程即为直接编辑 `.psm1` 后重新导入：

```powershell
# 开发时反复导入（-Force 覆盖已有模块）
Import-Module .\jdk-man.psd1 -Force

# 手动测试各子命令
jdk current
jdk list
jdk default 21
jdk add 8 D:\path\to\jdk8
jdk remove 8

# 发布到 PSGallery（需 API Key）
./publish.ps1 -ApiKey <key>
```

## Code Conventions & Common Patterns

### 文件 I/O：必须使用 .NET 方法
使用 `[System.IO.File]::ReadAllText` / `WriteAllText` 配合 `[System.Text.UTF8Encoding]::new($false)`（UTF-8 no-BOM），**禁止** `Get-Content` / `Set-Content`。此举避免文件锁定问题。

### 错误处理：throw
致命错误（未知版本、无效路径）使用 `throw`，**禁止** `Write-Error` + `return`。

### 用户消息：Write-Host + 颜色语义
| 颜色 | 含义 |
|------|------|
| `Green` | 成功操作 |
| `Yellow` | 警告 / 持久化变更提醒 |
| `Gray` | 信息性消息（如配置已存在） |

### current 命令的作用域判定
`current` 读取 `$env:JAVA_HOME` 并在 config 中查找匹配版本。作用域判定逻辑：
- 对比 `[Environment]::GetEnvironmentVariable('JAVA_HOME', 'User')` 与 session `$env:JAVA_HOME`
- 两者路径一致 → `Persistent (User)`，否则 → `Session only`
- 未在 config 中找到匹配 → 标记为 `(unmanaged)`，仍显示路径和作用域

### PATH 去重
`Update-SessionPath` 函数会：
1. 收集 config 中所有已知 JDK 的 `bin` 目录
2. 移除匹配 `%JAVA_HOME%\bin` 或 `%JAVA_HOME%/bin` 模式的条目
3. 将新 bin 目录前置到 session PATH

**任何 session PATH 操作都必须经过此函数**。

### 校验关卡
JDK 路径有效的唯一标准：`<path>\bin\java.exe` 存在。`add`、`use`、`default` 三个命令均强制执行此校验。

### list 命令的 CJK 对齐
`list` 内部包含 `Pad-Right` 辅助函数，手动计算 CJK 字符（Unicode 范围 `\u4e00-\u9fff` 等）的显示宽度（每字符占 2 格），确保中文表头对齐。

### Tab 补全
通过 `Register-ArgumentCompleter` 为 `jdk` 的 `Version` 参数注册补全，从 config JSON 中读取版本键。

### 注释基于帮助
`jdk` 函数使用 PowerShell 注释基帮助（comment-based help）；无参数调用 `jdk` 等同于 `Get-Help jdk`。

## Important Files

| 文件 | 角色 |
|------|------|
| `jdk-man.psm1` | **唯一入口点和全部逻辑**。`Export-ModuleMember -Function jdk` 导出唯一公开函数。 |
| `jdk-man.psd1` | 模块清单。`RootModule = 'jdk-man.psm1'`，`PowerShellVersion = '7.0'`。 |
| `publish.ps1` | 将 `.psd1` + `.psm1` 复制到临时目录后调用 `Publish-PSResource -Repository PSGallery` 发布。 |
| `%LOCALAPPDATA%\jdk-man\jdk-config.json` | 运行时配置文件（运行时生成，仓库内不包含）。 `.gitignore` 已排除。 |

## Runtime/Tooling Preferences

- **Runtime**：PowerShell 7.0+（`pwsh.exe`），非 Windows PowerShell 5.x。
- **平台**：仅 Windows 10 / 11。
- **无包管理器、无 build tool**。
- **发布渠道**：PowerShell Gallery（`Publish-PSResource`）。

## Testing & QA

项目无自动化测试框架。验证方式为手动导入模块后在终端逐条测试各子命令。
