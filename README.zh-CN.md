# jdk-man

[English](./README.md) | [简体中文](./README.zh-CN.md)

一个面向 Windows 的轻量级 JDK 版本管理器，基于 PowerShell 7+ 构建。通过一条命令即可注册、切换和移除多个 Java Development Kit 安装——无需管理员提示、无需 shell 覆盖层、无需折腾。

```powershell
jdk use 17
java -version
```

---

## 功能特性

- **一条命令，多套 JDK** —— `list`、`current`、`use`、`default`、`add`、`remove`
- **两种作用域** —— `use` 仅切换当前会话；`default` 在 Windows 用户级别持久化 `JAVA_HOME` 与 `PATH`
- **Tab 补全** —— 子命令与版本键从配置文件自动补全
- **校验关卡** —— 仅接受真实存在 `bin\java.exe` 的路径
- **PATH 安全** —— 在前置新 `bin` 前会清除旧 JDK `bin` 条目，不会累积重复项
- **零依赖** —— 纯 PowerShell，无原生二进制，无构建步骤

## 环境要求

- Windows 10 / 11
- PowerShell 7.0 或更高版本（`pwsh`）
- 磁盘上至少已安装一个 JDK

## 安装

### 从 PowerShell Gallery 安装

```powershell
Install-Module -Name jdk-man -Repository PSGallery
```

### 从源码安装

克隆仓库并直接导入模块：

```powershell
git clone https://github.com/sodekim/jdk-man.git
Import-Module .\jdk-man\jdk-man.psd1
```

若希望永久生效，将 `jdk-man.psd1` 与 `jdk-man.psm1` 复制到 `$env:PSModulePath` 中的任一目录（例如 `~\Documents\PowerShell\Modules\jdk-man`）。

## 快速上手

```powershell
# 注册一个已存在于磁盘上的 JDK
jdk add 17 D:\sdk\jdk\jdk-17.0.18+8

# 查看当前激活的 JDK 版本及作用域
jdk current

# 列出所有已配置版本（当前激活版本以 * 标记）
jdk list

# 仅切换当前会话
jdk use 17

# 设置跨新终端生效的持久默认版本
jdk default 21

# 从配置中移除某版本
jdk remove 8
```

## 命令一览

| 命令                 | 作用域             | 说明                                                                        |
| -------------------- | ----------------- | --------------------------------------------------------------------------- |
| `jdk list`           | 只读              | 打印所有已配置版本及其可用性状态。                                           |
| `jdk current`       | 只读              | 显示当前激活的 JDK 版本、路径和作用域（会话或持久化），以及配置注册信息和 `java -version` 输出。 |
| `jdk use <ver>`      | 当前会话          | 设置 `JAVA_HOME`，并将 `<jdk>\bin` 前置到当前会话的 `PATH`。                  |
| `jdk default <ver>`  | 用户级（持久化）  | 在用户级别设置 `JAVA_HOME`，并确保 `%JAVA_HOME%\bin` 存在于用户 `PATH` 中。同时作用于当前会话。 |
| `jdk add <ver> <path>` | 配置            | 注册一个 JDK 根目录（必须包含 `bin\java.exe`），随后提示是否设为默认版本；若版本已存在会先警告再覆盖。 |
| `jdk remove <ver>`   | 配置              | 从配置中移除某版本。若该版本是当前激活的 `JAVA_HOME`，会给出警告。              |

> [!NOTE]
> `use` 仅影响当前 shell，关闭终端即失效。`default` 写入用户环境变量——新开终端会自动生效。

## 配置

所有状态保存在一个 JSON 文件中：

```
%LOCALAPPDATA%\jdk-man\jdk-config.json
```

文件是一个 `版本 → JDK 根路径` 的扁平映射，首次运行时会自动创建为 `{}`。

```json
{
  "8":  "D:\\sdk\\jdk\\jdk-1.8.0_421",
  "17": "D:\\sdk\\jdk\\jdk-17.0.18+8",
  "21": "D:\\sdk\\jdk\\jdk-21.0.5+11"
}
```

你也可以手动编辑此文件 —— `jdk-man` 每次调用都会重新读取，丢弃解析失败的条目；若整个文件损坏，会先备份为 `jdk-config.json.bak` 再重置。

## 发布

仓库附带一个 `release.ps1` 脚本，供维护者使用：

```powershell
$env:POWERSHELL_GALLERY_API_KEY = "<PSGallery-API-key>"
./release.ps1 -Version "1.0.1"
```

它会更新模块清单中的版本号并提交该变更、创建 git tag、将清单和模块暂存到临时目录后调用 `Publish-PSResource` 发布到 PSGallery，并推送 git tag 到远程仓库——每一步 git 操作失败都会中止发布。`Publish-PSResource` 随 PowerShell 7.4+ 内置（`Microsoft.PowerShell.PSResourceGet` 模块）；更早的 7.x 需先安装该模块。

## 许可证

[MIT](./LICENSE) — © sodekim.