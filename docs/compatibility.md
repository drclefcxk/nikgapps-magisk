# 兼容性与故障排除 / Compatibility & troubleshooting

## 1. 支持范围 / Supported range

| 项目 | 要求 | 说明 |
| --- | --- | --- |
| 架构 | **arm64** | NikGapps 的 arm64 包内是 64 位 APK；`customize.sh` 会在非 arm64 设备上终止安装 |
| Android 版本 | 与所用 NikGapps 构建一致（示例为 **Android 12 / API 31**） | GMS/Play 商店与系统版本强相关，跨版本使用通常闪退 |
| Magisk | **20.4+**（`minMagisk=20400`） | 挂载 `system/product`、`system/system_ext` 需要该版本起的支持 |
| 动态分区 / 传统分区 | 均可 | Magisk 会透明处理 `/product`、`/system_ext` 是否为独立分区 |
| 存储空间 | 安装约 **180 MB**（`/data`） | 载荷解压后约 177 MB |

## 2. 与 ROM 的关系 / Relationship with the ROM

* **最适合没有预装 GMS 的 AOSP/类原生 ROM**。
* 如果 ROM 已经内置 Google 服务（官方固件、部分第三方 ROM），模块里的 GMS 会与 ROM 中的同名包冲突。此时请先移除 ROM 自带的 GMS（或改用该 ROM 对应的 GApps 方案），否则可能出现：
  * Play 服务反复停止；
  * Play 商店提示“应用未安装”；
  * 两个 GMS 版本互相覆盖、账号同步异常。
* 本模块**不会删除** ROM 中的任何文件，这一点与 recovery 版 NikGapps 不同（见 [architecture.md](architecture.md) 第 6 节）。

## 3. 已知限制 / Known limitations

1. **不执行 debloat / 冲突应用清理**：recovery 版会删除 `PrebuiltGmsCoreQt`、`GmsCore` 等旧包并处理 AOSP 应用，本模块只做覆盖挂载。
2. **`nikgapps.config` 不生效**：刷入哪些包在构建时已经固定，无法在设备上增删。
3. **没有 `addon.d`**：不会在 OTA 后自动重新注入；但模块本身位于 `/data`，系统更新通常不会删除它。
4. **不修改 build.prop 等分区属性**：如果 ROM 缺少 GApps 相关属性，模块无法补齐。
5. **首次开机时间可能变长**：系统需要扫描新增的特权应用，属正常现象。

## 4. 故障排除 / Troubleshooting

| 现象 | 可能原因 | 处理 |
| --- | --- | --- |
| 刷入后无法开机 / 卡开机动画 | GMS 与 ROM 不兼容、API 不匹配、ROM 自带 GMS | 进入 Magisk 安全模式或删除模块目录下的 `disable` 标记，见下文“禁用与卸载” |
| 安装时提示 `arm64 only` | 设备不是 arm64 | 换用对应架构的 NikGapps 构建 |
| 安装时提示 API 警告 | NikGapps 构建的 Android 版本高于/低于设备 | 使用与设备 Android 版本一致的 NikGapps 构建 |
| Play 商店闪退 / 提示“应用未安装” | 模块被禁用/移除，或与同包名应用签名冲突 | 先重新启用/刷入模块并重启；仍失败时 `adb uninstall com.android.vending`、`com.google.android.gms` 后重启 |
| Play 服务不断停止 | 缺少权限白名单 / ROM 自带 GMS / API 不匹配 | 确认模块完整刷入；清除 GMS 数据；检查 Android 版本 |
| Play 商店显示“设备未通过认证” | ROM 的设备指纹/认证状态 | 清除 Play 商店与 Play 服务数据；这是 ROM 侧问题，GApps 模块无法修复 |
| 安装失败，提示空间不足 | `/data` 空间不足 | 清理空间（≥ 300 MB 余量）后重试 |
| 开机后没有 Google 应用 | 模块未启用 / 被安全模式禁用 | 在 Magisk 中确认模块已启用并重启 |

### 禁用与卸载 / Disable & uninstall

无法开机时（任选其一）：

```bash
# 有 adb（root/recovery）
adb shell "mkdir -p /data/adb/modules/nikgapps-magisk && touch /data/adb/modules/nikgapps-magisk/disable"

# 或删除模块目录（下次开机 Magisk 会清理）
adb shell "touch /data/adb/modules/nikgapps-magisk/remove"
```

也可以使用 Magisk 的安全模式：开机时按住音量下键，Magisk 会跳过所有模块，进入系统后在 Magisk App 中停用本模块。

正常卸载：Magisk App → 模块 → 移除 → 重启。模块本身只删除 `/data/adb/modules/nikgapps-magisk`；应用数据是否保留取决于系统启动时的清理行为与是否存在 `/data/app` 更新副本，详见第 6 节。

