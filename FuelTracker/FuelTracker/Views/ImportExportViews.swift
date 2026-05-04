import SwiftUI
import UniformTypeIdentifiers

// MARK: - Export Vehicle Selection View

struct ExportVehicleSelectionView: View {
    let vehicles: [Vehicle]
    @Binding var selectedVehicles: Set<UUID>
    @Environment(\.dismiss) var dismiss
    @State private var showingExporter = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(vehicles) { vehicle in
                    Button(action: {
                        if selectedVehicles.contains(vehicle.id) {
                            selectedVehicles.remove(vehicle.id)
                        } else {
                            selectedVehicles.insert(vehicle.id)
                        }
                    }) {
                        HStack {
                            Image(systemName: selectedVehicles.contains(vehicle.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedVehicles.contains(vehicle.id) ? .blue : .gray)
                            
                            VStack(alignment: .leading) {
                                Text(vehicle.name)
                                    .foregroundColor(.primary)
                                Text(vehicle.plateNumber)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("选择要导出的车辆")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("导出") {
                        showingExporter = true
                    }
                    .disabled(selectedVehicles.isEmpty)
                }
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: VehicleExportDocument(vehicles: vehicles.filter { selectedVehicles.contains($0.id) }),
                contentType: .json,
                defaultFilename: "FuelTracker_Export"
            ) { result in
                switch result {
                case .success:
                    dismiss()
                case .failure(let error):
                    print("Export failed: \(error)")
                }
            }
        }
    }
}

// MARK: - Import Vehicle Select View

struct ImportVehicleSelectView: View {
    let importedVehicles: [Vehicle]
    let existingVehicles: [Vehicle]
    @Binding var selectedVehicles: Set<UUID>
    @Environment(\.dismiss) var dismiss
    @State private var importMode: ImportMode = .merge
    var onImport: (ImportMode, Set<UUID>) -> Void
    
    enum ImportMode {
        case merge
        case replace
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Picker("导入方式", selection: $importMode) {
                        Text("合并").tag(ImportMode.merge)
                        Text("覆盖").tag(ImportMode.replace)
                    }
                    .pickerStyle(.segmented)
                    
                    Text(importMode == .merge ? "保留现有数据，追加新记录" : "选中的车辆将被替换")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Button("全选") {
                        selectedVehicles = Set(importedVehicles.map { $0.id })
                    }
                    Button("取消全选") {
                        selectedVehicles.removeAll()
                    }
                }
                
                Section(header: Text("选择要导入的车辆（\(selectedVehicles.count)/\(importedVehicles.count)）")) {
                    ForEach(importedVehicles) { vehicle in
                        Button(action: {
                            if selectedVehicles.contains(vehicle.id) {
                                selectedVehicles.remove(vehicle.id)
                            } else {
                                selectedVehicles.insert(vehicle.id)
                            }
                        }) {
                            HStack {
                                Image(systemName: selectedVehicles.contains(vehicle.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedVehicles.contains(vehicle.id) ? .blue : .gray)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(vehicle.name)
                                            .foregroundColor(.primary)
                                        
                                        if existingVehicles.contains(where: { $0.id == vehicle.id }) {
                                            Text("已存在")
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.orange.opacity(0.2))
                                                .foregroundColor(.orange)
                                                .cornerRadius(4)
                                        }
                                    }
                                    
                                    HStack(spacing: 12) {
                                        Text("\(vehicle.fuelRecords.count + vehicle.chargeRecords.count) 条记录")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        if !vehicle.plateNumber.isEmpty {
                                            Text(vehicle.plateNumber)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择导入车辆")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("导入") {
                        onImport(importMode, selectedVehicles)
                        dismiss()
                    }
                    .disabled(selectedVehicles.isEmpty)
                }
            }
        }
    }
}

// MARK: - Vehicle Export Document

struct VehicleExportDocument: FileDocument {
    var vehicles: [Vehicle]
    
    static var readableContentTypes: [UTType] { [.json] }
    
    init(vehicles: [Vehicle]) {
        self.vehicles = vehicles
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        vehicles = try decoder.decode([Vehicle].self, from: data)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(vehicles)
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Import Data Wrapper

class ImportDataWrapper: ObservableObject, Identifiable {
    let id = UUID()
    let vehicles: [Vehicle]
    
    init(vehicles: [Vehicle]) {
        self.vehicles = vehicles
    }
}

// MARK: - Previews

#Preview("Export") {
    ExportVehicleSelectionView(
        vehicles: [
            Vehicle(name: "测试车辆1", plateNumber: "京A12345", type: .fuel),
            Vehicle(name: "测试车辆2", plateNumber: "京B67890", type: .electric)
        ],
        selectedVehicles: .constant([])
    )
}

#Preview("Import") {
    ImportVehicleSelectView(
        importedVehicles: [
            Vehicle(name: "导入车辆1", plateNumber: "沪C11111", type: .hybrid)
        ],
        existingVehicles: [],
        selectedVehicles: .constant([]),
        onImport: { _, _ in }
    )
}