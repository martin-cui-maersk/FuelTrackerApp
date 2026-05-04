import SwiftUI
import UniformTypeIdentifiers

struct VehicleListView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var showingAddVehicle = false
    @State private var showingImportPicker = false
    @State private var showingExportSheet = false
    @State private var showingAbout = false
    @State private var showingSettings = false
    @State private var importError = ""
    @State private var showingImportError = false
    @State private var pendingImportData: ImportDataWrapper?
    @State private var selectedExportVehicles: Set<UUID> = []
    @State private var selectedImportVehicles: Set<UUID> = []
    @State private var vehicleToDelete: Vehicle?
    @State private var showingDeleteConfirm = false
    
    var body: some View {
        NavigationView {
            List {
                if dataStore.vehicles.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("暂无车辆")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("点击右上角 + 添加第一辆车")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                } else {
                    ForEach(dataStore.vehicles) { vehicle in
                        NavigationLink(destination: VehicleDetailView(vehicleId: vehicle.id)) {
                            VehicleRowView(vehicle: vehicle)
                        }
                    }
                    .onDelete { indexSet in
                        if let index = indexSet.first {
                            vehicleToDelete = dataStore.vehicles[index]
                            showingDeleteConfirm = true
                        }
                    }
                }
            }
            .navigationTitle("油耗记录")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button(action: { 
                            selectedExportVehicles = Set(dataStore.vehicles.map { $0.id })
                            showingExportSheet = true 
                        }) {
                            Label("导出数据", systemImage: "square.and.arrow.up")
                        }
                        Button(action: { showingImportPicker = true }) {
                            Label("导入数据", systemImage: "square.and.arrow.down")
                        }
                        Divider()
                        Button(action: { showingSettings = true }) {
                            Label("设置", systemImage: "gearshape")
                        }
                        Button(action: { showingAbout = true }) {
                            Label("关于", systemImage: "info.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddVehicle = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddVehicle) {
                AddVehicleView()
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(item: $pendingImportData) { wrapper in
                ImportVehicleSelectView(
                    importedVehicles: wrapper.vehicles,
                    existingVehicles: dataStore.vehicles,
                    selectedVehicles: $selectedImportVehicles,
                    onImport: { mode, selectedIds in
                        performImport(mode: mode, selectedVehicleIds: selectedIds)
                    }
                )
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        loadImportFile(url: url)
                    }
                case .failure(let error):
                    importError = error.localizedDescription
                    showingImportError = true
                }
            }
            .sheet(isPresented: $showingExportSheet) {
                ExportVehicleSelectionView(
                    vehicles: dataStore.vehicles,
                    selectedVehicles: $selectedExportVehicles
                )
            }
            .alert("导入失败", isPresented: $showingImportError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(importError)
            }
            .alert("删除车辆", isPresented: $showingDeleteConfirm) {
                Button("取消", role: .cancel) { 
                    vehicleToDelete = nil
                }
                Button("删除", role: .destructive) {
                    if let vehicle = vehicleToDelete {
                        dataStore.deleteVehicle(vehicle)
                    }
                    vehicleToDelete = nil
                }
            } message: {
                if let vehicle = vehicleToDelete {
                    Text("确定要删除「\(vehicle.name)」吗？\n该车辆的所有加油/充电记录将被删除。")
                } else {
                    Text("确定要删除吗？")
                }
            }
        }
    }
    
    // 加载导入文件
    private func loadImportFile(url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            importError = "无法访问文件"
            showingImportError = true
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let vehicles = try decoder.decode([Vehicle].self, from: data)
            selectedImportVehicles = Set(vehicles.map { $0.id })
            pendingImportData = ImportDataWrapper(vehicles: vehicles)
        } catch {
            importError = "导入失败: \(error.localizedDescription)"
            showingImportError = true
        }
    }
    
    // 执行导入
    private func performImport(mode: ImportVehicleSelectView.ImportMode, selectedVehicleIds: Set<UUID>) {
        guard let importedVehicles = pendingImportData?.vehicles else { return }
        
        let vehiclesToImport = importedVehicles.filter { selectedVehicleIds.contains($0.id) }
        
        switch mode {
        case .replace:
            dataStore.vehicles.removeAll { selectedVehicleIds.contains($0.id) }
            dataStore.vehicles.append(contentsOf: vehiclesToImport)
            dataStore.saveVehicles()
            
        case .merge:
            for importedVehicle in vehiclesToImport {
                if let existingIndex = dataStore.vehicles.firstIndex(where: { $0.id == importedVehicle.id }) {
                    var existingVehicle = dataStore.vehicles[existingIndex]
                    for record in importedVehicle.fuelRecords {
                        if !existingVehicle.fuelRecords.contains(where: { $0.id == record.id }) {
                            existingVehicle.fuelRecords.append(record)
                        }
                    }
                    for record in importedVehicle.chargeRecords {
                        if !existingVehicle.chargeRecords.contains(where: { $0.id == record.id }) {
                            existingVehicle.chargeRecords.append(record)
                        }
                    }
                    dataStore.vehicles[existingIndex] = existingVehicle
                } else {
                    dataStore.vehicles.append(importedVehicle)
                }
            }
            dataStore.saveVehicles()
        }
        
        pendingImportData = nil
    }
}

