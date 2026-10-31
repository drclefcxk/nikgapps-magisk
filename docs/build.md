# 构建与发布 / Building & releasing

## 1. 环境要求 / Requirements

| 工具 | 用途 |
| --- | --- |
| `bash` 4+ | 构建与转换脚本（使用关联数组） |
| `unzip` | 解压 NikGapps 与其中的应用包 |
| `tar`（含 xz） | 处理 `.tar.xz` 形式的 NikGapps 包 |
| `python3` | 打包模块 zip（`tools/make_module_zip.py`） |

构建过程大约需要 **500 MB** 临时空间（解压后的 NikGapps、载荷与最终 zip），一次构建通常十几秒。

## 2. 本地构建 / Local build

把 NikGapps 刷机包放在仓库目录（或任意路径），然后：

```bash
# 使用默认输出名 <NikGapps 文件名>-magisk.zip
./build.sh NikGapps-core-arm64-12-20241231-signed.zip

# 指定输出路径
./build.sh NikGapps-core-arm64-12-20241231-signed.zip ./out/module.zip

# 不带参数：读取 .env 的 NIKGAPPS_ZIP_NAME，否则选择目录下第一个 NikGapps-*.zip
./build.sh
```

一次成功构建的输出示例：

```text
==> Source   : /home/user/nikgapps-magisk/NikGapps-core-arm64-12-20241231-signed.zip
==> Version  : core-arm64-12-20241231 (code 20241231)
==> Extracting NikGapps-core-arm64-12-20241231-signed.zip
[CONVERT] Core/ExtraFiles              -> system/product    (36 files)
[CONVERT] Core/GmsCore                 -> system/product    (3 files)
...
==> Converted 6 package(s), 45 file(s)
==> Payload size: 177M
==> Packed 49 files (176.4 MiB unpacked) -> .../NikGapps-core-arm64-12-20241231-signed-magisk.zip (79.8 MiB)
==> SHA-256  : ...
==> Output   : ...
```

构建中间产物（解压后的模块目录）保留在 `.build/module`，便于检查；该目录已被 `.gitignore` 忽略。

## 3. 配置 / Configuration (`.env`)

`build.sh` 会在启动时读取 `.env`：

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `SOURCE_URL` | SourceForge 上的 core-arm64-12 包 | CI 下载地址 |
| `NIKGAPPS_ZIP_NAME` | `NikGapps-core-arm64-12-20241231-signed.zip` | 本地/CI 文件与模块名 |
| `RELEASE_VERSION` | `core-arm64-12-20241231` | 写入 `module.prop` 的 `version`，同时作为 Release tag |
| `MODULE_ID` | `nikgapps-magisk` | 模块 id（`^[a-zA-Z][a-zA-Z0-9._-]+$`） |
| `MODULE_NAME` | `NikGapps for Magisk` | 模块显示名 |

> 值建议使用引号，例如 `MODULE_NAME="NikGapps for Magisk"`，因为 `build.sh` 会直接 `source` 该文件。

## 4. 版本号规则 / Versioning

`build.sh` 从 NikGapps 文件名解析版本：

```text
NikGapps-<variant>-<arch>-<android>-<YYYYMMDD>[-signed].zip
         core     arm64  12        20241231
```

* `version` = `core-arm64-12-20241231`（或 `RELEASE_VERSION`）
* `versionCode` = `20241231`（文件名中的日期，必须是整数）

更换 NikGapps 版本时，只需更新 `.env` 的 `SOURCE_URL`、`NIKGAPPS_ZIP_NAME`、`RELEASE_VERSION` 三项。

## 5. 校验产物 / Verify the artifact

```bash
# zip 完整性
unzip -tq NikGapps-core-arm64-12-20241231-signed-magisk.zip

# 文件清单（应为 49 个文件：4 个模块文件 + 45 个载荷文件）
unzip -l NikGapps-core-arm64-12-20241231-signed-magisk.zip

# 校验和
sha256sum NikGapps-core-arm64-12-20241231-signed-magisk.zip
```

期望的顶层结构：

```text
META-INF/com/google/android/update-binary
META-INF/com/google/android/updater-script
customize.sh
module.prop
system/product/...
system/system_ext/...
```

## 6. 只运行转换器 / Converter only

```bash
./convert-nikgapps-to-magisk.sh <NikGapps zip> <module directory>
```

`<module directory>` 必须已存在，脚本会：

1. 删除并重建其中的 `system/`；
2. 按 [architecture.md](architecture.md) 的规则写入载荷；
3. 打印每个包的目标分区与文件数。

手动搭建一个模块目录：

```bash
rm -rf .build && mkdir -p .build/module
cp -a magisk-template/. .build/module/
printf 'id=nikgapps-magisk\nname=NikGapps for Magisk\nversion=test\nversionCode=1\nauthor=me\ndescription=local test\n' \
  > .build/module/module.prop
./convert-nikgapps-to-magisk.sh NikGapps-core-arm64-12-20241231-signed.zip .build/module
python3 tools/make_module_zip.py .build/module ./test-module.zip
```

## 7. CI / GitHub Actions

工作流：[`.github/workflows/build.yml`](../.github/workflows/build.yml)

* **触发**：`push` 到 `main`、针对 `main` 的 `pull_request`、手动 `workflow_dispatch`
* **步骤**：
  1. `actions/checkout@v4`
  2. 安装 `unzip zip curl python3`
  3. 从 `.env` 导出 `SOURCE_URL` / `NIKGAPPS_ZIP_NAME` / `RELEASE_VERSION`
  4. `curl` 下载 NikGapps
  5. `./build.sh` 构建 `nikgapps-magisk-<RELEASE_VERSION>.zip`
  6. 生成含 SHA256 与 SourceURL 的 Release 说明
  7. `softprops/action-gh-release@v2` 以 `RELEASE_VERSION` 为 tag 发布（PR 跳过）
* **权限**：工作流声明 `permissions: contents: write`，使用仓库自带的 `GITHUB_TOKEN`。

> SourceForge 下载偶尔失败时，可重跑工作流，或把 `SOURCE_URL` 换成镜像/直链。

## 8. 常见构建问题 / Troubleshooting

| 现象 | 原因 / 解决 |
| --- | --- |
| `bash: 4 or newer is required` | 使用系统自带旧 bash（如 macOS 3.2），安装 bash 4+ 后重试 |
| `does not look like a NikGapps build (AppSet/ is missing)` | 输入的不是 NikGapps zip，或下载到的是 HTML 错误页 |
| `unzip: cannot find zipfile directory` | 下载不完整，删除后重新下载 |
| `No package could be converted` | zip 结构异常，或所有包都被过滤；检查 `AppSet/` 内容 |
| 磁盘空间不足 | 预留 ≥ 1 GB 空间后重试 |
| CI 发布 403 | 仓库 Settings → Actions → Workflow permissions 设为 *Read and write* |
