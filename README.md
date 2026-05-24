# ControlDisplay

一个原生 macOS 菜单栏小工具：连接外部显示器时，一键关闭内置屏。

参考截图实现了三种模式：

- **全部**：所有显示器都开
- **内建**：只开内置屏，关闭所有外接显示器
- **外接**：只开外接显示器，关闭内置屏（你的主用例）

支持菜单栏点选、浮动选择器面板、全局可自定义快捷键（默认 ⌥⇧P）、登录时自动启动。

## 真关闭：技术现状（必读）

在 Apple Silicon 上「让内置屏真正断电熄灭」没有公开 API。本项目采用**三层策略**，逻辑在 `Sources/ControlDisplay/PrivateDisplayControl.swift`，从最彻底到最兜底依次尝试：

1. **私有 `CGSConfigureDisplayEnabled`（macOS 13+ Apple Silicon 主用路径）** —— 在 `CGBeginDisplayConfiguration` 事务里把显示器置为 disabled，系统会把它从 `online` 列表彻底移除：鼠标过不去、窗口进不去、面板断电，在「系统设置 > 显示器」里也看不到它。这正是 Lunar BlackOut「断开」和 BetterDisplay 自动断开内置屏用的同一个 SkyLight 私有函数。
2. **私有 `CGSConfigureDisplayMode` 模式禁用（Intel 兼容路径）** —— 老 Intel Mac 的标准做法（DisableMonitor 风格）。M 芯片模式列表通常没有「关闭模式」，会自动跳过。
3. **伽马全黑 + `DisplayServicesSetBrightness` 把背光降到 0（兜底）** —— 前两层都失败时使用。注意这一层**鼠标仍能移过去**，因为显示器逻辑上还在桌面排布里，只是画面全黑、背光最暗。

> 用 `CGCompleteDisplayConfiguration(..., .forSession)` 提交：断开只对当前登录会话有效，万一 App 异常退出，注销/重启后内置屏会自动回来，避免死锁。

进一步参考：[Lunar](https://github.com/alin23/Lunar)、[BetterDisplay](https://github.com/waydabber/BetterDisplay)、私有 API 头文件集 [NUIKit/CGSInternal](https://github.com/NUIKit/CGSInternal)。

> 私有 API 全部用 `weak_import` 弱链接，符号缺失不会让 App 启动崩溃；运行时也会判空再调用。

## 项目结构

```
DissableMacDosplay/
├── Package.swift                              # SwiftPM 配置
├── build.sh                                   # 编译 + 打包 .app 的脚本
├── Resources/Info.plist                       # 菜单栏 App 的 bundle 信息（LSUIElement=true）
└── Sources/
    ├── CGSPrivate/                            # 私有 CoreGraphics API 的 C 声明
    │   ├── include/CGSPrivate.h
    │   └── shim.c
    └── ControlDisplay/
        ├── main.swift                         # 入口
        ├── AppDelegate.swift                  # 状态栏、菜单
        ├── DisplayMode.swift                  # 全部/内建/外接 枚举
        ├── DisplayManager.swift               # 枚举显示器、决定开关哪台
        ├── PrivateDisplayControl.swift        # ★ 关闭引擎（分层策略）
        ├── DisplayServicesBridge.swift        # dlopen 私有亮度 API
        ├── QuickSwitchPanel.swift             # 浮动选择器面板（参考第二张截图）
        ├── HotKey.swift                       # Carbon 全局快捷键
        ├── HotKeyPreferencesWindow.swift      # 自定义快捷键窗口
        └── LoginItem.swift                    # SMAppService 登录启动
```

## 编译运行

需要 macOS 13+ 和 Xcode Command Line Tools（不需要 Xcode IDE，但有也没问题）。

```bash
cd /Users/helong/Git/DissableMacDosplay
./build.sh                    # 默认 release 构建
open .build/release/ControlDisplay.app
```

首次运行 macOS 可能因为 ad-hoc 签名拦截，按住 Control 点击 .app → 打开即可。

## 使用

- 顶部菜单栏会出现一个显示器图标，点击展开菜单。
- 选**外接**：立即关闭内置屏。再次选**全部**或**内建**即可恢复。
- 选**快速切换…**（默认 ⌥⇧P）：屏幕中央弹出选择器，按一下完成切换；面板里也可以直接按数字键 1/2/3 选「全部 / 内建 / 外接」，Esc 关闭。
- **自定义快捷键…**：点录制框 → 按下想要的组合（必须带修饰键）→ 保存。
- **登录时启动**：调用 SMAppService 注册当前 .app 为登录项。

## 可能需要按机器调优的地方

1. **`CGSConfigureDisplayEnabled` 符号名**：较新的 macOS 可能只导出 `SLSConfigureDisplayEnabled`（SkyLight 前缀）。`CGSBridge` 已经两个名字都尝试，正常无需改动。
2. **若真断开无效、降级到了伽马全黑**（表现为鼠标还能移过去）：在 `tryHardDisconnect` 里打印 `err` 和 `CGCompleteDisplayConfiguration` 的返回值，确认是符号没加载到还是事务被拒。
3. **状态恢复**：App 在 `applicationWillTerminate` 里会把所有显示器恢复到「全部」，避免退出/崩溃后屏幕一直黑；断开用的是 `.forSession`，注销/重启也会恢复。

## 已知限制

- 无法上架 Mac App Store（用了私有 API）。
- 系统大版本升级后，如果 Apple 改了私有符号，硬关闭策略可能失效，但兜底的伽马全黑策略基于公开 API，应该一直能用。
- 当前没有外接显示器时选「外接」会被忽略并提示，避免把唯一可见的屏关掉。
