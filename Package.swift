// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ControlDisplay",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        // C target：集中声明 macOS 私有 CoreGraphics API。
        // 这些符号未公开，可能随系统版本变化；全部弱链接，找不到也不会导致崩溃。
        .target(
            name: "CGSPrivate",
            path: "Sources/CGSPrivate"
        ),
        // 主程序：菜单栏 App。
        .executableTarget(
            name: "ControlDisplay",
            dependencies: ["CGSPrivate"],
            path: "Sources/ControlDisplay",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("IOKit")
            ]
        )
    ]
)
