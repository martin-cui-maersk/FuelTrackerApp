import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("appearanceMode") private var appearanceModeRaw: String = ColorSchemeOption.system.rawValue
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("外观", selection: $appearanceModeRaw) {
                        ForEach(ColorSchemeOption.allCases, id: \.rawValue) { option in
                            Text(option.rawValue).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.menu)  // 👈 关键：下拉菜单样式
                    
                    Text("选择“跟随系统”后，应用将自动匹配设备的深色/浅色模式")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("外观")
                }
                
                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("关于")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
