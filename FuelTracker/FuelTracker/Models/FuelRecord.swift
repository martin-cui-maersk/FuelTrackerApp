import Foundation

// 加油记录
struct FuelRecord: Identifiable, Codable, Hashable {
    var id: UUID
    var odometer: Double          // 里程数（公里）
    var fuelAmount: Double        // 加油量（升）
    var totalPrice: Double        // 实付金额（元）
    var pricePerLiter: Double     // 单价（元/升）- 自动计算
    var isFullTank: Bool          // 是否加满（用于油耗计算）
    /// 本次加油时油表低油量/油灯是否已亮（纯油车场景：与上次加满配合时，本段耗油按上次加油量估算）
    var lowFuelLightOnAtRefuel: Bool
    var date: Date                // 加油时间
    var note: String              // 备注
    
    init(id: UUID = UUID(), odometer: Double, fuelAmount: Double, totalPrice: Double, isFullTank: Bool = true, lowFuelLightOnAtRefuel: Bool = false, date: Date = Date(), note: String = "") {
        self.id = id
        self.odometer = odometer
        self.fuelAmount = fuelAmount
        self.totalPrice = totalPrice
        self.pricePerLiter = fuelAmount > 0 ? totalPrice / fuelAmount : 0
        self.isFullTank = isFullTank
        self.lowFuelLightOnAtRefuel = lowFuelLightOnAtRefuel
        self.date = date
        self.note = note
    }
    
    // 兼容旧版本数据（默认加满）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        odometer = try container.decode(Double.self, forKey: .odometer)
        fuelAmount = try container.decode(Double.self, forKey: .fuelAmount)
        totalPrice = try container.decode(Double.self, forKey: .totalPrice)
        pricePerLiter = try container.decodeIfPresent(Double.self, forKey: .pricePerLiter) ?? (fuelAmount > 0 ? totalPrice / fuelAmount : 0)
        isFullTank = try container.decodeIfPresent(Bool.self, forKey: .isFullTank) ?? true
        lowFuelLightOnAtRefuel = try container.decodeIfPresent(Bool.self, forKey: .lowFuelLightOnAtRefuel) ?? false
        date = try container.decode(Date.self, forKey: .date)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
    
    enum CodingKeys: String, CodingKey {
        case id, odometer, fuelAmount, totalPrice, pricePerLiter, isFullTank, lowFuelLightOnAtRefuel, date, note
    }
}

// 充电记录
struct ChargeRecord: Identifiable, Codable, Hashable {
    var id: UUID
    var odometer: Double              // 里程数（公里）
    var chargeAmount: Double          // 充电量（kWh）
    var totalPrice: Double            // 实付金额（元）
    var pricePerKwh: Double           // 单价（元/kWh）- 自动计算
    var startBatteryPercent: Double   // 开始电量%（必填）
    var endBatteryPercent: Double     // 结束电量%（必填）
    var chargeTime: Double?           // 充电时长（分钟）
    var date: Date                    // 充电时间
    var note: String                  // 备注
    
    init(id: UUID = UUID(), odometer: Double, chargeAmount: Double, totalPrice: Double, startBatteryPercent: Double = 0, endBatteryPercent: Double = 100, chargeTime: Double? = nil, date: Date = Date(), note: String = "") {
        self.id = id
        self.odometer = odometer
        self.chargeAmount = chargeAmount
        self.totalPrice = totalPrice
        self.pricePerKwh = chargeAmount > 0 ? totalPrice / chargeAmount : 0
        self.startBatteryPercent = startBatteryPercent
        self.endBatteryPercent = endBatteryPercent
        self.chargeTime = chargeTime
        self.date = date
        self.note = note
    }
    
    // 兼容旧版本数据
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        odometer = try container.decode(Double.self, forKey: .odometer)
        
        // 兼容旧的可选chargeAmount
        if let amount = try container.decodeIfPresent(Double.self, forKey: .chargeAmount) {
            chargeAmount = amount
        } else if let oldAmount = try container.decodeIfPresent(Double.self, forKey: .charargeAmount) {
            chargeAmount = oldAmount
        } else {
            chargeAmount = 0
        }
        
        totalPrice = try container.decode(Double.self, forKey: .totalPrice)
        pricePerKwh = try container.decodeIfPresent(Double.self, forKey: .pricePerKwh) ?? (chargeAmount > 0 ? totalPrice / chargeAmount : 0)
        
        // 兼容旧版本的可选百分比，默认值
        startBatteryPercent = try container.decodeIfPresent(Double.self, forKey: .startBatteryPercent) ?? 0
        endBatteryPercent = try container.decodeIfPresent(Double.self, forKey: .endBatteryPercent) ?? 100
        
        chargeTime = try container.decodeIfPresent(Double.self, forKey: .chargeTime)
        
        // 兼容旧的isFullCharge字段（忽略）
        _ = try container.decodeIfPresent(Bool.self, forKey: .isFullCharge)
        
        date = try container.decode(Date.self, forKey: .date)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
    
    enum CodingKeys: String, CodingKey {
        case id, odometer, chargeAmount, totalPrice, pricePerKwh, startBatteryPercent, endBatteryPercent, chargeTime, date, note, charargeAmount, isFullCharge
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(odometer, forKey: .odometer)
        try container.encode(chargeAmount, forKey: .chargeAmount)
        try container.encode(totalPrice, forKey: .totalPrice)
        try container.encode(pricePerKwh, forKey: .pricePerKwh)
        try container.encode(startBatteryPercent, forKey: .startBatteryPercent)
        try container.encode(endBatteryPercent, forKey: .endBatteryPercent)
        try container.encodeIfPresent(chargeTime, forKey: .chargeTime)
        try container.encode(date, forKey: .date)
        try container.encode(note, forKey: .note)
    }
    
    // 兼容旧版本的属性名
    var charargeAmount: Double? { chargeAmount }
}