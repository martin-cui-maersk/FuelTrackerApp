import SwiftUI
import Charts

// 时间范围枚举
enum TimeRange: String, CaseIterable {
    case threeMonths = "三个月"
    case sixMonths = "半年"
    case oneYear = "一年"
    case all = "全部"

    func startDate() -> Date? {
        switch self {
        case .threeMonths:
            return Calendar.current.date(byAdding: .month, value: -3, to: Date())
        case .sixMonths:
            return Calendar.current.date(byAdding: .month, value: -6, to: Date())
        case .oneYear:
            return Calendar.current.date(byAdding: .year, value: -1, to: Date())
        case .all:
            return nil
        }
    }
}

struct StatisticsView: View {
    let vehicle: Vehicle
    @Environment(\.dismiss) var dismiss
    @State private var selectedTimeRange: TimeRange = .all

    // 过滤后的数据
    private var filteredFuelRecords: [FuelRecord] {
        guard let startDate = selectedTimeRange.startDate() else {
            return vehicle.fuelRecords.sorted { $0.date > $1.date }
        }
        return vehicle.fuelRecords.filter { $0.date >= startDate }.sorted { $0.date > $1.date }
    }

    private var filteredChargeRecords: [ChargeRecord] {
        guard let startDate = selectedTimeRange.startDate() else {
            return vehicle.chargeRecords.sorted { $0.date > $1.date }
        }
        return vehicle.chargeRecords.filter { $0.date >= startDate }.sorted { $0.date > $1.date }
    }

    // 计算统计数据
    private var filteredTotalDistance: Double {
        guard !filteredFuelRecords.isEmpty else { return 0 }
        let sorted = filteredFuelRecords.sorted { $0.date < $1.date }
        guard let first = sorted.first?.odometer, let last = sorted.last?.odometer else { return 0 }
        return last - first
    }

    // 总油费
    private var filteredTotalFuelCost: Double {
        filteredFuelRecords.reduce(0) { $0 + $1.totalPrice }
    }

    // 总油量
    private var filteredTotalFuel: Double {
        filteredFuelRecords.reduce(0) { $0 + $1.fuelAmount }
    }

