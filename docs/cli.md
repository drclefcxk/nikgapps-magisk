# 命令行参考 / CLI reference

本页列出仓库中所有脚本的用法。构建流程与配置见 [build.md](build.md)，实现细节见 [architecture.md](architecture.md)。

## 1. `build.sh`

一键构建：复制模板 → 生成 `module.prop` → 转换载荷 → 打包。

```bash
./build.sh [NikGapps zip] [output zip]
```

| 参数 | 说明 |
| --- | --- |
| `NikGapps zip` | 可选，NikGapps 刷机包路径；省略时依次尝试 `.env` 的 `NIKGAPPS_ZIP_NAME`、目录下第一个 `NikGapps-*.zip` |
| `output zip` | 可选，输出路径；默认 `./<输入文件名去 .zip>-magisk.zip` |

示例：

```bash
./build.sh
./build.sh NikGapps-core-arm64-12-20241231-signed.zip
./build.sh NikGapps-core-arm64-12-20241231-signed.zip dist/NikGapps-core.zip
```

行为：

* 读取 `.env`（若存在）并导出变量；
* 输出固定为 `META-INF/` + `module.prop` + `customize.sh` + `system/`；
* 中间目录 `.build/module` 会被重建；
* 结束时输出 SHA-256 与产物路径。

## 2. `convert-nikgapps-to-magisk.sh`

只做“解包 + 路径映射”，不生成 `module.prop`，不打包。

```bash
./convert-nikgapps-to-magisk.sh <NikGapps zip> <module directory>
```

| 参数 | 说明 |
| --- | --- |
| `NikGapps zip` | 输入刷机包（`.zip`） |
| `module directory` | 输出模块目录，必须可写；其中的 `system/` 会被清空重建 |

要求：`bash` 4+、`unzip`、`tar`。脚本退出码非 0 表示失败，并会清理临时目录。

## 3. 路径映射规则 / Path mapping

NikGapps 包内路径以 `___` 编码，转换规则与其安装器一致：

| NikGapps 条目 | 模块内路径 |
| --- | --- |
| `___priv-app___Phonesky/Phonesky.apk` | `system/<默认分区>/priv-app/Phonesky/Phonesky.apk` |
| `___etc___permissions/foo.xml` | `system/<默认分区>/etc/permissions/foo.xml` |
| `___overlay/GmsConfigOverlayGSA.apk` | `system/product/overlay/GmsConfigOverlayGSA.apk` |
| `___system___etc___foo.conf` | `system/etc/foo.conf` |
| `___system_ext___priv-app___Gsf/Gsf.apk` | `system/system_ext/priv-app/Gsf/Gsf.apk` |

`<默认分区>` 的判定顺序：

1. `common/install.sh` 中的 `包名,大小,分区`；
2. 包内 `installer.sh` 的 `default_partition`；
3. `product`。

`installer.sh` / `uninstaller.sh` 会被跳过。

## 4. `tools/make_module_zip.py`

把已经准备好的模块目录打成 zip：

```bash
python3 tools/make_module_zip.py <module directory> <output zip>
```

* 要求目录中存在 `module.prop`；
* 忽略符号链接与空目录；
* 把 `META-INF/com/google/android/update-binary` 放在 zip 的第一个条目；
* 使用 deflate 压缩并打印文件数与大小。

## 5. `convert-opengappss-to-magisk.sh`（遗留 / legacy）

旧版转换器，用于 OpenGApps 刷机包（需要 `lzip`）：

```bash
./convert-opengappss-to-magisk.sh open_gapps-arm64-11.0-micro-20220215.zip ./magisk-template/system
```

它会把结果写入 `./magisk-template/system`，之后可以自行打包：

```bash
cd magisk-template
zip -r ../magisk-opengapps.zip .
```

脚本内的 `blacklist` 数组用于跳过某些包（例如 `setupwizard`、`gmssetup` 等可能造成无法开机的组件），可按需修改。当前的 NikGapps 流程不使用该脚本，也不使用该黑名单。

## 6. 常用片段 / Recipes

```bash
# 1) 构建并校验
./build.sh && unzip -tq ./*-magisk.zip

# 2) 只重建载荷（例如只改了 magisk-template）
./convert-nikgapps-to-magisk.sh NikGapps-core-arm64-12-20241231-signed.zip .build/module

# 3) 查看模块内容
unzip -l NikGapps-core-arm64-12-20241231-signed-magisk.zip

# 4) 检查生成/待发布的校验和
sha256sum ./*-magisk.zip
```
