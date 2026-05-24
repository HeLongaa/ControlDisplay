//
//  CGSPrivate.h
//  仅暴露私有 CoreGraphics API 用到的结构体定义。
//
//  ⚠️ 函数本身不在这里 extern 声明，而是在 Swift 侧用 dlsym 动态加载
//  （见 CGSBridge.swift）。这样可以彻底避开 Swift 对 weak_import C 符号
//  的处理差异，缺符号时不会触发任何静态链接器错误。
//

#ifndef CGSPrivate_h
#define CGSPrivate_h

#include <CoreGraphics/CoreGraphics.h>
#include <stdint.h>

/// 私有显示模式描述结构体。真实结构体比这里更大，只读取前面几个字段，
/// 多余字节由系统填充忽略；传入 sizeof(CGSDisplayModeDescription) 即可。
typedef struct {
    uint32_t modeNumber;
    int32_t  flags;
    uint32_t width;
    uint32_t height;
    uint32_t depthFormat;
} CGSDisplayModeDescription;

#endif /* CGSPrivate_h */
