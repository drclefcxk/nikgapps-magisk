# nikgapps-magisk

把 [NikGapps](https://sourceforge.net/projects/nikgapps/files/) 刷机包打包成免系统修改的 [Magisk](https://github.com/topjohnwu/Magisk) 模块。
Package [NikGapps](https://sourceforge.net/projects/nikgapps/files/) as a systemless [Magisk](https://github.com/topjohnwu/Magisk) module.

本项目改编自 [opengapps-magisk](https://github.com/ic0xgkk/opengapps-magisk)（ic0xgkk / Bave Lee），把原本面向 OpenGApps 的转换流程改为面向 NikGapps。
Adapted from [opengapps-magisk](https://github.com/ic0xgkk/opengapps-magisk) (ic0xgkk / Bave Lee); the pipeline now targets NikGapps.

发布包 / Releases: [github.com/drclefcxk/nikgapps-magisk/releases](https://github.com/drclefcxk/nikgapps-magisk/releases)

## 介绍 / Introduction

NikGapps 只提供 recovery 刷机包，从 Magisk App 刷入时会直接提示 *“NikGapps cannot be flashed as a module!”* 并退出。本项目解析 NikGapps 的 `AppSet/*/*.zip`，按官方安装器相同的规则还原 `/system`、`/system_ext`、`/product` 目录，再按 Magisk 模块规范重新打包。

NikGapps only ships recovery flashable zips and aborts when flashed from the Magisk app. This project unpacks `AppSet/*/*.zip`, restores the same `/system`, `/system_ext` and `/product` layout the official installer produces, and repacks it as a Magisk module.

## 特性 / Features

* 在 Magisk App 内直接刷入，无需 TWRP / flash from the Magisk app, no TWRP required
* 不写入 `/system`，magic mount 生效，可随时停用或卸载 / nothing is written to `/system`; disable or remove the module to revert
* 路径映射与 NikGapps 安装器保持一致，可复现、可审查 / same path mapping as the official installer
* 一条命令构建，GitHub Actions 自动构建与发布 / one-command build with CI
* 完整文档：架构、构建、CLI、兼容性、开发指南 / full documentation set

## 快速开始 / Quick start

### 1. 构建 / Build

```bash
# 依赖：bash 4+、unzip、tar（xz）、python3
./build.sh NikGapps-core-arm64-12-20241231-signed.zip

# 产物（输出到当前目录）
# => NikGapps-core-arm64-12-20241231-signed-magisk.zip
```

不带参数时自动使用 `.env` 中的 `NIKGAPPS_ZIP_NAME`，或目录下第一个 `NikGapps-*.zip`。

### 2. 刷入 / Flash

1. 把生成的 zip 传到设备 / copy the zip to the device
2. Magisk App → 模块 → 从本地安装 / Modules → Install from storage
3. 重启 / reboot
4. 首次开机后打开 Play 商店完成初始化 / open the Play Store once

## 文档 / Documentation

| 文档 | 内容 |
| --- | --- |
| [docs/architecture.md](docs/architecture.md) | NikGapps 包结构、路径映射算法、模块结构、开机挂载原理 |
| [docs/build.md](docs/build.md) | 本地构建、`.env` 配置、版本号规则、CI 与发布、构建排错 |
| [docs/cli.md](docs/cli.md) | `build.sh`、转换器、打包脚本与遗留 OpenGApps 脚本的命令行参考 |
| [docs/compatibility.md](docs/compatibility.md) | 支持范围、已知限制、故障排除、禁用/卸载/回滚 |
| [docs/development.md](docs/development.md) | 仓库结构、修改指南、测试清单、提交规范、发布流程 |
| [CHANGELOG.md](CHANGELOG.md) | 变更记录 |

## 项目结构 / Layout

```text
.
├── build.sh                          # 一键构建
├── convert-nikgapps-to-magisk.sh     # NikGapps -> system/<partition>/... 转换器
├── convert-opengappss-to-magisk.sh   # 遗留：OpenGApps 转换器
├── tools/make_module_zip.py          # 模块打包工具
├── magisk-template/                  # 模块骨架（module.prop / customize.sh / META-INF）
├── .env                              # 下载地址、版本、模块 id
├── .github/workflows/build.yml       # CI：下载 -> 构建 -> 发布
└── docs/                             # 文档
```

生成的模块：

```text
META-INF/com/google/android/{update-binary,updater-script}
module.prop
customize.sh
system/product/...        # GMS、Play 商店、同步适配器、overlay、权限白名单 ...
system/system_ext/...     # GoogleServicesFramework ...
```

## 注意事项 / Notes

* 仅支持 **arm64**；模块与 NikGapps 构建的 Android 版本绑定（示例为 Android 12 / API 31）。
* 需要 **Magisk 20.4+**（挂载 `system/product`、`system/system_ext`）。
* 安装占用 `/data` 约 180 MB。
* 模块不会删除 ROM 中已有的 Google 应用；如果 ROM 自带 GMS，请先移除以免冲突。
* 与 recovery 版 NikGapps 的差异详见 [docs/compatibility.md](docs/compatibility.md)；移除/停用模块后的数据行为见该文档第 6 节。

## 感谢 / Thanks

* [NikGapps](https://sourceforge.net/projects/nikgapps/files/) — Nikhil Menghani
* [Magisk](https://github.com/topjohnwu/Magisk)
* 原始 OpenGApps 转换项目 / original OpenGApps converters:
  * [opengapps-magisk](https://github.com/ic0xgkk/opengapps-magisk) — ic0xgkk
  * [OpenGapps-For-Magisk-Converter](https://github.com/bavelee/OpenGapps-For-Magisk-Converter) — Bave Lee

## License 许可证

> nikgapps-magisk is free software: you can redistribute it and/or modify it
> under the terms of the GNU General Public License as published by the Free
> Software Foundation, either version 3 of the License, or (at your option)
> any later version.
>
> This program is distributed in the hope that it will be useful, but WITHOUT
> ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
> FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
> more details.
>
> You should have received a copy of the GNU General Public License along with
> this program. If not, see <http://www.gnu.org/licenses/>.

原始 OpenGApps 转换脚本 Copyright (C) Bave Lee / ic0xgkk，依据 GPL-3.0 使用。
