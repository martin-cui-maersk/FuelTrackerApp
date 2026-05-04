import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    // App 图标和名称
                    VStack(spacing: 16) {
                        Image(systemName: "fuelpump.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("油耗记录")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("版本 1.0.0")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("构建日期 2026年5月4日")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
                
                Section(header: Text("功能介绍")) {
                    FeatureRow(icon: "car.fill", title: "多车辆管理", description: "支持添加多辆车，分别记录")
                    FeatureRow(icon: "fuelpump.fill", title: "加油记录", description: "记录里程、金额、油量")
                    FeatureRow(icon: "chart.xyaxis.line", title: "油耗统计", description: "自动计算油耗、费用趋势")
                    FeatureRow(icon: "square.and.arrow.up", title: "数据导出", description: "JSON格式导出导入")
                }
                
                Section(header: Text("关于")) {
                    HStack {
                        Text("开发者")
                        Spacer()
                        Text("FuelTracker Team")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("反馈建议")
                        Spacer()
                        Link("发送邮件", destination: URL(string: "mailto:martincuixp@gmail.com")!)
                    }
                }
                
                Section {
                    Text("感谢使用油耗记录 App！\n\n如有问题或建议，欢迎反馈。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 10)
                }
            }
            .navigationTitle("关于")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AboutView()
}
