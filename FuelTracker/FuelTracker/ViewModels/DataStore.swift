import Foundation
import SwiftUI

class DataStore: ObservableObject {
    @Published var vehicles: [Vehicle] = []
    
    private let saveKey = "fueltracker_vehicles"
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    init() {
        loadVehicles()
    }
    
    // 加载数据
    func loadVehicles() {
        let fileURL = documentsPath.appendingPathComponent("vehicles.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([Vehicle].self, from: data) {
            vehicles = decoded
            return
        }
        
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Vehicle].self, from: data) {
            vehicles = decoded
        }
    }
    
    // 保存数据
    func saveVehicles() {
        let fileURL = documentsPath.appendingPathComponent("vehicles.json")
        if let encoded = try? JSONEncoder().encode(vehicles) {
            try? encoded.write(to: fileURL)
        }
        
        if let encoded = try? JSONEncoder().encode(vehicles) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    // 添加车辆
    func addVehicle(name: String, plateNumber: String = "", type: VehicleType = .fuel) -> Bool {
        // 检查车牌是否已存在
        if !plateNumber.isEmpty && vehicles.contains(where: { $0.plateNumber == plateNumber }) {
            return false
        }
        
        let vehicle = Vehicle(name: name, plateNumber: plateNumber, type: type)
        vehicles.append(vehicle)
        saveVehicles()
        return true
    }
    
    // 更新车辆
    func updateVehicle(_ vehicle: Vehicle) -> Bool {
        // 检查车牌是否被其他车辆使用
        if !vehicle.plateNumber.isEmpty && vehicles.contains(where: { $0.id != vehicle.id && $0.plateNumber == vehicle.plateNumber }) {
            return false
        }
        
        guard let index = vehicles.firstIndex(where: { $0.id == vehicle.id }) else { return false }
        vehicles[index] = vehicle
        saveVehicles()
        return true
    }
    
    // 检查车牌是否已存在
    func isPlateNumberExists(_ plateNumber: String, excludeVehicleId: UUID? = nil) -> Bool {
        if plateNumber.isEmpty { return false }
        return vehicles.contains(where: { $0.plateNumber == plateNumber && $0.id != excludeVehicleId })
    }
    
    // 删除车辆
    func deleteVehicle(_ vehicle: Vehicle) {
        vehicles.removeAll { $0.id == vehicle.id }
        saveVehicles()
    }
    
    // 添加加油记录
    func addFuelRecord(to vehicle: Vehicle, odometer: Double, fuelAmount: Double, totalPrice: Double, isFullTank: Bool = true, date: Date = Date(), note: String = "") {
        guard let index = vehicles.firstIndex(where: { $0.id == vehicle.id }) else { return }
        let record = FuelRecord(odometer: odometer, fuelAmount: fuelAmount, totalPrice: totalPrice, isFullTank: isFullTank, date: date, note: note)
        vehicles[index].fuelRecords.append(record)
        saveVehicles()
    }
    
    // 删除加油记录
    func deleteFuelRecord(_ record: FuelRecord, from vehicle: Vehicle) {
        guard let vehicleIndex = vehicles.firstIndex(where: { $0.id == vehicle.id }) else { return }
        vehicles[vehicleIndex].fuelRecords.removeAll { $0.id == record.id }
        saveVehicles()
    }
    
    // 更新加油记录
    func updateFuelRecord(_ record: FuelRecord, in vehicle: Vehicle) {
        guard let vehicleIndex = vehicles.firstIndex(where: { $0.id == vehicle.id }),
              let recordIndex = vehicles[vehicleIndex].fuelRecords.firstIndex(where: { $0.id == record.id }) else { return }
        vehicles[vehicleIndex].fuelRecords[recordIndex] = record
        saveVehicles()
    }
    
    // 添加充电记录
    func addChargeRecord(to vehicle: Vehicle, odometer: Double, chargeAmount: Double, totalPrice: Double, startBatteryPercent: Double = 0, endBatteryPercent: Double = 100, chargeTime: Double? = nil, date: Date = Date(), note: String = "") {
        guard let index = vehicles.firstIndex(where: { $0.id == vehicle.id }) else { return }
        let record = ChargeRecord(odometer: odometer, chargeAmount: chargeAmount, totalPrice: totalPrice, startBatteryPercent: startBatteryPercent, endBatteryPercent: endBatteryPercent, chargeTime: chargeTime, date: date, note: note)
        vehicles[index].chargeRecords.append(record)
        saveVehicles()
    }
    
    // 删除充电记录
    func deleteChargeRecord(_ record: ChargeRecord, from vehicle: Vehicle) {
        guard let vehicleIndex = vehicles.firstIndex(where: { $0.id == vehicle.id }) else { return }
        vehicles[vehicleIndex].chargeRecords.removeAll { $0.id == record.id }
        saveVehicles()
    }
    
    // 更新充电记录
    func updateChargeRecord(_ record: ChargeRecord, in vehicle: Vehicle) {
        guard let vehicleIndex = vehicles.firstIndex(where: { $0.id == vehicle.id }),
              let recordIndex = vehicles[vehicleIndex].chargeRecords.firstIndex(where: { $0.id == record.id }) else { return }
        vehicles[vehicleIndex].chargeRecords[recordIndex] = record
        saveVehicles()
    }
    
    // 兼容旧版本的 addRecord 方法
    func addRecord(to vehicle: Vehicle, odometer: Double, fuelAmount: Double, totalPrice: Double, date: Date = Date(), note: String = "") {
        addFuelRecord(to: vehicle, odometer: odometer, fuelAmount: fuelAmount, totalPrice: totalPrice, date: date, note: note)
    }
    
    // 兼容旧版本的 deleteRecord 方法
    func deleteRecord(_ record: FuelRecord, from vehicle: Vehicle) {
        deleteFuelRecord(record, from: vehicle)
    }
    
    // 兼容旧版本的 updateRecord 方法
    func updateRecord(_ record: FuelRecord, in vehicle: Vehicle) {
        updateFuelRecord(record, in: vehicle)
    }
    
    // 获取导出数据字符串
    func getExportString() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        guard let data = try? encoder.encode(vehicles) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}