import Foundation

// 车辆类型
enum VehicleType: String, Codable, CaseIterable {
    case fuel = "油车"
    case electric = "纯电车"
    case hybrid = "混动车"
    
    var icon: String {
        switch self {
        case .fuel: return "fuelpump.fill"
        case .electric: return "bolt.fill"
        case .hybrid: return "bolt.car.fill"
        }
    }
}

struct Vehicle: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var plateNumber: String
    var type: VehicleType
    var createdAt: Date
    var fuelRecords: [FuelRecord]      // 加油记录
    var chargeRecords: [ChargeRecord]  // 充电记录
    
    init(id: UUID = UUID(), name: String, plateNumber: String = "", type: VehicleType = .fuel) {
        self.id = id
        self.name = name
        self.plateNumber = plateNumber
        self.type = type
        self.createdAt = Date()
        self.fuelRecords = []
        self.chargeRecords = []
    }
    
    // 兼容旧数据的初始化
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        plateNumber = try container.decodeIfPresent(String.self, forKey: .plateNumber) ?? ""
        type = try container.decodeIfPresent(VehicleType.self, forKey: .type) ?? .fuel
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        fuelRecords = try container.decodeIfPresent([FuelRecord].self, forKey: .fuelRecords) ?? []
        chargeRecords = try container.decodeIfPresent([ChargeRecord].self, forKey: .chargeRecords) ?? []
        
        // 兼容旧版本的 records 字段
        if fuelRecords.isEmpty {
            fuelRecords = try container.decodeIfPresent([FuelRecord].self, forKey: .records) ?? []
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(plateNumber, forKey: .plateNumber)
        try container.encode(type, forKey: .type)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(fuelRecords, forKey: .fuelRecords)
        try container.encode(chargeRecords, forKey: .chargeRecords)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, plateNumber, type, createdAt, fuelRecords, chargeRecords, records
    }
    
    // 计算总里程
    var totalDistance: Double {
        let allOdometers = fuelRecords.map { $0.odometer } + chargeRecords.map { $0.odometer }
        guard let minOdo = allOdometers.min(), let maxOdo = allOdometers.max(), maxOdo > minOdo else { return 0 }
        return maxOdo - minOdo
    }
    
    // 获取所有记录的最大里程（加油和充电都算）
    var lastOdometer: Double? {
        let fuelMax = fuelRecords.map(\.odometer).max()
        let chargeMax = chargeRecords.map(\.odometer).max()
        
        if let f = fuelMax, let c = chargeMax {
            return max(f, c)
        }
        return fuelMax ?? chargeMax
    }
    
    // 计算总加油量（用整数累加避免浮点精度误差，以"毫升"为单位）
    var totalFuel: Double {
        // 每条记录的加油量转换为毫升（整数），累加后再转换为升
        let totalInMl = fuelRecords.reduce(0) { $0 + Int(round($1.fuelAmount * 1000)) }
        return Double(totalInMl) / 1000.0
    }
    
    // 计算总充电量（用整数累加避免浮点精度误差，以"Wh"为单位）
    var totalCharge: Double {
        // 每条记录的充电量转换为Wh（整数），累加后再转换为kWh
        let totalInWh = chargeRecords.reduce(0) { $0 + Int(round($1.chargeAmount * 1000)) }
        return Double(totalInWh) / 1000.0
    }
    
    // 计算总花费（用整数累加避免浮点精度误差，以"分"为单位）
    var totalCost: Double {
        // 每条记录的金额转换为分（整数），累加后再转换为元
        let fuelCostInCents = fuelRecords.reduce(0) { $0 + Int(round($1.totalPrice * 100)) }
        let chargeCostInCents = chargeRecords.reduce(0) { $0 + Int(round($1.totalPrice * 100)) }
        return Double(fuelCostInCents + chargeCostInCents) / 100.0
    }
    
    // 计算用于油耗统计的加油量（所有加满记录都参与计算，用整数累加）
    // 实际耗油量 = 总加满加油量 - 第一次加满加油量（公认公式）
    var fuelForConsumption: Double {
        let sorted = fuelRecords.sorted { $0.odometer < $1.odometer }
        let fullTankRecords = sorted.filter { $0.isFullTank }
        guard fullTankRecords.count >= 2 else { return 0 }
        
        // 所有加满记录的加油量（跳过第一条，用毫升累加）
        // 第一条加满是初始油量，不算消耗
        let totalInMl = fullTankRecords.dropFirst().reduce(0) { $0 + Int(round($1.fuelAmount * 1000)) }
        return Double(totalInMl) / 1000.0
    }
    
    // 计算用于油耗统计的里程（所有加满记录都参与计算）
    var distanceForFuelConsumption: Double {
        let sorted = fuelRecords.sorted { $0.odometer < $1.odometer }
        let fullTankRecords = sorted.filter { $0.isFullTank }
        guard fullTankRecords.count >= 2 else { return 0 }
        
        // 所有加满记录之间的里程（第一条加满到最后一条加满的距离）
        let firstOdo = fullTankRecords.first!.odometer
        let lastOdo = fullTankRecords.last!.odometer
        return lastOdo - firstOdo
    }
    
    // 加权平均油耗计算（小熊油耗算法）
    // 平均油耗 = Σ(单次油耗 × 权重)，权重 = 单次行程 / 行程总和
    var weightedAverageFuelConsumption: Double? {
        guard type != .electric else { return nil }
        
        let sorted = fuelRecords.sorted { $0.odometer < $1.odometer }
        guard sorted.count >= 2 else { return nil }
        
        // 小熊油耗加权平均算法
        // 平均油耗 = Σ(单次油耗 × 权重)，权重 = 单次行程 / 行程总和
        
        var totalDistance = 0.0      // 行程总和
        var weightedSum = 0.0        // 油耗 × 行程 的总和
        
        for i in 1..<sorted.count {
            let prev = sorted[i - 1]
            let current = sorted[i]
            let distance = current.odometer - prev.odometer
            
            if distance > 0 {
                // 单次油耗 = 本次加油量 / 行程 × 100
                let singleConsumption = current.fuelAmount / distance * 100
                weightedSum += singleConsumption * distance
                totalDistance += distance
            }
        }
        
        guard totalDistance > 0 else { return nil }
        
        // 加权平均 = Σ(油耗×行程) / 总行程
        let result = weightedSum / totalDistance
        return round(result * 100) / 100  // 保留两位小数
    }
    
    // 计算用于电耗统计的充电量（用整数累加，从第二条开始）
    var chargeForConsumption: Double {
        guard chargeRecords.count >= 2 else { return 0 }
        let sorted = chargeRecords.sorted { $0.odometer < $1.odometer }
        // 用Wh累加避免浮点误差
        let totalInWh = sorted.dropFirst().reduce(0) { $0 + Int(round($1.chargeAmount * 1000)) }
        return Double(totalInWh) / 1000.0
    }
    
    // 计算用于电耗统计的里程
    var distanceForChargeConsumption: Double {
        guard chargeRecords.count >= 2 else { return 0 }
        let sorted = chargeRecords.sorted { $0.odometer < $1.odometer }
        guard let first = sorted.first, let last = sorted.last else { return 0 }
        return last.odometer - first.odometer
    }
    
    // 加权平均电耗计算（小熊油耗算法）
    // 平均电耗 = Σ(单次电耗 × 权重)，权重 = 单次行程 / 行程总和
    var weightedAverageElectricConsumption: Double? {
        guard type != .fuel, chargeRecords.count >= 2 else { return nil }
        
        let sorted = chargeRecords.sorted { $0.odometer < $1.odometer }
        
        // 计算每段行程和电耗
        var totalDistance = 0.0
        var weightedSum = 0.0
        
        for i in 1..<sorted.count {
            let prevRecord = sorted[i - 1]
            let currentRecord = sorted[i]
            let distance = currentRecord.odometer - prevRecord.odometer
            
            if distance > 0 && currentRecord.chargeAmount > 0 {
                // 单次电耗 = 本次充电量 / 行程 × 100
                let singleConsumption = currentRecord.chargeAmount / distance * 100
                weightedSum += singleConsumption * distance  // 电耗 × 行程（后续除以总行程）
                totalDistance += distance
            }
        }
        
        guard totalDistance > 0 else { return nil }
        
        // 加权平均 = Σ(电耗×行程) / 总行程
        let result = weightedSum / totalDistance
        return round(result * 100) / 100  // 保留两位小数
    }
    
    // 平均油耗（升/百公里）- 使用加权平均算法（小熊油耗算法）
    // 平均油耗 = Σ(单次油耗 × 权重)，权重 = 单次行程 / 行程总和
    var averageFuelConsumption: Double? {
        return weightedAverageFuelConsumption
    }
    
    // 平均电耗（kWh/百公里）- 使用加权平均算法
    var averageElectricConsumption: Double? {
        return weightedAverageElectricConsumption
    }
    
    // 用于计算每公里花费的加油金额（从第二条开始，用整数累加）
    var fuelCostForConsumption: Double {
        let sorted = fuelRecords.sorted { $0.odometer < $1.odometer }
        guard sorted.count >= 2 else { return 0 }
        // 用分累加避免浮点误差
        let totalInCents = sorted.dropFirst().reduce(0) { $0 + Int(round($1.totalPrice * 100)) }
        return Double(totalInCents) / 100.0
    }
    
    // 用于计算每公里花费的充电金额（从第二条开始，用整数累加）
    var chargeCostForConsumption: Double {
        let sorted = chargeRecords.sorted { $0.odometer < $1.odometer }
        guard sorted.count >= 2 else { return 0 }
        // 用分累加避免浮点误差
        let totalInCents = sorted.dropFirst().reduce(0) { $0 + Int(round($1.totalPrice * 100)) }
        return Double(totalInCents) / 100.0
    }
    
    // 平均每公里费用 - 用里程差和后续记录金额计算
    var averageCostPerKm: Double? {
        var totalCostForCalc: Double = 0
        var totalDistanceForCalc: Double = 0
        
        // 油车和混动车：计算加油每公里花费
        if type != .electric && fuelRecords.count >= 2 {
            totalCostForCalc += fuelCostForConsumption
            totalDistanceForCalc += distanceForFuelConsumption
        }
        
        // 电车和混动车：计算充电每公里花费
        if type != .fuel && chargeRecords.count >= 2 {
            totalCostForCalc += chargeCostForConsumption
            totalDistanceForCalc += distanceForChargeConsumption
        }
        
        guard totalDistanceForCalc > 0 else { return nil }
        let result = totalCostForCalc / totalDistanceForCalc
        return round(result * 100) / 100  // 保留两位小数
    }
    
    // 平均每天行程（公里/天）
    var averageDistancePerDay: Double? {
        let allOdometers = fuelRecords.map { $0.odometer } + chargeRecords.map { $0.odometer }
        guard let minOdo = allOdometers.min(), let maxOdo = allOdometers.max(), maxOdo > minOdo else { return nil }
        
        // 计算天数
        let allDates = fuelRecords.map { $0.date } + chargeRecords.map { $0.date }
        guard let minDate = allDates.min(), let maxDate = allDates.max() else { return nil }
        
        let days = Calendar.current.dateComponents([.day], from: minDate, to: maxDate).day ?? 0
        guard days > 0 else { return nil }
        
        return (maxOdo - minOdo) / Double(days)
    }
    
    // 每次加油的里程差（所有记录都计算，不只是加满）
    func distanceForFuelRecord(_ record: FuelRecord) -> Double? {
        let sorted = fuelRecords.sorted { $0.odometer < $1.odometer }
        guard let index = sorted.firstIndex(where: { $0.id == record.id }) else { return nil }
        guard index > 0 else { return nil } // 第一条无法计算
        
        let prevRecord = sorted[index - 1]
        let distance = record.odometer - prevRecord.odometer
        return distance
    }
    
    // 每次加油的行程油费支出
    // 都用区间总行程油费：区间总加油量 × 区间上次油价
    // 每次加油的行程燃油消耗量（用油耗和公里差计算）
    // 行程燃油量 = 油耗(L/100km) × 公里差(km) / 100
    func tripFuelAmountForRecord(_ record: FuelRecord) -> Double? {
        guard let consumption = fuelConsumptionForRecord(record) else { return nil }
        guard let distance = distanceForFuelRecord(record), distance > 0 else { return nil }
        
        return consumption * distance / 100
    }
    
    func tripFuelCostForRecord(_ record: FuelRecord) -> Double? {
        // 行程油费 = 行程燃油量 × 上次油价
        guard let tripAmount = tripFuelAmountForRecord(record) else { return nil }
        
        let sorted = fuelRecords.sorted { $0.odometer < $1.odometer }
        guard let index = sorted.firstIndex(where: { $0.id == record.id }) else { return nil }
        guard index > 0 else { return nil }
        
        // 上次油价
        let prevRecord = sorted[index - 1]
        
        return tripAmount * prevRecord.pricePerLiter
    }
    
    // 每次加油的油耗计算
    // 都用区间总油耗：找到上一个加满记录，计算从上一个加满到本次加满之间的总油耗
    // 如果中间有未加满记录，它们的油耗值也是这个区间油耗
    func fuelConsumptionForRecord(_ record: FuelRecord) -> Double? {
        let sorted = fuelRecords.sorted { $0.odometer < $1.odometer }
        guard let index = sorted.firstIndex(where: { $0.id == record.id }) else { return nil }
        guard index > 0 else { return nil } // 第一条无法计算
        
        // 找上一个加满记录
        var prevFullTankIndex = index - 1
        while prevFullTankIndex >= 0 && !sorted[prevFullTankIndex].isFullTank {
            prevFullTankIndex -= 1
        }
        guard prevFullTankIndex >= 0 && sorted[prevFullTankIndex].isFullTank else { return nil }
        
        // 如果当前是加满记录，计算从上一个加满到本次加满的区间油耗
        // 如果当前是未加满记录，需要找到下一个加满记录才能计算完整区间
        var nextFullTankIndex = index
        if !record.isFullTank {
            // 未加满记录：找下一个加满记录
            nextFullTankIndex = index + 1
            while nextFullTankIndex < sorted.count && !sorted[nextFullTankIndex].isFullTank {
                nextFullTankIndex += 1
            }
            guard nextFullTankIndex < sorted.count && sorted[nextFullTankIndex].isFullTank else { return nil }
        }
        
        // 计算区间总油耗
        let prevFullTank = sorted[prevFullTankIndex]
        let nextFullTank = sorted[nextFullTankIndex]
        let intervalDistance = nextFullTank.odometer - prevFullTank.odometer
        guard intervalDistance > 0 else { return nil }
        
        // 区间总加油量（从上次加满后到本次区间结束加满之间的所有加油）
        var intervalFuel = 0.0
        for i in (prevFullTankIndex + 1)..<(nextFullTankIndex + 1) {
            intervalFuel += sorted[i].fuelAmount
        }
        
        // 区间总油耗
        return intervalFuel / intervalDistance * 100
    }
    
    // 每次加油的每公里费用（用行程油费计算）
    // 每公里费用 = 行程油费 / 公里差 = (本次加油量 × 上次油价) / 公里差
    func fuelCostPerKmForRecord(_ record: FuelRecord) -> Double? {
        guard let tripCost = tripFuelCostForRecord(record) else { return nil }
        guard let distance = distanceForFuelRecord(record), distance > 0 else { return nil }
        
        return tripCost / distance
    }
    
    // 每次充电的里程差
    func distanceForChargeRecord(_ record: ChargeRecord) -> Double? {
        let sorted = chargeRecords.sorted { $0.odometer < $1.odometer }
        guard let index = sorted.firstIndex(where: { $0.id == record.id }) else { return nil }
        guard index > 0 else { return nil } // 第一条无法计算
        
        let prevRecord = sorted[index - 1]
        let distance = record.odometer - prevRecord.odometer
        return distance
    }
    
    // 每次充电的行程电费支出（用上次电价计算：电耗 × 公里差 × 上次电价）
    func tripChargeCostForRecord(_ record: ChargeRecord) -> Double? {
        guard record.chargeAmount > 0 else { return nil }
        
        let sorted = chargeRecords.sorted { $0.odometer < $1.odometer }
        guard let index = sorted.firstIndex(where: { $0.id == record.id }) else { return nil }
        guard index > 0 else { return nil } // 第一条无法计算
        
        let prevRecord = sorted[index - 1]
        let distance = record.odometer - prevRecord.odometer
        guard distance > 0 else { return nil }
        
        // 行程电费 = 充电量 × 上次电价
        let tripCost = record.chargeAmount * prevRecord.pricePerKwh
        return tripCost
    }
    
    // 每次充电的电耗计算（不需要充满，只要有充电量就计算）
    func chargeConsumptionForRecord(_ record: ChargeRecord) -> Double? {
        guard record.chargeAmount > 0 else { return nil }
        
        let sorted = chargeRecords.sorted { $0.odometer < $1.odometer }
        guard let index = sorted.firstIndex(where: { $0.id == record.id }),
              index > 0 else { return nil }
        
        let prevRecord = sorted[index - 1]
        let distance = record.odometer - prevRecord.odometer
        guard distance > 0 else { return nil }
        
        return record.chargeAmount / distance * 100
    }
    
    // 每次充电的每公里费用（用行程电费计算）
    // 每公里费用 = 行程电费 / 公里差 = (本次充电量 × 上次电价) / 公里差
    func chargeCostPerKmForRecord(_ record: ChargeRecord) -> Double? {
        guard let tripCost = tripChargeCostForRecord(record) else { return nil }
        guard let distance = distanceForChargeRecord(record), distance > 0 else { return nil }
        
        return tripCost / distance
    }
    
    // 获取所有记录按年月分组
    var recordsByYearMonth: [(year: Int, month: Int, fuelRecords: [FuelRecord], chargeRecords: [ChargeRecord])] {
        var result: [String: (year: Int, month: Int, fuelRecords: [FuelRecord], chargeRecords: [ChargeRecord])] = [:]
        
        let calendar = Calendar.current
        
        for record in fuelRecords {
            let components = calendar.dateComponents([.year, .month], from: record.date)
            if let year = components.year, let month = components.month {
                let key = "\(year)-\(month)"
                if var group = result[key] {
                    group.fuelRecords.append(record)
                    result[key] = group
                } else {
                    result[key] = (year: year, month: month, fuelRecords: [record], chargeRecords: [])
                }
            }
        }
        
        for record in chargeRecords {
            let components = calendar.dateComponents([.year, .month], from: record.date)
            if let year = components.year, let month = components.month {
                let key = "\(year)-\(month)"
                if var group = result[key] {
                    group.chargeRecords.append(record)
                    result[key] = group
                } else {
                    result[key] = (year: year, month: month, fuelRecords: [], chargeRecords: [record])
                }
            }
        }
        
        return result.values.sorted { ($0.year, $0.month) > ($1.year, $1.month) }
    }
    
    // 总加油次数
    var totalFuelCount: Int {
        fuelRecords.count
    }
    
    // 有效油耗记录数（加满记录数 - 1，第一条无法计算）
    var validFuelConsumptionCount: Int {
        let fullTankRecords = fuelRecords.filter { $0.isFullTank }
        guard fullTankRecords.count >= 2 else { return 0 }
        return fullTankRecords.count - 1  // 第一条加满无法计算油耗
    }
    
    // 总充电次数
    var totalChargeCount: Int {
        chargeRecords.count
    }
    
    // 有效电耗记录数（有充电量且不是第一条的记录数，可用于计算电耗）
    var validChargeConsumptionCount: Int {
        guard chargeRecords.count >= 2 else { return 0 }
        // 排序后，从第二条开始算有效记录
        let sorted = chargeRecords.sorted { $0.odometer < $1.odometer }
        return sorted.dropFirst().filter { $0.chargeAmount > 0 }.count
    }
    
    // 月度统计摘要（加油）- 增加加满次数信息
    func monthlyFuelSummary(year: Int, month: Int) -> (distance: Double, cost: Double, costPerKm: Double, fullTankCount: Int, totalCount: Int)? {
        let calendar = Calendar.current
        let monthRecords = fuelRecords.filter {
            let components = calendar.dateComponents([.year, .month], from: $0.date)
            return components.year == year && components.month == month
        }
        
        guard !monthRecords.isEmpty else { return nil }
        
        // 找到该月之前的最后一条记录
        let sortedMonthRecords = monthRecords.sorted { $0.odometer < $1.odometer }
        let firstOdoInMonth = sortedMonthRecords.first!.odometer
        
        // 找到该月之前所有记录中的最后一条
        let allRecordsBefore = fuelRecords.filter {
            let components = calendar.dateComponents([.year, .month], from: $0.date)
            return (components.year ?? 0) < year || ((components.year ?? 0) == year && (components.month ?? 0) < month)
        }
        
        let lastOdoBeforeMonth: Double
        if let lastBefore = allRecordsBefore.sorted(by: { $0.odometer < $1.odometer }).last?.odometer {
            lastOdoBeforeMonth = lastBefore
        } else {
            lastOdoBeforeMonth = firstOdoInMonth // 如果没有之前的记录，用本月第一条
        }
        
        let lastOdoInMonth = sortedMonthRecords.last!.odometer
        let distance = lastOdoInMonth - lastOdoBeforeMonth
        let cost = monthRecords.reduce(0) { $0 + $1.totalPrice }
        let costPerKm = distance > 0 ? cost / distance : 0
        
        // 统计加满次数
        let fullTankCount = monthRecords.filter { $0.isFullTank }.count
        let totalCount = monthRecords.count
        
        return (distance, cost, costPerKm, fullTankCount, totalCount)
    }
    
    // 月度统计摘要（充电）
    func monthlyChargeSummary(year: Int, month: Int) -> (distance: Double, cost: Double, costPerKm: Double)? {
        let calendar = Calendar.current
        let monthRecords = chargeRecords.filter {
            let components = calendar.dateComponents([.year, .month], from: $0.date)
            return components.year == year && components.month == month
        }
        
        guard !monthRecords.isEmpty else { return nil }
        
        let sortedMonthRecords = monthRecords.sorted { $0.odometer < $1.odometer }
        let firstOdoInMonth = sortedMonthRecords.first!.odometer
        
        let allRecordsBefore = chargeRecords.filter {
            let components = calendar.dateComponents([.year, .month], from: $0.date)
            return (components.year ?? 0) < year || ((components.year ?? 0) == year && (components.month ?? 0) < month)
        }
        
        let lastOdoBeforeMonth: Double
        if let lastBefore = allRecordsBefore.sorted(by: { $0.odometer < $1.odometer }).last?.odometer {
            lastOdoBeforeMonth = lastBefore
        } else {
            lastOdoBeforeMonth = firstOdoInMonth
        }
        
        let lastOdoInMonth = sortedMonthRecords.last!.odometer
        let distance = lastOdoInMonth - lastOdoBeforeMonth
        let cost = monthRecords.reduce(0) { $0 + $1.totalPrice }
        let costPerKm = distance > 0 ? cost / distance : 0
        
        return (distance, cost, costPerKm)
    }
    
    // 混动车合并记录（加油和充电混合，按里程排序）
    var allRecordsSorted: [HybridRecord] {
        var records: [HybridRecord] = []
        
        for record in fuelRecords {
            records.append(HybridRecord(odometer: record.odometer, date: record.date, fuelRecord: record, chargeRecord: nil))
        }
        
        for record in chargeRecords {
            records.append(HybridRecord(odometer: record.odometer, date: record.date, fuelRecord: nil, chargeRecord: record))
        }
        
        return records.sorted { $0.odometer > $1.odometer }
    }
}

// 混动车统一记录类型
struct HybridRecord: Identifiable {
    let id = UUID()
    let odometer: Double
    let date: Date
    let fuelRecord: FuelRecord?
    let chargeRecord: ChargeRecord?
    
    var isFuel: Bool { fuelRecord != nil }
}
