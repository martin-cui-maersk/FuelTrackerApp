import SwiftUI
import Charts

struct VehicleDetailView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    
    let vehicleId: UUID
    @State private var showingAddFuelRecord = false
    @State private var showingAddChargeRecord = false
    @State private var showingStatistics = false
    @State private var editingFuelRecord: FuelRecord?
    @State private var editingChargeRecord: ChargeRecord?
    @State private var showingEditVehicle = false
    @State private var expandedFuelSections: Set<String> = []
    @State private var expandedChargeSections: Set<String> = []
    
    private var vehicle: Vehicle {
        dataStore.vehicles.first { $0.id == vehicleId } ?? Vehicle(name: "未知车辆")
    }
    
    var body: some View {
        List {
            // 统计摘要
            Section(header: Text("统计")) {
                VStack(spacing: 12) {
                    // 第一行
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "road.lanes")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text("总里程")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text(String(format: "%.0f km", vehicle.totalDistance))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "yensign.circle")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text("总花费")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text(String(format: "¥%.2f", vehicle.totalCost))
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "gauge")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Text("平均油耗")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if let avg = vehicle.averageFuelConsumption {
                                Text(String(format: "%.2f L/100km", avg))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                            } else {
                                Text("-")
                                    .foregroundColor(.gray)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // 第二行
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "fuelpump")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Text("总油量")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text(String(format: "%.2f L", vehicle.totalFuel))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.caption)
                                    .foregroundColor(.purple)
                                Text("平均每天")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if let dist = vehicle.averageDistancePerDay {
                                Text(String(format: "%.2f km", dist))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.purple)
                            } else {
                                Text("-")
                                    .foregroundColor(.gray)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "dollarsign.circle")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text("每公里")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if let cost = vehicle.averageCostPerKm {
                                Text(String(format: "¥%.2f", cost))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                            } else {
                                Text("-")
                                    .foregroundColor(.gray)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .font(.subheadline)
            }
            
            // 加油记录（油车）- 按年月分组，可折叠
            if vehicle.type == .fuel {
                Section(header: Text("加油记录")) {
                    ForEach(Array(vehicle.recordsByYearMonth.enumerated()), id: \.offset) { index, group in
                        if !group.fuelRecords.isEmpty {
                            DisclosureGroup(
                                isExpanded: Binding(
                                    get: { expandedFuelSections.contains("\(group.year)-\(group.month)") },
                                    set: { isExpanded in
                                        let key = "\(group.year)-\(group.month)"
                                        if isExpanded {
                                            expandedFuelSections.insert(key)
                                        } else {
                                            expandedFuelSections.remove(key)
                                        }
                                    }
                                )
                            ) {
                                // 按里程排序（里程大的在前，同一天内也按里程排序）
                                ForEach(group.fuelRecords.sorted(by: { $0.odometer > $1.odometer })) { record in
                                    FuelRecordRowView(vehicle: vehicle, record: record)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            editingFuelRecord = record
                                        }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                deleteFuelRecord(record)
                                            } label: {
                                                Label("删除", systemImage: "trash")
                                            }
                                        }
                                }
                            } label: {
                                HStack {
                                    Text("\(String(group.year))年\(group.month)月")
                                        .font(.headline)
                                    Spacer()
                                    if let summary = vehicle.monthlyFuelSummary(year: group.year, month: group.month) {
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("\(String(format: "%.0f", summary.distance))km · ¥\(String(format: "%.2f", summary.cost)) · ¥\(String(format: "%.2f", summary.costPerKm))/km")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            if summary.fullTankCount < summary.totalCount {
                                                Text("加满\(summary.fullTankCount)/\(summary.totalCount)次")
                                                    .font(.caption2)
                                                    .foregroundColor(.orange)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // 充电记录（纯电车）- 按年月分组，可折叠
            if vehicle.type == .electric {
                Section(header: Text("充电记录")) {
                    ForEach(Array(vehicle.recordsByYearMonth.enumerated()), id: \.offset) { index, group in
                        if !group.chargeRecords.isEmpty {
                            DisclosureGroup(
                                isExpanded: Binding(
                                    get: { expandedChargeSections.contains("\(group.year)-\(group.month)") },
                                    set: { isExpanded in
                                        let key = "\(group.year)-\(group.month)"
                                        if isExpanded {
                                            expandedChargeSections.insert(key)
                                        } else {
                                            expandedChargeSections.remove(key)
                                        }
                                    }
                                )
                            ) {
                                // 按里程排序（里程大的在前，同一天内也按里程排序）
                                ForEach(group.chargeRecords.sorted(by: { $0.odometer > $1.odometer })) { record in
                                    ChargeRecordRowView(vehicle: vehicle, record: record)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            editingChargeRecord = record
                                        }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                deleteChargeRecord(record)
                                            } label: {
                                                Label("删除", systemImage: "trash")
                                            }
                                        }
                                }
                            } label: {
                                HStack {
                                    Text("\(String(group.year))年\(group.month)月")
                                        .font(.headline)
                                    Spacer()
                                    if let summary = vehicle.monthlyChargeSummary(year: group.year, month: group.month) {
                                        Text("\(String(format: "%.0f", summary.distance))km · ¥\(String(format: "%.2f", summary.cost)) · ¥\(String(format: "%.2f", summary.costPerKm))/km")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // 混动车 - 加油和充电合并显示，按里程排序
            if vehicle.type == .hybrid {
                Section(header: Text("加油/充电记录")) {
                    ForEach(vehicle.allRecordsSorted) { record in
                        if record.isFuel {
                            FuelRecordRowView(vehicle: vehicle, record: record.fuelRecord!, showType: true)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingFuelRecord = record.fuelRecord
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteFuelRecord(record.fuelRecord!)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                        } else {
                            ChargeRecordRowView(vehicle: vehicle, record: record.chargeRecord!, showType: true)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingChargeRecord = record.chargeRecord
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteChargeRecord(record.chargeRecord!)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
        }
        .navigationTitle(vehicle.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingStatistics = true }) {
                        Label("查看统计", systemImage: "chart.xyaxis.line")
                    }
                    
                    if vehicle.type != .electric {
                        Button(action: { showingAddFuelRecord = true }) {
                            Label("添加加油记录", systemImage: "fuelpump.fill")
                        }
                    }
                    
                    if vehicle.type != .fuel {
                        Button(action: { showingAddChargeRecord = true }) {
                            Label("添加充电记录", systemImage: "bolt.fill")
                        }
                    }
                    
                    Divider()
                    
                    Button(action: { showingEditVehicle = true }) {
                        Label("编辑车辆", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddFuelRecord) {
            AddFuelRecordView(vehicle: vehicle)
        }
        .sheet(isPresented: $showingAddChargeRecord) {
            if let v = dataStore.vehicles.first(where: { $0.id == vehicleId }) {
                AddChargeRecordView(vehicle: v)
            }
        }
        .sheet(item: $editingFuelRecord) { record in
            EditFuelRecordView(vehicle: vehicle, record: record)
        }
        .sheet(item: $editingChargeRecord) { record in
            EditChargeRecordView(vehicle: vehicle, record: record)
        }
        .sheet(isPresented: $showingStatistics) {
            StatisticsView(vehicle: vehicle)
        }
        .sheet(isPresented: $showingEditVehicle) {
            EditVehicleView(vehicle: vehicle)
        }
    }
    
    // 计算加油月统计摘要
    private func groupFuelSummary(fuelRecords: [FuelRecord]) -> String {
        guard fuelRecords.count >= 2 else {
            let totalCost = fuelRecords.reduce(0) { $0 + $1.totalPrice }
            return "¥\(Int(totalCost))"
        }
        
        let sorted = fuelRecords.sorted { $0.odometer < $1.odometer }
        let distance = sorted.last!.odometer - sorted.first!.odometer
        let totalCost = fuelRecords.reduce(0) { $0 + $1.totalPrice }
        let costPerKm = distance > 0 ? totalCost / distance : 0
        
        return "\(String(format: "%.0f", distance))km · ¥\(String(format: "%.2f", totalCost)) · ¥\(String(format: "%.2f", costPerKm))/km"
    }
    
    // 计算充电月统计摘要
    private func groupChargeSummary(chargeRecords: [ChargeRecord]) -> String {
        guard chargeRecords.count >= 2 else {
            let totalCost = chargeRecords.reduce(0) { $0 + $1.totalPrice }
            return "¥\(String(format: "%.2f", totalCost))"
        }
        
        let sorted = chargeRecords.sorted { $0.odometer < $1.odometer }
        let distance = sorted.last!.odometer - sorted.first!.odometer
        let totalCost = chargeRecords.reduce(0) { $0 + $1.totalPrice }
        let costPerKm = distance > 0 ? totalCost / distance : 0
        
        return "\(String(format: "%.0f", distance))km · ¥\(String(format: "%.2f", totalCost)) · ¥\(String(format: "%.2f", costPerKm))/km"
    }
    
    private func deleteFuelRecord(_ record: FuelRecord) {
        if let index = dataStore.vehicles.firstIndex(where: { $0.id == vehicleId }) {
            dataStore.vehicles[index].fuelRecords.removeAll { $0.id == record.id }
            dataStore.saveVehicles()
        }
    }
    
    private func deleteChargeRecord(_ record: ChargeRecord) {
        if let index = dataStore.vehicles.firstIndex(where: { $0.id == vehicleId }) {
            dataStore.vehicles[index].chargeRecords.removeAll { $0.id == record.id }
            dataStore.saveVehicles()
        }
    }
}

// 加油记录行
struct FuelRecordRowView: View {
    let vehicle: Vehicle
    let record: FuelRecord
    var showType: Bool = false  // 是否显示类型标识（混动车用）
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 第一行：标记 + 日期 + 金额
            HStack {
                HStack(spacing: 8) {
                    if showType {
                        HStack(spacing: 4) {
                            Image(systemName: "fuelpump.fill")
                                .font(.caption2)
                            Text("加油")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                    }
                    
                    if record.isFullTank {
                        Text("加满")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    } else {
                        Text("未加满")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.gray.opacity(0.15))
                            .foregroundColor(.gray)
                            .cornerRadius(4)
                    }
                    
                    if record.lowFuelLightOnAtRefuel, !record.isFullTank {
                        Text("油灯亮")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.red.opacity(0.12))
                            .foregroundColor(.red)
                            .cornerRadius(4)
                    }
                    
                    Text(record.date, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(String(format: "¥%.2f", record.totalPrice))
                    .font(.headline)
                    .foregroundColor(.green)
            }
            
            // 第二行：里程 | 加油量 | 单价
            HStack(spacing: 24) {
                HStack(spacing: 4) {
                    Image(systemName: "speedometer")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(String(format: "%.0f km", record.odometer))
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "fuelpump.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text(String(format: "%.2f L", record.fuelAmount))
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "yensign")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(String(format: "%.2f/L", record.pricePerLiter))
                }
            }
            .font(.subheadline)
            
            // 第三行：里程差 | 油耗 | 油费 | 每公里
            if let consumption = vehicle.fuelConsumptionForRecord(record),
               let distance = vehicle.distanceForFuelRecord(record),
               let tripCost = vehicle.tripFuelCostForRecord(record),
               let costPerKm = vehicle.fuelCostPerKmForRecord(record) {
                
                Divider()
                    .padding(.vertical, 2)
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("行驶")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        HStack(spacing: 2) {
                            Text(String(format: "%.0f", distance))
                                .fontWeight(.semibold)
                            Text("km")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("油耗")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        HStack(spacing: 2) {
                            Text(String(format: "%.2f", consumption))
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                            Text("L/100km")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("油费")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(format: "¥%.2f", tripCost))
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("每公里")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(format: "¥%.2f", costPerKm))
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                }
                .font(.subheadline)
            }
            
            if !record.note.isEmpty {
                Text(record.note)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 2)
    }
}

// 充电记录行
struct ChargeRecordRowView: View {
    let vehicle: Vehicle
    let record: ChargeRecord
    var showType: Bool = false  // 是否显示类型标识（混动车用）
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if showType {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.caption2)
                        Text("充电")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.15))
                    .foregroundColor(.green)
                    .cornerRadius(4)
                }
                
                Text(record.date, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "¥%.2f", record.totalPrice))
                    .font(.headline)
                    .foregroundColor(.green)
            }
            
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "speedometer")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(String(format: "%.0f km", record.odometer))
                        .font(.subheadline)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text(String(format: "%.2f kWh", record.chargeAmount))
                        .font(.subheadline)
                }
                
                // 显示电量百分比范围
                HStack(spacing: 4) {
                    Image(systemName: "battery.100")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(String(format: "%.0f%% → %.0f%%", record.startBatteryPercent, record.endBatteryPercent))
                        .font(.subheadline)
                }
                
                if let chargeTime = record.chargeTime {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(String(format: "%.0f 分钟", chargeTime))
                            .font(.subheadline)
                    }
                }
            }
            
            // 公里差和电耗显示
            if let distance = vehicle.distanceForChargeRecord(record) {
                HStack(spacing: 20) {
                    // 公里差（所有记录都显示）
                    HStack {
                        Text("公里差:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.0f km", distance))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    
                    // 电耗（有充电量才显示）
                    if record.chargeAmount > 0 {
                        if let consumption = vehicle.chargeConsumptionForRecord(record) {
                            HStack {
                                Text("电耗:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f kWh/100km", consumption))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }
            
            // 行程电费支出（有充电量才显示，用上次电价计算）
            if record.chargeAmount > 0 {
                if let tripCost = vehicle.tripChargeCostForRecord(record) {
                    HStack(spacing: 20) {
                        HStack {
                            Text("行程电费:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "¥%.2f", tripCost))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                        
                        if let costPerKm = vehicle.chargeCostPerKmForRecord(record) {
                            HStack {
                                Text("每公里:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "¥%.2f", costPerKm))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            
            // 无充电量提示
            if record.chargeAmount == 0 {
                Text("无充电量数据")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            if !record.note.isEmpty {
                Text(record.note)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 2)
    }
}

// 编辑车辆视图
struct EditVehicleView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    
    @State var vehicle: Vehicle
    @State private var name: String = ""
    @State private var plateNumber: String = ""
    @State private var vehicleType: VehicleType = .fuel
    @State private var showError = false
    @State private var errorMessage = ""
    
    init(vehicle: Vehicle) {
        self._vehicle = State(initialValue: vehicle)
        self._name = State(initialValue: vehicle.name)
        self._plateNumber = State(initialValue: vehicle.plateNumber)
        self._vehicleType = State(initialValue: vehicle.type)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("车辆信息")) {
                    TextField("车辆名称", text: $name)
                    TextField("车牌号（必填）", text: $plateNumber)
                }
                
                Section(header: Text("车辆类型")) {
                    ForEach(VehicleType.allCases, id: \.self) { type in
                        HStack {
                            Image(systemName: type.icon)
                                .foregroundColor(vehicleType == type ? .blue : .gray)
                                .frame(width: 30)
                            
                            Text(type.rawValue)
                                .foregroundColor(vehicleType == type ? .blue : .primary)
                            
                            Spacer()
                            
                            if vehicleType == type {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            vehicleType = type
                        }
                    }
                }
            }
            .navigationTitle("编辑车辆")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveVehicle()
                    }
                    .disabled(name.isEmpty || plateNumber.isEmpty)
                }
            }
            .alert("保存失败", isPresented: $showError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func saveVehicle() {
        if dataStore.isPlateNumberExists(plateNumber, excludeVehicleId: vehicle.id) {
            errorMessage = "车牌号「\(plateNumber)」已被其他车辆使用"
            showError = true
            return
        }
        
        var updated = vehicle
        updated.name = name
        updated.plateNumber = plateNumber
        updated.type = vehicleType
        
        if dataStore.updateVehicle(updated) {
            dismiss()
        } else {
            errorMessage = "保存失败，请重试"
            showError = true
        }
    }
}

#Preview {
    NavigationView {
        let store = DataStore()
        _ = store.addVehicle(name: "测试车辆", plateNumber: "京A12345", type: .hybrid)
        let vehicle = store.vehicles[0]
        return VehicleDetailView(vehicleId: vehicle.id)
            .environmentObject(store)
    }
}

