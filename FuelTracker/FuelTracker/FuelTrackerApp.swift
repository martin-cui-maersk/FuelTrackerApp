//
//  FuelTrackerApp.swift
//  FuelTracker
//
//  Created on 2026-05-05.
//

import SwiftUI

@main
struct FuelTrackerApp: App {
    @StateObject private var dataStore = DataStore()
    
    // 存储外观模式的 rawValue，默认跟随系统
    @AppStorage("appearanceMode") private var appearanceModeRaw: String = ColorSchemeOption.system.rawValue
    
    // 计算属性，方便获取枚举对象
    private var appearanceMode: ColorSchemeOption {
        get { ColorSchemeOption(rawValue: appearanceModeRaw) ?? .system }
        set { appearanceModeRaw = newValue.rawValue }
    }
    
    // 初始化：处理旧版本数据迁移（从 isDarkMode 迁移到 appearanceMode）
    init() {
        migrateOldColorSchemeSetting()
    }
    
    var body: some Scene {
        WindowGroup {
            VehicleListView()
                .environmentObject(dataStore)
                .preferredColorScheme(appearanceMode.colorScheme)
        }
    }
    
    // MARK: - 数据迁移（如果旧版本使用了 isDarkMode）
    private func migrateOldColorSchemeSetting() {
        let hasOldSetting = UserDefaults.standard.object(forKey: "isDarkMode") != nil
        guard hasOldSetting else { return }
        
        let oldIsDark = UserDefaults.standard.bool(forKey: "isDarkMode")
        let newMode: ColorSchemeOption = oldIsDark ? .dark : .light
        UserDefaults.standard.set(newMode.rawValue, forKey: "appearanceMode")
        UserDefaults.standard.removeObject(forKey: "isDarkMode")
        
        print("已从旧版 isDarkMode 迁移到新模式：\(newMode.rawValue)")
    }
}