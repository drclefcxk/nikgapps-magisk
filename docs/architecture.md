# 架构与实现原理 / Architecture

本文说明 NikGapps 刷机包的结构、转换器的路径映射规则，以及生成的 Magisk 模块在设备上如何生效。
This document describes the NikGapps package layout, the converter rules, and how the resulting Magisk module works on-device.

- 转换器：`convert-nikgapps-to-magisk.sh`
- 构建入口：`build.sh`
- 模块模板：`magisk-template/`

## 1. 输入：NikGapps 刷机包 / Input: NikGapps zip

```text
NikGapps-core-arm64-12-20241231-signed.zip
├── AppSet/
│   └── Core/
│       ├── GmsCore.zip
│       ├── GooglePlayStore.zip
│       ├── GoogleServicesFramework.zip
│       ├── GoogleContactsSyncAdapter.zip
│       ├── GoogleCalendarSyncAdapter.zip
│       └── ExtraFiles.zip
├── common/
│   ├── install.sh              # AppSet -> 包列表 -> 分区
│   ├── nikgapps_functions.sh   # 安装器函数（install_file 等）
│   ├── mount.sh
│   └── ...
├── afzc/
│   ├── nikgapps.config         # 需要刷入哪些包的开关
│   └── debloater.config
├── customize.sh                # NikGapps 自带安装逻辑（BOOTMODE 时直接退出）
├── module.prop                 # NikGapps 自带的“假模块”信息
├── busybox
└── META-INF/
```

要点：

1. **每个应用包都是独立压缩包**：`AppSet/<AppSet>/<Package>.zip`，本项目同时支持 `.tar.xz` 形式的包。
2. **`common/install.sh` 决定分区**：其中以 `包名,大小,分区` 的形式列出每个包，例如：

   ```sh
   Core="
   GoogleServicesFramework,7415,system_ext
   GooglePlayStore,53834,product
   GoogleContactsSyncAdapter,2817,product
   GoogleCalendarSyncAdapter,2451,product
   GmsCore,117303,product
   ExtraFiles,1120,product
   "

   install_app_set "Core" "$Core" ".zip"
   ```

3. **包内 `installer.sh` 描述安装细节**：`default_partition`、`file_list`、需要清理的 AOSP 应用等。
4. **顶层 `module.prop` / `customize.sh` 不是我们要用的模块**：NikGapps 借它们让 Magisk App 能识别 zip，但 `customize.sh` 在 `BOOTMODE` 下会直接提示 *“NikGapps cannot be flashed as a module! Flash it via recovery...”* 并退出。本项目不使用这些文件。

## 2. 包内路径编码 / Encoded paths

NikGapps 包内的文件路径用 `___` 作为分隔符并以前导 `___` 表示“相对于分区根”：

```text
___priv-app___PrebuiltGmsCore/PrebuiltGmsCoreSc.apk
        │
        └── priv-app/PrebuiltGmsCore/PrebuiltGmsCoreSc.apk
```

NikGapps 安装器 `install_file()` 的处理顺序（本项目保持一致）：

| 首段 | 含义 | 目标位置 |
| --- | --- | --- |
| `system` / `system_ext` / `product` / `vendor` | 显式指定分区 | `/<首段>/<其余路径>` |
| `overlay` | 产品 overlay | `/product/overlay/<其余路径>`（`PRODUCT_BLOCK` 设备为 `/product`） |
| 其他 | 使用包的默认分区 | `/<默认分区>/<路径>` |

`installer.sh` 与 `uninstaller.sh` 属于 NikGapps 的安装逻辑，不会进入模块。

## 3. 分区从哪来 / Where the partition comes from

转换器按以下优先级决定一个包的默认分区：

1. `common/install.sh` 中的 `包名,大小,分区` 行（最权威）；
2. 包内 `installer.sh` 的 `default_partition="..."`；
3. 兜底 `product`。

对 `NikGapps-core-arm64-12-20241231` 的实际结果：

| 包 | 分区 |
| --- | --- |
| `GoogleServicesFramework` | `system_ext` |
| `GooglePlayStore` | `product` |
| `GoogleContactsSyncAdapter` | `product` |
| `GoogleCalendarSyncAdapter` | `product` |
| `GmsCore` | `product` |
| `ExtraFiles` | `product` |

> 上游 NikGapps 在 Android 10 及以下会把 `system_ext` 回退到 `product`。本项目按目标 Android 版本构建（当前为 Android 12），因此保留 `system_ext`；`customize.sh` 会在 API < 31 时给出警告。

## 4. 转换算法 / Conversion algorithm

