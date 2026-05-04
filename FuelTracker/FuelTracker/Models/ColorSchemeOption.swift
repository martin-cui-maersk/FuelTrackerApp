//
//  ColorSchemeOption.swift
//  FuelTracker
//
//  Created on 2026-05-05.
//

import SwiftUI

/// 外观模式：浅色、深色、跟随系统
enum ColorSchemeOption: String, CaseIterable {
    case light = "浅色"
    case dark = "深色"
    case system = "跟随系统"

    /// 对应的 SwiftUI 颜色方案（nil 表示跟随系统）
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}