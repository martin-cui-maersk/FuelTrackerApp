import SwiftUI

// 添加加油记录
struct AddFuelRecordView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    
    let vehicle: Vehicle
    
    @State private var odometer = ""
    @State private var totalPrice = ""
    @State private var fuelAmount = ""
    @State private var isFullTank = true  // 默认加满
    @State private var date = Date()
    @State private var note = ""
    @State private var showDatePicker = false
    
    private var lastOdometer: Double? {
        // 混动车显示上一次里程（加油和充电都算）
        if vehicle.type == .hybrid {
            return vehicle.lastOdometer
        }
        return vehicle.fuelRecords.map(\.odometer).max()
    }
    
    private var calculatedPricePerLiter: Double? {
        guard let fuel = Double(fuelAmount), fuel > 0,
              let total = Double(totalPrice) else { return nil }
        return total / fuel
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("加油信息")) {
                    HStack {
                        Text("里程(km)")
                            .frame(width: 80, alignment: .leading)
                        TextField("必填", text: $odometer)
                            .keyboardType(.decimalPad)
                        if let last = lastOdometer {
                            Text("上次: \(Int(last))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    HStack {
                        Text("实付金额(元)")
                            .frame(width: 80, alignment: .leading)
                        TextField("必填", text: $totalPrice)
                            .keyboardType(.decimalPad)
                    }
                    
                    HStack {
                        Text("油量(L)")
                            .frame(width: 80, alignment: .leading)
                        TextField("必填", text: $fuelAmount)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section(header: Text("加满状态")) {
                    Toggle(isOn: $isFullTank) {
                        VStack(alignment: .leading) {
                            Text("加满油箱")
                            if !isFullTank {
                                Text("不加满时无法计算本次油耗")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
                
                Section(header: Text("时间")) {
                    Button(action: { showDatePicker = true }) {
                        HStack {
                            Text("加油时间")
                            Spacer()
                            Text(date, style: .date)
                                .foregroundColor(.blue)
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                Section(header: Text("备注（选填）")) {
                    TextField("如：加油站名称", text: $note)
                }
                
                if let pricePerLiter = calculatedPricePerLiter {
                    Section {
                        HStack {
                            Text("单价（自动计算）")
                            Spacer()
                            Text(String(format: "%.2f 元/L", pricePerLiter))
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("添加加油记录")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveRecord()
                    }
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showDatePicker) {
                NavigationView {
                    DatePicker("加油时间", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()
                        .navigationTitle("选择日期")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("确定") { showDatePicker = false }
                            }
                        }
                }
                .presentationDetents([.medium])
            }
        }
    }
    
    private var isValid: Bool {
        guard let odometer = Double(odometer), odometer > 0,
              let fuel = Double(fuelAmount), fuel > 0,
              let total = Double(totalPrice), total > 0 else {
            return false
        }
        return true
    }
    
    private func saveRecord() {
        guard let odometer = Double(odometer),
              let fuel = Double(fuelAmount),
              let total = Double(totalPrice) else { return }
        
        dataStore.addFuelRecord(
            to: vehicle,
            odometer: odometer,
            fuelAmount: fuel,
            totalPrice: total,
            isFullTank: isFullTank,
            date: date,
            note: note
        )
        dismiss()
    }
}

// 编辑加油记录
struct EditFuelRecordView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    
    let vehicle: Vehicle
    @State var record: FuelRecord
    
    @State private var odometer: String
    @State private var totalPrice: String
    @State private var fuelAmount: String
    @State private var isFullTank: Bool
    @State private var date: Date
    @State private var note: String
    @State private var showDatePicker = false
    
    private var calculatedPricePerLiter: Double? {
        guard let fuel = Double(fuelAmount), fuel > 0,
              let total = Double(totalPrice) else { return nil }
        return total / fuel
    }
    
    init(vehicle: Vehicle, record: FuelRecord) {
        self.vehicle = vehicle
        self._record = State(initialValue: record)
        self._odometer = State(initialValue: String(format: "%.0f", record.odometer))
        self._totalPrice = State(initialValue: String(format: "%.2f", record.totalPrice))
        self._fuelAmount = State(initialValue: String(format: "%.2f", record.fuelAmount))
        self._isFullTank = State(initialValue: record.isFullTank)
        self._date = State(initialValue: record.date)
        self._note = State(initialValue: record.note)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("加油信息")) {
                    HStack {
                        Text("里程(km)")
                            .frame(width: 80, alignment: .leading)
                        TextField("必填", text: $odometer)
                            .keyboardType(.decimalPad)
                    }
                    
                    HStack {
                        Text("实付金额(元)")
                            .frame(width: 80, alignment: .leading)
                        TextField("必填", text: $totalPrice)
                            .keyboardType(.decimalPad)
                    }
                    
                    HStack {
                        Text("油量(L)")
                            .frame(width: 80, alignment: .leading)
                        TextField("必填", text: $fuelAmount)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section(header: Text("加满状态")) {
                    Toggle(isOn: $isFullTank) {
                        VStack(alignment: .leading) {
                            Text("加满油箱")
                            if !isFullTank {
                                Text("不加满时无法计算本次油耗")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
                
                Section(header: Text("时间")) {
                    Button(action: { showDatePicker = true }) {
                        HStack {
                            Text("加油时间")
                            Spacer()
                            Text(date, style: .date)
                                .foregroundColor(.blue)
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                Section(header: Text("备注")) {
                    TextField("备注", text: $note)
                }
                
                if let pricePerLiter = calculatedPricePerLiter {
                    Section {
                        HStack {
                            Text("单价（自动计算）")
                            Spacer()
                            Text(String(format: "%.2f 元/L", pricePerLiter))
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("编辑加油记录")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveRecord()
                    }
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showDatePicker) {
                NavigationView {
                    DatePicker("加油时间", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()
                        .navigationTitle("选择日期")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("确定") { showDatePicker = false }
                            }
                        }
                }
                .presentationDetents([.medium])
            }
        }
    }
    
    private var isValid: Bool {
        guard let odometer = Double(odometer), odometer > 0,
              let fuel = Double(fuelAmount), fuel > 0,
              let total = Double(totalPrice), total > 0 else {
            return false
        }
        return true
    }
    
    private func saveRecord() {
        guard let odometer = Double(odometer),
              let fuel = Double(fuelAmount),
              let total = Double(totalPrice) else { return }
        
        var updated = record
        updated.odometer = odometer
        updated.fuelAmount = fuel
        updated.totalPrice = total
        updated.pricePerLiter = fuel > 0 ? total / fuel : 0
        updated.isFullTank = isFullTank
        updated.date = date
        updated.note = note
        
        dataStore.updateFuelRecord(updated, in: vehicle)
        dismiss()
    }
}

// 添加充电记录
struct AddChargeRecordView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    
    let vehicle: Vehicle
    
    @State private var odometer = ""
    @State private var totalPrice = ""
    @State private var chargeAmount = ""
    @State private var startBatteryPercent = ""
    @State private var endBatteryPercent = "100"
    @State private var chargeTime = ""
    @State private var date = Date()
    @State private var note = ""
    @State private var showDatePicker = false
    
    private var lastOdometer: Double? {
        // 混动车显示上一次里程（加油和充电都算）
        if vehicle.type == .hybrid {
            return vehicle.lastOdometer
        }
        return vehicle.chargeRecords.map(\.odometer).max()
    }
    
    private var calculatedPricePerKwh: Double? {
        guard let charge = Double(chargeAmount), charge > 0,
              let total = Double(totalPrice) else { return nil }
        return total / charge
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("充电信息")) {
                    HStack {
                        Text("里程(km)")
                            .frame(width: 80, alignment: .leading)
                        TextField("必填", text: $odometer)
                            .keyboardType(.decimalPad)
                        if let last = lastOdometer {
                            Text("上次: \(Int(last))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    HStack {
                        Text("实付金额(元)")
                            .frame(width: 80, alignment: .leading)
                        TextField("必填", text: $totalPrice)
                            .keyboardType(.decimalPad)
                    }
                    
                    HStack {
                        Text("充电量(kWh)")
                            .frame(width: 80, alignment: .leading)
                        TextField("必填", text: $chargeAmount)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section(header: Text("电量百分比")) {
                    HStack {
                        Text("开始电量%")
                            .frame(width: 80, alignment: .leading)
                        TextField("如: 20", text: $startBatteryPercent)
                            .keyboardType(.decimalPad)
                        Text("%")
                    }
                    
                    HStack {
                        Text("结束电量%")
                            .frame(width: 80, alignment: .leading)
                        TextField("如: 100", text: $endBatteryPercent)
                            .keyboardType(.decimalPad)
                        Text("%")
                    }
                    
                    Text("记录充电开始和结束时的电池百分比")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("充电时长（选填）")) {
                    HStack {
                        Text("时长(分钟)")
                            .frame(width: 80, alignment: .leading)
                        TextField("选填", text: $chargeTime)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section(header: Text("时间")) {
                    Button(action: { showDatePicker = true }) {
                        HStack {
                            Text("充电时间")
                            Spacer()
                            Text(date, style: .date)
                                .foregroundColor(.blue)
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                Section(header: Text("备注（选填）")) {
                    TextField("如：充电站名称", text: $note)
                }
                
                if let pricePerKwh = calculatedPricePerKwh {
                    Section {
                        HStack {
                            Text("单价（自动计算）")
                            Spacer()
                            Text(String(format: "%.2f 元/kWh", pricePerKwh))
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .navigationTitle("添加充电记录")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveRecord()
                    }
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showDatePicker) {
                NavigationView {
                    DatePicker("充电时间", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()
                        .navigationTitle("选择日期")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("确定") { showDatePicker = false }
                            }
                        }
                }
                .presentationDetents([.medium])
            }
        }
    }
    
    private var isValid: Bool {
        guard let odometer = Double(odometer), odometer > 0,
              let total = Double(totalPrice), total > 0,
              let charge = Double(chargeAmount), charge > 0 else {
            return false
        }
        // 电量百分比可选，但如果有值需要合理
        if let start = Double(startBatteryPercent), let end = Double(endBatteryPercent) {
            return start >= 0 && start <= 100 && end >= 0 && end <= 100 && end >= start
        }
        return true
    }
    
    private func saveRecord() {
        guard let odometer = Double(odometer),
              let total = Double(totalPrice),
              let charge = Double(chargeAmount) else { return }
        
        let startPercent = Double(startBatteryPercent) ?? 0
        let endPercent = Double(endBatteryPercent) ?? 100
        let time: Double? = Double(chargeTime)
        
        dataStore.addChargeRecord(
            to: vehicle,
            odometer: odometer,
            chargeAmount: charge,
            totalPrice: total,
            startBatteryPercent: startPercent,
            endBatteryPercent: endPercent,
            chargeTime: time,
            date: date,
            note: note
        )
        dismiss()
    }
}

// 编辑充电记录
struct EditChargeRecordView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    
    let vehicle: Vehicle
    @State var record: ChargeRecord
    
    @State private var odometer: String
    @State private var totalPrice: String
    @State private var chargeAmount: String
    @State private var startBatteryPercent: String
    @State private var endBatteryPercent: String
    @State private var chargeTime: String
    @State private var date: Date
    @State private var note: String
    @State private var showDatePicker = false
    
    private var calculatedPricePerKwh: Double? {
        guard let charge = Double(chargeAmount), charge > 0,
              let total = Double(totalPrice) else { return nil }
        return total / charge
    }
    
    init(vehicle: Vehicle, record: ChargeRecord) {
        self.vehicle = vehicle
        self._record = State(initialValue: record)
        self._odometer = State(initialValue: String(format: "%.0f", record.odometer))
        self._totalPrice = State(initialValue: String(format: "%.2f", record.totalPrice))
        self._chargeAmount = State(initialValue: String(format: "%.2f", record.chargeAmount))
        self._startBatteryPercent = State(initialValue: String(format: "%.0f", record.startBatteryPercent))
        self._endBatteryPercent = State(initialValue: String(format: "%.0f", record.endBatteryPercent))
        self._chargeTime = State(initialValue: record.chargeTime.map { String(format: "%.0f", $0) } ?? "")
        self._date = State(initialValue: record.date)
        self._note = State(initialValue: record.note)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("充电信息")) {
                    HStack {
                        Text("里程(km)")
                            .frame(width: 80, alignment: .leading)
                        TextField("必填", text: $odometer)
                            .keyboardType(.decimalPad)
                    }
                    
                    HStack {
                        Text("实付金额(元)")
                            .frame(width: 80, alignment: .leading)
                        TextField("必填", text: $totalPrice)
                            .keyboardType(.decimalPad)
                    }
                    
                    HStack {
                        Text("充电量(kWh)")
                            .frame(width: 80, alignment: .leading)
                        TextField("必填", text: $chargeAmount)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section(header: Text("电量百分比")) {
                    HStack {
                        Text("开始电量%")
                            .frame(width: 80, alignment: .leading)
                        TextField("如: 20", text: $startBatteryPercent)
                            .keyboardType(.decimalPad)
                        Text("%")
                    }
                    
                    HStack {
                        Text("结束电量%")
                            .frame(width: 80, alignment: .leading)
                        TextField("如: 100", text: $endBatteryPercent)
                            .keyboardType(.decimalPad)
                        Text("%")
                    }
                }
                
                Section(header: Text("充电时长（选填）")) {
                    HStack {
                        Text("时长(分钟)")
                            .frame(width: 80, alignment: .leading)
                        TextField("选填", text: $chargeTime)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section(header: Text("时间")) {
                    Button(action: { showDatePicker = true }) {
                        HStack {
                            Text("充电时间")
                            Spacer()
                            Text(date, style: .date)
                                .foregroundColor(.blue)
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                Section(header: Text("备注")) {
                    TextField("备注", text: $note)
                }
                
                if let pricePerKwh = calculatedPricePerKwh {
                    Section {
                        HStack {
                            Text("单价（自动计算）")
                            Spacer()
                            Text(String(format: "%.2f 元/kWh", pricePerKwh))
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .navigationTitle("编辑充电记录")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveRecord()
                    }
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showDatePicker) {
                NavigationView {
                    DatePicker("充电时间", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()
                        .navigationTitle("选择日期")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("确定") { showDatePicker = false }
                            }
                        }
                }
                .presentationDetents([.medium])
            }
        }
    }
    
    private var isValid: Bool {
        guard let odometer = Double(odometer), odometer > 0,
              let total = Double(totalPrice), total > 0,
              let charge = Double(chargeAmount), charge > 0 else {
            return false
        }
        return true
    }
    
    private func saveRecord() {
        guard let odometer = Double(odometer),
              let total = Double(totalPrice),
              let charge = Double(chargeAmount) else { return }
        
        let startPercent = Double(startBatteryPercent) ?? 0
        let endPercent = Double(endBatteryPercent) ?? 100
        let time: Double? = Double(chargeTime)
        
        var updated = record
        updated.odometer = odometer
        updated.totalPrice = total
        updated.chargeAmount = charge
        updated.pricePerKwh = charge > 0 ? total / charge : 0
        updated.startBatteryPercent = startPercent
        updated.endBatteryPercent = endPercent
        updated.chargeTime = time
        updated.date = date
        updated.note = note
        
        dataStore.updateChargeRecord(updated, in: vehicle)
        dismiss()
    }
}

#Preview {
    AddFuelRecordView(vehicle: Vehicle(name: "测试车辆"))
        .environmentObject(DataStore())
}