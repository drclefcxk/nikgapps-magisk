# Changelog

本项目的所有重要变更记录在此文件。格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [0.1.0] - 2026-11-01

首个 NikGapps 适配版本，基于 NikGapps `core-arm64-12-20241231`。

### Added

- `convert-nikgapps-to-magisk.sh`
  - 解析 `common/install.sh` 与包内 `installer.sh`，得到「包 → 分区」映射；
  - 把 `___` 编码路径还原为 `system/<partition>/<path>`，`overlay/` 归入 `system/product/overlay/`；
  - 支持 `AppSet/*/*.zip` 与 `.tar.xz`，跳过 `installer.sh` / `uninstaller.sh`；
  - bash 4+ 检查、临时目录自动清理、逐包转换日志。
- `build.sh`：一键复制模板、生成 `module.prop`、转换载荷、打包并输出 SHA-256。
- `tools/make_module_zip.py`：按 Magisk 规范打包，`update-binary` 置于 zip 首条。
- `magisk-template/customize.sh`：arm64 校验、API 提示、权限设置与安装信息。
- `magisk-template/module.prop`：`id=nikgapps-magisk`、`minMagisk=20400`，`support` 指向本项目仓库。
- `docs/`：architecture / build / cli / compatibility / development 文档。
- `CHANGELOG.md`、`.gitattributes`（强制脚本使用 LF）、`.gitignore`（忽略构建产物与 `*.zip`）。

### Changed

- `magisk-template/META-INF/com/google/android/update-binary` 更新为 Magisk 官方 `module_installer.sh`（要求 Magisk 20.4+）。
- `.env` 改为 NikGapps 的 `SOURCE_URL` / `NIKGAPPS_ZIP_NAME` / `RELEASE_VERSION` / `MODULE_ID` / `MODULE_NAME` / `MODULE_AUTHOR` / `MODULE_SUPPORT`。
- `.github/workflows/build.yml` 改为下载 NikGapps 并调用 `build.sh`；升级到 `actions/checkout@v4`、`softprops/action-gh-release@v2`，补充 `permissions: contents: write`。
- `README.md` 重写为 NikGapps 流程，并加入文档导航。

### Removed

- 旧 Magisk 模板 `magisk-template/config.sh`、`magisk-template/common/`（legacy `install.sh` 风格，已由 `customize.sh` 取代）。
- 仓库中的 `.DS_Store` 文件。
- `usage.md`：内容并入 `docs/cli.md`。

### Notes

- 原始 OpenGApps 转换项目的作者 ic0xgkk、Bave Lee 的署名保留在脚本头、[README](README.md) 与本文件（GPL-3.0 要求保留版权声明）。
- 与 recovery 版 NikGapps 的差异（不删除 ROM 文件、无 `addon.d`/debloat、`nikgapps.config` 不生效）见 [docs/compatibility.md](docs/compatibility.md)。
- 移除模块后的数据行为与“残留的 Play 商店/服务”见 [docs/compatibility.md](docs/compatibility.md) 第 6 节。
- 保留 `convert-opengappss-to-magisk.sh` 作为 OpenGApps 遗留支持。

## 代码基线 / Code base

- 改编自 [opengapps-magisk](https://github.com/ic0xgkk/opengapps-magisk)（2022-02-20 `4994f9a`）
  与 [OpenGapps-For-Magisk-Converter](https://github.com/bavelee/OpenGapps-For-Magisk-Converter)，
  遵循 GPL-3.0。
- 本仓库为独立初始化的仓库，不包含上游提交历史。