    // 平均每天里程
    private var filteredAverageDailyDistance: Double {
        guard !filteredFuelRecords.isEmpty else { return 0 }
        let sorted = filteredFuelRecords.sorted { $0.date < $1.date }
        guard let firstDate = sorted.first?.date, let lastDate = sorted.last?.date else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: firstDate, to: lastDate).day ?? 1
        guard days > 0 else { return filteredTotalDistance }
        return filteredTotalDistance / Double(days)
    }

    // 每公里油耗
    private var filteredFuelPerKm: Double? {
        guard filteredTotalDistance > 0, filteredTotalFuel > 0 else { return nil }
        return filteredTotalFuel / filteredTotalDistance * 100
    }

    private var filteredTotalCharge: Double {
        filteredChargeRecords.reduce(0) { $0 + $1.chargeAmount }
    }

    private var filteredTotalCost: Double {
        let fuelCost = filteredFuelRecords.reduce(0) { $0 + $1.totalPrice }
        let chargeCost = filteredChargeRecords.reduce(0) { $0 + $1.totalPrice }
        return fuelCost + chargeCost
    }

    private var filteredAverageFuelConsumption: Double? {
        // 使用加权平均算法(小熊油耗算法)
        // 平均油耗 = Σ(单次油耗 × 权重),权重 = 单次行程 / 行程总和
        let sorted = filteredFuelRecords.sorted { $0.odometer < $1.odometer }
        guard sorted.count >= 2 else { return nil }

        var totalDistance = 0.0
        var weightedSum = 0.0

        for i in 1..<sorted.count {
            let prev = sorted[i - 1]
            let current = sorted[i]
            let distance = current.odometer - prev.odometer

            if distance > 0 {
                let useLastFullTankAsConsumed = !current.isFullTank && current.lowFuelLightOnAtRefuel && prev.isFullTank
                let segmentFuelLiters = useLastFullTankAsConsumed ? prev.fuelAmount : current.fuelAmount
                let singleConsumption = segmentFuelLiters / distance * 100
                weightedSum += singleConsumption * distance
                totalDistance += distance
            }
        }

        guard totalDistance > 0 else { return nil }
        let result = weightedSum / totalDistance
        return round(result * 100) / 100
    }

    // 最低油耗
    private var filteredMinFuelConsumption: Double? {
        let sorted = filteredFuelRecords.sorted { $0.odometer < $1.odometer }
        guard sorted.count >= 2 else { return nil }

        var minCons: Double?
        for i in 1..<sorted.count {
            if let consumption = fuelConsumptionForRecord(sorted[i], from: sorted) {
                if let m = minCons {
                    minCons = Swift.min(consumption, m)
                } else {
                    minCons = consumption
                }
            }
        }

        return minCons
    }

    // 最高油耗
    private var filteredMaxFuelConsumption: Double? {
        let sorted = filteredFuelRecords.sorted { $0.odometer < $1.odometer }
        guard sorted.count >= 2 else { return nil }

        var maxCons: Double?
        for i in 1..<sorted.count {
            if let consumption = fuelConsumptionForRecord(sorted[i], from: sorted) {
                if let m = maxCons {
                    maxCons = Swift.max(consumption, m)
                } else {
                    maxCons = consumption
                }
            }
        }

        return maxCons
    }

    // 每公里费用(加权平均算法)
    private var filteredAverageCostPerKm: Double? {
        let sorted = filteredFuelRecords.sorted { $0.odometer < $1.odometer }
        guard sorted.count >= 2 else { return nil }

        var totalWeightedCost: Double = 0
        var totalDistance: Double = 0

        // 找到所有加满记录
        let fullTankRecords = sorted.enumerated().filter { $0.element.isFullTank }
        guard fullTankRecords.count >= 2 else { return nil }

        // 对每个区间计算费用(从第i个加满到第i+1个加满)
        for i in 0..<(fullTankRecords.count - 1) {
            let currentIdx = fullTankRecords[i].offset
            let nextIdx = fullTankRecords[i + 1].offset

            let currentRecord = sorted[currentIdx]
            let nextRecord = sorted[nextIdx]

            let distance = nextRecord.odometer - currentRecord.odometer
            guard distance > 0 else { continue }

            // 区间总加油量
            var intervalFuel = 0.0
            for j in (currentIdx + 1)...nextIdx {
                intervalFuel += sorted[j].fuelAmount
            }

            // 区间总费用(单价 × 加油量)
            var intervalCost = 0.0
            for j in (currentIdx + 1)...nextIdx {
                intervalCost += sorted[j].totalPrice
            }

            // 每公里费用 × 距离 = 区间总费用
            totalWeightedCost += intervalCost
            totalDistance += distance
        }

        guard totalDistance > 0 else { return nil }
        let result = totalWeightedCost / totalDistance
        return round(result * 100) / 100
    }

    private var filteredAverageElectricConsumption: Double? {
        let sorted = filteredChargeRecords.sorted { $0.date < $1.date }
        guard sorted.count >= 2 else { return nil }

        var totalConsumption: Double = 0
        var count = 0

        for i in 1..<sorted.count {
            let prev = sorted[i-1]
            let curr = sorted[i]
            let distance = curr.odometer - prev.odometer
            if distance > 0 {
                let consumption = prev.chargeAmount / distance * 100
                totalConsumption += consumption
                count += 1
            }
        }

        return count > 0 ? totalConsumption / Double(count) : nil
    }

    // 计算单次油耗(使用区间算法,与Vehicle.swift一致)
    // 加满记录:用上一个加满到本次加满的区间油耗
    // 未加满记录:用本次到下一个加满的区间油耗
    private func fuelConsumptionForRecord(_ record: FuelRecord, from records: [FuelRecord]) -> Double? {
        let sortedByOdo = records.sorted { $0.odometer < $1.odometer }
        guard let index = sortedByOdo.firstIndex(where: { $0.id == record.id }) else { return nil }
        guard index > 0 else { return nil }

        let prevAdjacent = sortedByOdo[index - 1]
        let currentRec = sortedByOdo[index]
        let segmentDistance = currentRec.odometer - prevAdjacent.odometer
        if segmentDistance > 0, !currentRec.isFullTank, currentRec.lowFuelLightOnAtRefuel, prevAdjacent.isFullTank {
            let result = prevAdjacent.fuelAmount / segmentDistance * 100
            return round(result * 100) / 100
        }

        // 找上一个加满记录
        var prevFullTankIndex = index - 1
        while prevFullTankIndex >= 0 && !sortedByOdo[prevFullTankIndex].isFullTank {
            prevFullTankIndex -= 1
        }
        guard prevFullTankIndex >= 0 && sortedByOdo[prevFullTankIndex].isFullTank else { return nil }

        // 如果当前是加满记录,计算从上一个加满到本次加满的区间油耗
        // 如果当前是未加满记录,需要找到下一个加满记录才能计算完整区间
        var nextFullTankIndex = index
        if !record.isFullTank {
            nextFullTankIndex = index + 1
            while nextFullTankIndex < sortedByOdo.count && !sortedByOdo[nextFullTankIndex].isFullTank {
                nextFullTankIndex += 1
            }
            guard nextFullTankIndex < sortedByOdo.count && sortedByOdo[nextFullTankIndex].isFullTank else { return nil }
        }

        // 计算区间总油耗
        let prevFullTank = sortedByOdo[prevFullTankIndex]
        let nextFullTank = sortedByOdo[nextFullTankIndex]
        let intervalDistance = nextFullTank.odometer - prevFullTank.odometer
        guard intervalDistance > 0 else { return nil }

        // 区间总加油量
        var intervalFuel = 0.0
        for i in (prevFullTankIndex + 1)..<(nextFullTankIndex + 1) {
            intervalFuel += sortedByOdo[i].fuelAmount
        }

        // 区间总油耗 (L/100km)
        let result = intervalFuel / intervalDistance * 100
        return round(result * 100) / 100
    }

    // 油耗趋势数据
    private var fuelConsumptionData: [(date: Date, consumption: Double)] {
        let sorted = filteredFuelRecords.sorted { $0.date < $1.date }
        var result: [(Date, Double)] = []

        for i in 1..<sorted.count {
            if let consumption = fuelConsumptionForRecord(sorted[i], from: sorted) {
                result.append((sorted[i].date, consumption))
            }
        }
        return result
    }

    // 电耗趋势数据
    private var chargeConsumptionData: [(date: Date, consumption: Double)] {
        let sorted = filteredChargeRecords.sorted { $0.date < $1.date }
        var result: [(Date, Double)] = []

        for i in 1..<sorted.count {
            let prev = sorted[i-1]
            let curr = sorted[i]
            let distance = curr.odometer - prev.odometer
            if distance > 0 {
                let consumption = prev.chargeAmount / distance * 100
                result.append((curr.date, consumption))
            }
        }
        return result
    }

    // 按月统计油费
    private func calculateMonthlyFuelCost() -> [(month: Date, total: Double)] {
        var monthly: [String: Double] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"

        for record in filteredFuelRecords {
            let key = formatter.string(from: record.date)
            monthly[key, default: 0] += record.totalPrice
        }

        let sortedKeys = monthly.keys.sorted()
        return sortedKeys.compactMap { key in
            guard let total = monthly[key] else { return nil }
            guard let date = formatter.date(from: key) else { return nil }
            return (month: date, total: total)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 时间范围选择
                    Picker("时间范围", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // 油耗趋势图(柱状图)
                    if vehicle.type != .electric && !fuelConsumptionData.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("油耗趋势")
                                    .font(.headline)
                                Text("(" + selectedTimeRange.rawValue + " · 序号=月份)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)

                            let avgFuel = filteredAverageFuelConsumption

                            Chart {
                                // 折线 - 使用完整数据系列
                                ForEach(fuelConsumptionData.indices, id: \.self) { index in
                                    let item = fuelConsumptionData[index]
                                    LineMark(
                                        x: .value("序号", Double(index)),
                                        y: .value("油耗", item.consumption)
                                    )
                                    .foregroundStyle(.orange)
                                    .lineStyle(StrokeStyle(lineWidth: 2))
                                }

                                // 平均线
                                if let avg = avgFuel {
                                    RuleMark(y: .value("平均", avg))
                                        .foregroundStyle(.blue.opacity(0.6))
                                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                                        .annotation(position: .trailing, spacing: 0) {
                                            Text(String(format: "%.2f", avg))
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                                .padding(.horizontal, 4)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(4)
                                        }
                                }

                                // 数据点
                                ForEach(fuelConsumptionData.indices, id: \.self) { index in
                                    let item = fuelConsumptionData[index]
                                    PointMark(
                                        x: .value("序号", Double(index)),
                                        y: .value("油耗", item.consumption)
                                    )
                                    .foregroundStyle(.orange)
                                    .symbolSize(12)
                                }
                            }
                            .chartXScale(domain: 0...Double(fuelConsumptionData.count - 1))
                            .chartXAxis {
                                AxisMarks(values: .automatic(desiredCount: min(fuelConsumptionData.count, 6))) { value in
                                    AxisGridLine()
                                    AxisTick()
                                    if let idx = value.as(Int.self), idx >= 0, idx < fuelConsumptionData.count {
                                        AxisValueLabel {
                                            Text(fuelConsumptionData[idx].date, format: .dateTime.month(.abbreviated))
                                        }
                                    }
                                }
                            }
                            .chartYAxisLabel("L/100km")
                            .frame(height: 200)
                            .padding()
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 1)
                        .padding(.horizontal)
                    }

                    // 电耗趋势图
                    if vehicle.type != .fuel && !chargeConsumptionData.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("电耗趋势")
                                    .font(.headline)
                                Text("(" + selectedTimeRange.rawValue + " · 序号=月份)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)

                            let avgCharge = filteredAverageElectricConsumption

                            Chart {
                                // 折线 - 使用完整数据系列
                                ForEach(chargeConsumptionData.indices, id: \.self) { index in
                                    let item = chargeConsumptionData[index]
                                    LineMark(
                                        x: .value("序号", Double(index)),
                                        y: .value("电耗", item.consumption)
                                    )
                                    .foregroundStyle(.green)
                                    .lineStyle(StrokeStyle(lineWidth: 2))
                                }
                                
                                // 平均线
                                if let avg = avgCharge {
                                    RuleMark(y: .value("平均", avg))
                                        .foregroundStyle(.blue.opacity(0.6))
                                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                                        .annotation(position: .trailing, spacing: 0) {
                                            Text(String(format: "%.2f", avg))
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                                .padding(.horizontal, 4)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(4)
                                        }
                                }
                                
                                // 数据点
                                ForEach(chargeConsumptionData.indices, id: \.self) { index in
                                    let item = chargeConsumptionData[index]
                                    PointMark(
                                        x: .value("序号", Double(index)),
                                        y: .value("电耗", item.consumption)
                                    )
                                    .foregroundStyle(.green)
                                    .symbolSize(12)
                                }
                            }
                            .chartXScale(domain: 0...Double(chargeConsumptionData.count - 1))
                            .chartXAxis {
                                AxisMarks(values: .automatic(desiredCount: min(chargeConsumptionData.count, 6))) { value in
                                    AxisGridLine()
                                    AxisTick()
                                    if let idx = value.as(Int.self), idx >= 0, idx < chargeConsumptionData.count {
                                        AxisValueLabel {
                                            Text(chargeConsumptionData[idx].date, format: .dateTime.month(.abbreviated))
                                        }
                                    }
                                }
                            }
                            .chartYAxisLabel("kWh/100km")
                            .frame(height: 200)
                            .padding()
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 1)
                        .padding(.horizontal)
                    }

                    // 油费统计柱状图
                    if vehicle.type != .electric && !filteredFuelRecords.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("油费统计(每月)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)

                            let monthlyData = calculateMonthlyFuelCost()

                            Chart {
                                ForEach(monthlyData, id: \.month) { item in
                                    BarMark(
                                        x: .value("月份", item.month, unit: .month),
                                        y: .value("油费", item.total)
                                    )
                                    .foregroundStyle(Color.orange.opacity(0.8))
                                    .annotation(position: .top) {
                                        Text("\(Int(item.total))")
                                            .font(.system(size: 8))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .chartYAxisLabel("元")
                            .chartXAxis {
                                AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                                }
                            }
                            .frame(height: 180)
                            .padding()
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 1)
                        .padding(.horizontal)
                    }

                    // 统计卡片
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        StatCard(title: "总里程", value: String(format: "%.0f km", filteredTotalDistance), color: .blue, icon: "road.lanes")
                        StatCard(title: "总油费", value: String(format: "¥%.2f", filteredTotalFuelCost), color: .orange, icon: "yensign.circle")

                        if vehicle.type != .electric {
                            StatCard(title: "总油量", value: String(format: "%.2f L", filteredTotalFuel), color: .orange, icon: "fuelpump")
                            if let avg = filteredAverageFuelConsumption {
                                StatCard(title: "平均油耗", value: String(format: "%.2f L/100km", avg), color: .orange, icon: "gauge")
                            }
                            if let min = filteredMinFuelConsumption {
                                StatCard(title: "最低油耗", value: String(format: "%.2f L/100km", min), color: .green, icon: "arrow.down.circle")
                            }
                            if let max = filteredMaxFuelConsumption {
                                StatCard(title: "最高油耗", value: String(format: "%.2f L/100km", max), color: .red, icon: "arrow.up.circle")
                            }
                            StatCard(title: "平均每天", value: String(format: "%.2f km", filteredAverageDailyDistance), color: .blue, icon: "calendar")
                            if let costPerKm = filteredAverageCostPerKm {
                                StatCard(title: "每公里", value: String(format: "¥%.2f", costPerKm), color: .orange, icon: "dollarsign.circle")
                            }
                        }

                        if vehicle.type != .fuel {
                            StatCard(title: "总充电", value: String(format: "%.2f kWh", filteredTotalCharge), color: .green, icon: "bolt.fill")
                            if let avg = filteredAverageElectricConsumption {
                                StatCard(title: "平均电耗", value: String(format: "%.2f kWh/100km", avg), color: .green, icon: "battery.100")
                            }
                        }
                    }
                    .padding(.horizontal)

                    // 油耗计算说明
                    NavigationLink(destination: FuelCalculationInfoView()) {
                        HStack {
                            Image(systemName: "info.circle")
                            Text("油耗计算说明")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .padding(.top, 8)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(vehicle.name + " 统计")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundColor(color)
                }
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 1)
    }
}