```text
1. 解压 NikGapps zip 到临时目录
2. 解析 common/install.sh -> 包名到分区的映射
3. 遍历 AppSet/*/*.{zip,tar.xz}
   ├─ 解压单个包
   ├─ 读取 installer.sh / install.sh 得到默认分区
   └─ 对包内每个文件：
        ├─ 跳过 installer.sh / uninstaller.sh
        ├─ 解码 ___ 路径
        ├─ 按第 2、3 节规则得到 system/<partition>/<path>
        └─ 拷贝到 <module>/system/<partition>/<path>
4. build.sh 生成 module.prop、设置权限
5. tools/make_module_zip.py 打包成模块 zip
```

转换结果示例：

```text
<module>/
├── module.prop
├── customize.sh
├── META-INF/com/google/android/{update-binary,updater-script}
└── system/
    ├── product/
    │   ├── app/GoogleCalendarSyncAdapter/...
    │   ├── app/GoogleContactsSyncAdapter/...
    │   ├── etc/{default-permissions,firmware,permissions,preferred-apps,security,sysconfig}/...
    │   ├── framework/*.jar
    │   ├── lib64/libgdx.so
    │   ├── overlay/Gms*.apk
    │   └── priv-app/{Phonesky,PrebuiltGmsCore,m_independent}/...
    └── system_ext/
        ├── etc/permissions/com.google.android.gsf.xml
        └── priv-app/GoogleServicesFramework/...
```

## 5. 生成的 Magisk 模块 / The generated module

```text
module.zip
├── META-INF/com/google/android/update-binary   # Magisk 官方 module_installer.sh
├── META-INF/com/google/android/updater-script  # 仅包含 "#MAGISK"
├── module.prop                                 # 模块元数据
├── customize.sh                                # 安装时被 source
└── system/...                                  # 载荷
```

### module.prop

由 `build.sh` 根据 NikGapps 文件名生成：

| 字段 | 取值 | 说明 |
| --- | --- | --- |
| `id` | `nikgapps-magisk`（可用 `MODULE_ID` 覆盖） | 模块唯一标识 |
| `name` | `NikGapps for Magisk`（可用 `MODULE_NAME` 覆盖） | 显示名称 |
| `version` | `core-arm64-12-20241231`（`RELEASE_VERSION` 或文件名） | 版本字符串 |
| `versionCode` | `20241231`（文件名中的日期） | 必须是整数 |
| `minMagisk` | `20400` | 挂载 `system/product`、`system/system_ext` 需要 Magisk 20.4+ |

### 安装流程

Magisk 的 `install_module`（`/data/adb/magisk/util_functions.sh`）大致执行：

1. 从 zip 中读取 `module.prop`，确定 `MODID` 与 `$MODPATH=/data/adb/modules/<id>`；
2. 解压 zip（排除 `META-INF/`）到 `$MODPATH`；
3. 用 `set_perm_recursive` 设置 `u:object_r:system_file:s0` 与 `0755/0644`；
4. `source $MODPATH/customize.sh`（若存在）；
5. 处理 `REPLACE` / `REMOVE`（本项目未使用）；
6. 清理 `customize.sh` 等安装期文件。

我们的 `customize.sh` 只做三件事：检查架构、按 API 提示、打印将挂载的应用数量。

### 开机挂载

Magisk 的 magic mount 会在 `post-fs-data` 阶段把 `$MODPATH/system` 递归合并到 `/system`。按照 Magisk 官方文档，**`/product`、`/system_ext`、`/vendor` 的内容要放在 `system/product`、`system/system_ext`、`system/vendor` 下**，Magisk 会透明处理这些分区是否为独立分区，因此本模块不需要关心设备是否使用动态分区。

## 6. 与 recovery 版 NikGapps 的差异 / Differences from recovery NikGapps

| 行为 | NikGapps recovery 版 | 本项目（Magisk 模块） |
| --- | --- | --- |
| 写入 `/system` 等分区 | 是 | 否，magic mount 覆盖 |
| 删除 ROM 中冲突的 AOSP/GMS 应用 | 是（`remove_aosp_apps_from_rom`） | 否 |
| `nikgapps.config` 选择包 / debloat | 是 | 否，构建时固定 |
| `addon.d` 与 OTA 自动恢复 | 是 | 否（Magisk 模块在 OTA 后仍保留） |
| 分区空间检查 | 是 | 否（仅占用 `/data`） |
| 卸载方式 | recovery 重刷 / 手动清理 | Magisk 中停用或移除模块 |

这些差异是“systemless”的必然结果，取舍见 [compatibility.md](compatibility.md)。

## 7. 脚本职责 / Script responsibilities

| 文件 | 职责 |
| --- | --- |
| `convert-nikgapps-to-magisk.sh` | 解包 NikGapps、映射路径、填充 `<module>/system` |
| `build.sh` | 复制模板、生成 `module.prop`、调用转换器、打包 |
| `tools/make_module_zip.py` | 按 Magisk 规范生成 zip（`update-binary` 置首） |
| `magisk-template/` | 模块骨架（`module.prop`、`customize.sh`、`META-INF`） |
| `.github/workflows/build.yml` | 下载 NikGapps、构建并发布 GitHub Release |
