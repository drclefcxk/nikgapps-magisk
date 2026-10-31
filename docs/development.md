# 开发指南 / Development guide

## 1. 目录结构 / Repository layout

```text
.
├── build.sh                          # 一键构建入口
├── convert-nikgapps-to-magisk.sh     # NikGapps 载荷转换器
├── convert-opengappss-to-magisk.sh   # 遗留：OpenGApps 转换器
├── tools/
│   └── make_module_zip.py            # 模块打包工具
├── magisk-template/                  # Magisk 模块骨架
│   ├── module.prop
│   ├── customize.sh
│   └── META-INF/com/google/android/
│       ├── update-binary             # Magisk 官方 module_installer.sh
│       └── updater-script            # "#MAGISK"
├── .env                              # 构建配置（下载地址、版本、模块 id）
├── .github/workflows/build.yml       # CI：下载 -> 构建 -> 发布
├── docs/                             # 文档
├── README.md
└── CHANGELOG.md
```

## 2. 环境准备 / Setup

```bash
# Debian/Ubuntu 示例
sudo apt-get install -y unzip tar python3 shellcheck   # shellcheck 可选
```

开发时常用的快速循环：

```bash
./build.sh && unzip -tq ./*-magisk.zip && unzip -l ./*-magisk.zip | tail -3
```

## 3. 修改转换逻辑 / Changing the converter

`convert-nikgapps-to-magisk.sh` 的关键函数：

| 函数 | 职责 |
| --- | --- |
| `map_entry_path` | `___` 路径解码与分区映射 |
| `read_default_partition` | 从 `installer.sh` 读取 `default_partition` |
| `extract_pkg_archive` | 解压单个包（`.zip` / `.tar.xz`） |

改动映射规则后请同步更新：

* [architecture.md](architecture.md) 第 2、3 节的表格；
* [cli.md](cli.md) 第 3 节的映射表。

注意 `set -euo pipefail` 与 `find -print0` 的配合：新增循环时仍应使用 `IFS= read -r -d ''`。

## 4. 修改模块模板 / Changing the template

`magisk-template/` 中：

* `module.prop`：直接刷模板时的默认信息；`build.sh` 会覆盖它。
* `customize.sh`：由 Magisk 安装器 `source`，**不要调用 `exit`**，也不要依赖 `set -e`。
* `update-binary`：保持为 Magisk 官方 `scripts/module_installer.sh` 的内容，不要加入自定义逻辑（Magisk App 安装时会用自带脚本覆盖它）。

## 5. 新增 NikGapps 变体 / Another NikGapps variant

1. 修改 `.env`：

   ```ini
   SOURCE_URL="<新的下载直链>"
   NIKGAPPS_ZIP_NAME="NikGapps-basic-arm64-13-20250101-signed.zip"
   RELEASE_VERSION="basic-arm64-13-20250101"
   ```

2. 运行 `./build.sh`。转换器会自动遍历 `AppSet/*/`，因此 `basic`、`omni`、`stock` 等多 AppSet 构建无需修改代码。
3. 检查是否出现新的分区或路径类型：

   ```bash
   unzip -l .build/module/system/product/... >/dev/null   # 或直接看构建日志
   ```

4. 如目标 Android 版本变化，同时更新 `magisk-template/customize.sh` 的 API 提示阈值。

## 6. 测试清单 / Test checklist

在提交前至少完成：

```bash
# 1) 语法检查
bash -n build.sh convert-nikgapps-to-magisk.sh
python3 -m py_compile tools/make_module_zip.py

# 2) 完整构建（应输出 49 个文件、约 80 MB）
./build.sh

# 3) zip 完整性与结构
unzip -tq ./*-magisk.zip
unzip -l ./*-magisk.zip | wc -l          # 49 个条目 + 表头

# 4) customize.sh 冒烟测试（用桩函数代替 Magisk 内置函数）
MODPATH="$PWD/.build/module" ARCH=arm64 API=31 sh -c '
  ui_print() { echo "$1"; }
  abort() { echo "abort: $1"; exit 1; }
  set_perm_recursive() { :; }
  . magisk-template/customize.sh
'
# 期望最后两行：
# - 9 app(s) will be mounted over /system at boot
# - Reboot to activate NikGapps

# 5) 可选：静态检查
shellcheck -S warning build.sh convert-nikgapps-to-magisk.sh
```

## 7. 提交规范 / Commit convention

采用简化的 [Conventional Commits](https://www.conventionalcommits.org/)：

```text
<type>(<scope>): <subject>

<body>
```

常用 `type`：`feat`、`fix`、`docs`、`build`、`chore`、`refactor`、`test`。
`scope` 示例：`converter`、`module`、`ci`、`template`。

示例：

```text
feat(converter): 支持 .tar.xz 形式的 NikGapps 包

- 复用 extract_pkg_archive()，按扩展名分派
- 补充 docs/cli.md 说明
```

## 8. 发布流程 / Release process

1. 更新 `.env` 中的 `RELEASE_VERSION`（与 NikGapps 版本保持一致，例如 `core-arm64-12-20241231`）。
2. 更新 [CHANGELOG.md](../CHANGELOG.md)。
3. 提交并推送 `main`；CI 会自动构建并以 `RELEASE_VERSION` 为 tag 创建 Release，附带 `nikgapps-magisk-<RELEASE_VERSION>.zip` 与 SHA256。
4. 本地验证过构建后，也可以打 git tag：

   ```bash
   git tag -a v0.1.0 -m "nikgapps-magisk v0.1.0"
   git push origin v0.1.0
   ```

## 9. Git 仓库说明 / About this repository

* 本仓库是**独立初始化**的仓库：从 `git init` 开始，历史被压缩为单个初始提交。
* 代码改编自 [opengapps-magisk](https://github.com/ic0xgkk/opengapps-magisk) 与
  [OpenGapps-For-Magisk-Converter](https://github.com/bavelee/OpenGapps-For-Magisk-Converter)，
  遵循 GPL-3.0，见 [README](../README.md) 与 [CHANGELOG](../CHANGELOG.md)。
* 远程仓库：`https://github.com/drclefcxk/nikgapps-magisk`（默认分支 `main`）：

  ```bash
  git remote add origin git@github.com:drclefcxk/nikgapps-magisk.git
  git push -u origin main --tags
  ```

* 提交身份（当前为仓库级配置）：

  ```bash
  git config user.name  "Your Name"
  git config user.email "you@example.com"
  git commit --amend --reset-author --no-edit     # 修正最近一次提交的作者
  ```

* 分支与版本：默认分支 `main`，发布版本使用 `v0.1.0` 形式的标签。
* 构建产物（`*.zip`、`.build/`）已被 `.gitignore` 忽略，不进入版本库。
