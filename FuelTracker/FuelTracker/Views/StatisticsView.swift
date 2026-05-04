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
                let singleConsumption = current.fuelAmount / distance * 100
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
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return nil }
        guard index > 0 else { return nil }

        // 找上一个加满记录
        var prevFullTankIndex = index - 1
        while prevFullTankIndex >= 0 && !records[prevFullTankIndex].isFullTank {
            prevFullTankIndex -= 1
        }
        guard prevFullTankIndex >= 0 && records[prevFullTankIndex].isFullTank else { return nil }

        // 如果当前是加满记录,计算从上一个加满到本次加满的区间油耗
        // 如果当前是未加满记录,需要找到下一个加满记录才能计算完整区间
        var nextFullTankIndex = index
        if !record.isFullTank {
            nextFullTankIndex = index + 1
            while nextFullTankIndex < records.count && !records[nextFullTankIndex].isFullTank {
                nextFullTankIndex += 1
            }
            guard nextFullTankIndex < records.count && records[nextFullTankIndex].isFullTank else { return nil }
        }

        // 计算区间总油耗
        let prevFullTank = records[prevFullTankIndex]
        let nextFullTank = records[nextFullTankIndex]
        let intervalDistance = nextFullTank.odometer - prevFullTank.odometer
        guard intervalDistance > 0 else { return nil }

        // 区间总加油量
        var intervalFuel = 0.0
        for i in (prevFullTankIndex + 1)..<(nextFullTankIndex + 1) {
            intervalFuel += records[i].fuelAmount
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

// 油耗计算说明页面
struct FuelCalculationInfoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 单次油耗计算
                VStack(alignment: .leading, spacing: 8) {
                    Text("单次油耗是怎么计算的?")
                        .font(.headline)
                        .foregroundColor(.orange)

                    Text("对于燃油车,单次油耗是连续两次加油期间的油耗。")
                        .font(.subheadline)

                    Text("算法1(加满到加满):两次都是加满,跳枪为准\n单次油耗 = 本次加油量 ÷ (本次里程 - 上次加满里程) × 100")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("算法2(亮灯到亮灯):两次都是油灯亮起\n单次油耗 = 第一次加油量 ÷ 两次之间里程 × 100")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("算法3(未加满记录):如果中间有未加满的记录\n需要计算整个区间的百公里油耗:从上一次加满到下一次加满之间,所有加油量总和 ÷ 整个区间里程 × 100\n这两次加油的油耗值相同")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("优先采用算法1(加满)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)

                // 平均油耗计算
                VStack(alignment: .leading, spacing: 8) {
                    Text("平均油耗是怎么计算的?")
                        .font(.headline)
                        .foregroundColor(.orange)

                    Text("采用小熊油耗的「加权平均」算法:")
                        .font(.subheadline)

                    Text("平均油耗 = Σ(单次油耗 × 权重)\n权重 = 单次行程 ÷ 行程总和")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("为什么用加权平均?\n加油量往往不等于消耗的油量,加权平均在各种复杂记录情况下(有时加满、有时亮灯)都能得到准确结果。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)

                // 公认公式对比
                VStack(alignment: .leading, spacing: 8) {
                    Text("与公认公式对比")
                        .font(.headline)
                        .foregroundColor(.green)

                    Text("公认公式:耗油量 ÷ 行驶里程 × 100")
                        .font(.subheadline)

                    Text("示例:熊大记录276次加油,总加油量13159.36L,总行程129047km\n公认公式:13159.36 ÷ 129047 × 100 = 10.15 L/100km\n加权平均:10.18 L/100km\n差异仅0.2%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)

                // 每公里费用
                VStack(alignment: .leading, spacing: 8) {
                    Text("每公里费用")
                        .font(.headline)
                        .foregroundColor(.blue)

                    Text("计算公式:总油费 ÷ 总里程")
                        .font(.subheadline)

                    Text("说明:单位为元/公里")
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