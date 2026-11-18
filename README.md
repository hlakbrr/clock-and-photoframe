# Clock & PhotoFrame（时钟相框二合一）

给退役 iPhone 用的桌面时钟 + 数字相框混合 App。原生 Swift 无第三方依赖，部署目标 iOS 15.0。

## 工作逻辑

- **时钟模式**：极简风格（纯黑背景、细体白色大数字、浅灰日期行），数字变化时自上翻转。视觉上是对 Zen Flip Clock 极简风格的干净重写（未使用其任何代码/素材）。
- **相框模式**：全屏 WKWebView 加载 ImmichFrame 服务端网页（对应原 nasframe-ios 壳）。
- **自动切换**（ProbeEngine）：在用户设置的探测时段内，每隔设定间隔（30秒/1分钟/2分钟/5分钟）HEAD 探测一次 ImmichFrame 服务器——在线切相框、离线切时钟；时段外始终显示时钟；时段支持跨午夜，可添加任意多个。
- **屏幕常亮**：App 前台期间禁止自动锁屏（桌面设备专用）。

## 设置项（下拉或双指长按进入）

- 相框服务器地址 + 可选认证密钥（自动追加 `?authsecret=`）
- 探测间隔：30秒 / 1分钟 / 2分钟 / 5分钟
- 探测时段：列表编辑，新增/修改/删除，空列表 = 全天探测
- 时钟外观：24小时制 / 显示秒 / 显示日期

## 深链（供看门狗/自动化调用）

`clockframe://open` 或 `immichframe://open`（后者兼容旧 nasframe 看门狗）→ 立即探测并按需刷新相框页。

## 构建

同 nasframe-ios：推送后 GitHub Actions（macos-latest）自动 XcodeGen → xcodebuild 无签名构建 → ldid 假签 → 打包 IPA → artifact 下载。TrollStore 安装。

## 来源说明

- 相框部分与 ImmichFrame 项目（GPL-3.0）服务端配套使用
- 时钟视觉参考 Zen Flip Clock（App Store 闭源商业软件，bundle ID com.mad.FlipClock）的设计风格，本项目全部代码为独立实现