// MARK: - Vehicle Row View

struct VehicleRowView: View {
    let vehicle: Vehicle
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: vehicle.type.icon)
                    .foregroundColor(.blue)
                    .font(.title2)
                VStack(alignment: .leading) {
                    HStack {
                        Text(vehicle.name)
                            .font(.headline)
                        Text(vehicle.type.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                    if !vehicle.plateNumber.isEmpty {
                        Text(vehicle.plateNumber)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("\(vehicle.fuelRecords.count + vehicle.chargeRecords.count) 条记录")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 显示统计数据
            HStack(spacing: 16) {
                if let costPerKm = vehicle.averageCostPerKm {
                    HStack(spacing: 4) {
                        Image(systemName: "yensign.circle.fill")
                            .foregroundColor(.blue)
                        Text(String(format: "%.2f 元/km", costPerKm))
                            .font(.subheadline)
                    }
                }
                
                if let avgPerDay = vehicle.averageDistancePerDay {
                    HStack(spacing: 4) {
                        Image(systemName: "road.lanes")
                            .foregroundColor(.purple)
                        Text(String(format: "%.0f km/天", avgPerDay))
                            .font(.subheadline)
                    }
                }
                
                if vehicle.type != .electric, let avgFuel = vehicle.averageFuelConsumption {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text(String(format: "%.2f L/100km", avgFuel))
                            .font(.subheadline)
                    }
                }
                
                if vehicle.type != .fuel, let avgElectric = vehicle.averageElectricConsumption {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.green)
                        Text(String(format: "%.2f kWh/100km", avgElectric))
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Vehicle View

struct AddVehicleView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var plateNumber = ""
    @State private var vehicleType: VehicleType = .fuel
    @State private var showError = false
    @State private var errorMessage = ""
    
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
                        .onTapGesture { vehicleType = type }
                    }
                    
                    HStack {
                        Image(systemName: vehicleType.icon)
                            .foregroundColor(.blue)
                        Text(typeDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("添加车辆")
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
            .alert("添加失败", isPresented: $showError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var typeDescription: String {
        switch vehicleType {
        case .fuel: return "记录加油，计算油耗"
        case .electric: return "记录充电，计算电耗"
        case .hybrid: return "可记录加油和充电"
        }
    }
    
    private func saveVehicle() {
        if dataStore.isPlateNumberExists(plateNumber) {
            errorMessage = "车牌号「\(plateNumber)」已存在"
            showError = true
            return
        }
        
        if dataStore.addVehicle(name: name, plateNumber: plateNumber, type: vehicleType) {
            dismiss()
        } else {
            errorMessage = "添加失败，请重试"
            showError = true
        }
    }
}

#Preview {
    VehicleListView()
        .environmentObject(DataStore())
}