#Preview {
    var vehicle = Vehicle(name: "测试车辆", type: .fuel)
    vehicle.fuelRecords = [
        FuelRecord(odometer: 1000, fuelAmount: 45, totalPrice: 337.5, date: Date().addingTimeInterval(-86400 * 30)),
        FuelRecord(odometer: 1350, fuelAmount: 38, totalPrice: 288.8, date: Date().addingTimeInterval(-86400 * 20)),
        FuelRecord(odometer: 1720, fuelAmount: 42, totalPrice: 310.8, date: Date().addingTimeInterval(-86400 * 10)),
        FuelRecord(odometer: 2100, fuelAmount: 40, totalPrice: 300, date: Date())
    ]
    return StatisticsView(vehicle: vehicle)
}

// 油耗计算说明页面（与 Vehicle.swift 及统计页中的油车逻辑一致）
struct FuelCalculationInfoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("适用范围与排序")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("以下公式适用于油车；混动车仅对「加油记录」使用相同油耗逻辑。所有加油记录均按里程表读数从小到大排序后再计算（与加油日期无关）。")
                        .font(.subheadline)

                    Text("相邻两次加油之间的行程 = 本条里程 − 上一条里程。第一条记录没有上一条，不参与油耗计算。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)

                VStack(alignment: .leading, spacing: 8) {
                    Text("本段估耗油量（升）")
                        .font(.headline)
                        .foregroundColor(.orange)

                    Text("在计算「平均油耗」时，每一对相邻记录会先确定本段估耗油量 L：")
                        .font(.subheadline)

                    Text("• 默认：L = 本条记录的加油量（升）。")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("• 若同时满足：①本条为「未加满」；②本条开启「加油时油灯已亮」；③上一条为「加满」，则 L = 上一条的加油量。含义是：上箱加满后跑到油灯亮，本段消耗近似为上一箱加进去的油量。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)

                VStack(alignment: .leading, spacing: 8) {
                    Text("平均油耗（L/100km）")
                        .font(.headline)
                        .foregroundColor(.orange)

                    Text("采用小熊油耗思路的行程加权：对每一对相邻记录，若行程 d > 0，则单次百公里油耗 = L ÷ d × 100。")
                        .font(.subheadline)

                    Text("平均油耗 = Σ(单次百公里油耗 × d) ÷ Σd\n数学上等价于：平均油耗 = (Σ L) × 100 ÷ Σd（因单次油耗 × d = L × 100）。")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("金额、升数在累加时按整数「分」「毫升」换算再累加，减少浮点误差；结果保留两位小数。统计页在选定时间范围内筛选记录后，使用相同规则。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)

                VStack(alignment: .leading, spacing: 8) {
                    Text("列表与趋势中的「单次油耗」")
                        .font(.headline)
                        .foregroundColor(.orange)

                    Text("车辆详情每条加油下方的百公里、统计页的油耗趋势/最低/最高，使用同一套「单次展示油耗」算法（与平均油耗的相邻段法不同）。")
                        .font(.subheadline)

                    Text("一、油灯 + 未加满 + 上次加满（与上面 L 的特殊条件一致）\n若本条与上一条之间的里程 d > 0，则展示百公里 = 上一条加油量 ÷ d × 100。")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("二、否则：「上一个加满 → 下一个加满」区间法\n• 从本条向前找到最近一条「加满」作为区间起点（里程记为 A）。\n• 若本条本身是加满，区间终点取本条；若本条未加满，则向后找到最近一条「加满」作为终点（里程记为 B）；若后面没有加满则无法计算。\n• 区间里程 = B − A。\n• 区间总加油量 = 从「起点加满的下一条」一直到「终点那条」为止，所有记录的加油量（升）之和。\n• 展示百公里 = 区间总加油量 ÷ 区间里程 × 100。\n同一区间内每条参与该区间计算的记录，展示的百公里数值相同。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)

                VStack(alignment: .leading, spacing: 8) {
                    Text("行程耗油量、行程油费、每公里油费")
                        .font(.headline)
                        .foregroundColor(.blue)

                    Text("行程耗油量（升）= 上述「单次展示油耗」÷ 100 × 本条与上一条之间的里程 d。")
                        .font(.subheadline)

                    Text("行程油费（元）= 行程耗油量 × 上一条记录的每升单价（由上一条实付与加油量自动算出）。")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("每公里油费（元/km）= 行程油费 ÷ d。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)

                VStack(alignment: .leading, spacing: 8) {
                    Text("加满法辅助量（总加油量与里程）")
                        .font(.headline)
                        .foregroundColor(.green)

                    Text("用于部分汇总：仅统计标记为「加满」的记录。若加满记录不足 2 条，相关量为 0。")
                        .font(.subheadline)

                    Text("• 用于耗油统计的总升数：从第二条「加满」起，每次加满的加油量之和（第一条加满视为初始油量，不计入消耗侧）。\n• 对应里程：最早一条「加满」与最晚一条「加满」的里程表之差。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)

                VStack(alignment: .leading, spacing: 8) {
                    Text("每公里费用（注意：统计页与车辆汇总算法不同）")
                        .font(.headline)
                        .foregroundColor(.blue)

                    Text("统计页「每公里」卡片：在两个相邻的「加满」点之间形成一个区间；区间内每次加油的实付金额相加得到区间油费，区间里程为两端加满的里程差。对每个区间算「区间油费 ÷ 区间里程」，再按各区间里程加权，得到加权平均每公里油费。")
                        .font(.subheadline)

                    Text("车辆模型中的平均每公里（如首页汇总）：分子为按里程排序后「从第二条加油记录起」所有加油实付之和；分母为「第一条加满」至「最后一条加满」的里程差（至少两条加满）。与统计页的区间加权可能数值不同。")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("单位均为元/公里。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)

                VStack(alignment: .leading, spacing: 8) {
                    Text("与「公认公式」的关系")
                        .font(.headline)
                        .foregroundColor(.green)

                    Text("常见口径：总消耗燃油 ÷ 总行驶里程 × 100。本应用用行程加权的单次估耗油量 L（含油灯特殊规则）综合成平均油耗，在记录较完整时与公认公式通常接近；小熊油耗等工具也普遍采用类似加权思路。")
                        .font(.subheadline)

                    Text("示例（概念）：总加油量与总里程算得 10.15 L/100km 时，本应用加权结果可能为 10.18 L/100km 等，差异往往很小。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
            }
            .padding()
        }
        .navigationTitle("油耗计算说明")
        .navigationBarTitleDisplayMode(.inline)
    }
}