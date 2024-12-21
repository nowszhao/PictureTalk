import SwiftUI

struct LearningContributionView: View {
    let records: [LearningRecord]
    let cellSize: CGFloat = 12 // 固定方块大小
    let spacing: CGFloat = 4   // 固定间距
    let rows = 7              // 一周7天
    
    // 根据容器宽度计算可以显示的列数
    private func calculateColumns(containerWidth: CGFloat) -> Int {
        let availableWidth = containerWidth - 16 // 减去左右padding
        let columnWidth = cellSize + spacing
        return Int(availableWidth / columnWidth)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 日历网格
            GeometryReader { geometry in
                let columns = calculateColumns(containerWidth: geometry.size.width)
                
                HStack(alignment: .top, spacing: spacing) {
                    // 显示周几的标签
                    VStack(alignment: .trailing, spacing: spacing) {
                        ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                            Text(day)
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                                .frame(height: cellSize)
                        }
                    }
                    .padding(.trailing, 4)
                    
                    // 日历网格
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: spacing) {
                            ForEach(0..<columns, id: \.self) { column in
                                VStack(spacing: spacing) {
                                    ForEach(0..<rows, id: \.self) { row in
                                        ContributionCell(record: getRecord(for: column, row: row))
                                            .frame(width: cellSize, height: cellSize)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .frame(height: CGFloat(rows) * cellSize + CGFloat(rows - 1) * spacing)
            
            // 图例
            HStack(spacing: 16) {
                ForEach(ContributionLevel.allCases, id: \.self) { level in
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(level.color)
                            .frame(width: cellSize, height: cellSize)
                        Text(level.description)
                            .font(.caption)
                    }
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func getRecord(for column: Int, row: Int) -> LearningRecord? {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        calendar.firstWeekday = 1  // 设置周日为每周第一天
        
        // 获取今天的日期
        let today = Date()
        
        // 计算总的天数偏移：每列代表一周，从右到左
        let totalColumns = calculateColumns(containerWidth: UIScreen.main.bounds.width)
        let reverseColumn = totalColumns - 1 - column  // 反转列的顺序
        let weeksToSubtract = reverseColumn
        
        // 先计算到对应的周
        guard let weekDate = calendar.date(byAdding: .weekOfYear, value: -weeksToSubtract, to: today) else {
            return nil
        }
        
        // 获取那周的周日
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekDate)
        components.weekday = 1  // 1 表示周日
        
        guard let weekStart = calendar.date(from: components),
              let targetDate = calendar.date(byAdding: .day, value: row, to: weekStart) else {
            return nil
        }
        
        // 添加调试日志
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd (E)"
        formatter.locale = Locale(identifier: "zh_CN")
        print("列: \(column), 行: \(row), 日期: \(formatter.string(from: targetDate))")
        
        // 查找对应的记录
        let record = records.first { calendar.isDate($0.date, inSameDayAs: targetDate) }
        if record != nil {
            print("找到记录 - 日期: \(formatter.string(from: record!.date))")
        }
        
        return record
    }
}

enum ContributionLevel: CaseIterable {
    case none
    case low      // 0-25%
    case medium   // 26-50%
    case high     // 51-75%
    case complete // 76-100%
    
    var color: Color {
        switch self {
        case .none: return Color.gray.opacity(0.2)
        case .low: return Color.green.opacity(0.3)
        case .medium: return Color.green.opacity(0.5)
        case .high: return Color.green.opacity(0.7)
        case .complete: return Color.green
        }
    }
    
    var description: String {
        switch self {
        case .none: return "未学习"
        case .low: return "开始"
        case .medium: return "进行中"
        case .high: return "较好"
        case .complete: return "完成"
        }
    }
    
    static func forCompletionRate(_ rate: Double) -> ContributionLevel {
        switch rate {
        case 0: return .none
        case 0..<0.25: return .low
        case 0.25..<0.5: return .medium
        case 0.5..<0.75: return .high
        default: return .complete
        }
    }
}

struct ContributionCell: View {
    let record: LearningRecord?
    
    var body: some View {
        let level = record.map { ContributionLevel.forCompletionRate($0.completionRate) } ?? .none
        
        Rectangle()
            .fill(level.color)
            .cornerRadius(2)
    }
} 