## 5. 与 OpenGApps 版本的关系 / Relation to the OpenGApps variant

本仓库仍保留 `convert-opengappss-to-magisk.sh` 以支持 OpenGApps 刷机包（见 [cli.md](cli.md) 第 5 节），但两条流水线互不影响：

* NikGapps 流程：`build.sh` + `convert-nikgapps-to-magisk.sh`（本仓库主线）
* OpenGApps 流程：`convert-opengappss-to-magisk.sh`（遗留，需要 `lzip`）

两者生成的模块 id 不同（`nikgapps-magisk` / 取决于 OpenGApps 模板），不会互相覆盖，但**不要同时启用**两套 GApps 模块。

## 6. 数据与移除行为 / Data & removal

### 6.1 模块本身不保存数据

`/data/adb/modules/nikgapps-magisk` 里只有只读的 APK、权限 XML 等文件（约 180 MB）；应用运行时的数据都写在真实的 `/data` 下。

### 6.2 移除或停用后，数据会怎样？

实测现象（Android 12 + 本项目构建）：

* 禁用或移除模块并重启后，Play 商店与 Play 服务通常仍出现在应用列表中，但打开会闪退；
* 重新启用模块并重启后，应用恢复正常，账号登录状态与数据保留。

原因：Play 商店会把 GMS（`com.google.android.gms`）与自身（`com.android.vending`）更新到 `/data/app`。这些“更新的系统应用”在模块消失后仍然存在，因此系统不会把它们当成“已消失的系统应用”去清理数据。

只有当包**在任何分区都不存在**时（没有 `/data/app` 更新副本，或被手动卸载），系统才会在下次正常开机时清理其数据（AOSP `PackageManagerService`）：

```java
// Android 12, PackageManagerService.java:7397-7400
logCriticalInfo(Log.WARN, "System package " + ps.name
        + " no longer exists; it's data will be wiped");
removePackageDataLIF(ps, userIds, null, 0, false);
```

源码：[PackageManagerService.java#L7397-L7400](https://github.com/aosp-mirror/platform_frameworks_base/blob/android12-release/services/core/java/com/android/server/pm/PackageManagerService.java#L7397-L7400)。

结论：

* 有 `/data/app` 更新副本时，禁用/移除后重新刷入，数据通常保留；
* 包完全消失时，等同全新安装，需要重新登录；
* 最稳妥：移除后**不进入 Android**，直接在 recovery/Magisk 中刷回同一模块。

### 6.3 移除模块后 Play 商店 / Play 服务还在、打不开、可卸载？

这是**预期行为**，不是模块的 bug：

* Play 商店会把 GMS（`com.google.android.gms`）和自身（`com.android.vending`）更新到 `/data/app`；
* 模块只提供 `/system/product`、`/system_ext` 中的系统副本，移除后系统副本消失，`/data/app` 中的更新版本仍在；
* 它不再是特权系统应用，缺少权限与 GSF 依赖，启动会失败或闪退，所以“打不开”；
* 因为不再是系统应用，设置里会提供“卸载”；只要不卸载，数据保留，重新刷入模块即可恢复（见 6.2）。

| 目标 | 做法 |
| --- | --- |
| 恢复可用的 GApps | 重新刷入同一模块并重启，`/data` 中的更新版本会重新作为系统应用更新生效 |
| 彻底移除 | 在设置中卸载，或 `adb uninstall com.android.vending`、`adb uninstall com.google.android.gms`（会删除数据） |
| 保留数据 | 卸载前先备份；只要不卸载，数据通常仍在 |

### 6.4 如何尽量不丢数据

* 升级/切换 NikGapps 版本：直接刷入新模块覆盖（保持模块 id `nikgapps-magisk`），不要先移除。
* 必须移除时：先做 TWRP 全量 `/data` 备份，恢复后再刷入同一版本。
* 误点“停用”：重新启用即可；实测重新启用后应用恢复、数据与登录状态保留。

### 6.5 数据去向一览

| 数据 | 位置 | 移除模块并正常开机后 |
| --- | --- | --- |
| 应用私有数据（登录态、token 缓存、设置、`/data/app` 更新包） | `/data/data/…`、`/data/user_de/…` | 若包彻底消失：被系统清除；若 `/data/app` 有更新副本：保留 |
| Google 账号条目 | `/data/system/users/0/accounts_ce.db` | 通常保留（AccountManager 只清理授权），但缺少 GMS 时不可用，重刷后一般需重新授权 |
| 用户存储（照片、下载、备份） | `/data/media/0` | 不受影响 |
| 云端数据（通讯录、日历、相册） | Google 服务器 | 不受影响，重新登录后同步回来 |
| 模块本体 | `/data/adb/modules/nikgapps-magisk` | 被删除，释放约 180 MB |
