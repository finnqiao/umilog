import SwiftUI
import Charts
import UmiDB
import UmiDesignSystem
import UmiCoreKit

/// Comprehensive statistics dashboard for dive analytics
public struct StatisticsView: View {
    @StateObject private var viewModel = StatisticsViewModel()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Summary Cards
                summarySection

                // Dive Depth Chart
                depthChartSection

                // Monthly Activity
                monthlyActivitySection

                // Dive Conditions Breakdown
                conditionsSection

                // Personal Records
                personalRecordsSection
            }
            .padding()
        }
        .navigationTitle("Statistics")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overview")
                .font(.headline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                SummaryCard(
                    value: "\(viewModel.stats.totalDives)",
                    label: "Total Dives",
                    icon: "water.waves",
                    color: .oceanBlue
                )
                SummaryCard(
                    value: formatDuration(viewModel.stats.totalBottomTime),
                    label: "Time Underwater",
                    icon: "clock",
                    color: .diveTeal
                )
                SummaryCard(
                    value: String(format: "%.1fm", viewModel.stats.maxDepth),
                    label: "Deepest Dive",
                    icon: "arrow.down",
                    color: .divePurple
                )
                SummaryCard(
                    value: "\(viewModel.stats.sitesVisited)",
                    label: "Sites Visited",
                    icon: "mappin",
                    color: .seaGreen
                )
            }
        }
    }

    // MARK: - Depth Chart

    private var depthChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Depth Progression")
                .font(.headline)
                .foregroundStyle(.secondary)

            if viewModel.depthData.isEmpty {
                emptyChartPlaceholder(message: "Log dives to see depth trends")
            } else {
                Chart(viewModel.depthData) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Depth", point.depth)
                    )
                    .foregroundStyle(Color.diveTeal.gradient)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Depth", point.depth)
                    )
                    .foregroundStyle(Color.diveTeal.opacity(0.2).gradient)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Depth", point.depth)
                    )
                    .foregroundStyle(Color.diveTeal)
                }
                .chartYScale(domain: .automatic(includesZero: true))
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let depth = value.as(Double.self) {
                                Text("\(Int(depth))m")
                            }
                        }
                    }
                }
                .frame(height: 200)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Monthly Activity

    private var monthlyActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Monthly Activity")
                .font(.headline)
                .foregroundStyle(.secondary)

            if viewModel.monthlyData.isEmpty {
                emptyChartPlaceholder(message: "Log dives to see monthly trends")
            } else {
                Chart(viewModel.monthlyData) { month in
                    BarMark(
                        x: .value("Month", month.month),
                        y: .value("Dives", month.count)
                    )
                    .foregroundStyle(Color.oceanBlue.gradient)
                    .cornerRadius(4)
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 180)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Conditions Breakdown

    private var conditionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Dive Conditions")
                .font(.headline)
                .foregroundStyle(.secondary)

            if viewModel.conditionsData.isEmpty {
                emptyChartPlaceholder(message: "Log dives to see conditions breakdown")
            } else {
                Chart(viewModel.conditionsData) { item in
                    SectorMark(
                        angle: .value("Count", item.count),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Condition", item.condition))
                    .annotation(position: .overlay) {
                        if item.count > 0 {
                            Text("\(item.count)")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                    }
                }
                .chartLegend(position: .bottom, spacing: 16)
                .frame(height: 200)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Personal Records

    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Personal Records")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                RecordRow(
                    icon: "arrow.down.to.line",
                    label: "Deepest Dive",
                    value: String(format: "%.1f m", viewModel.records.deepestDive),
                    color: .diveTeal
                )
                RecordRow(
                    icon: "clock.badge.checkmark",
                    label: "Longest Dive",
                    value: "\(viewModel.records.longestDive) min",
                    color: .oceanBlue
                )
                RecordRow(
                    icon: "thermometer.snowflake",
                    label: "Coldest Water",
                    value: String(format: "%.0f°C", viewModel.records.coldestTemp),
                    color: .blue
                )
                RecordRow(
                    icon: "eye",
                    label: "Best Visibility",
                    value: String(format: "%.0f m", viewModel.records.bestVisibility),
                    color: .seaGreen
                )
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Helpers

    private func emptyChartPlaceholder(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        if hours > 0 {
            return "\(hours)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Supporting Views

private struct SummaryCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title2.bold())

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

private struct RecordRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 32)

            Text(label)
                .font(.subheadline)

            Spacer()

            Text(value)
                .font(.headline)
                .foregroundStyle(color)
        }
    }
}

// MARK: - View Model

@MainActor
class StatisticsViewModel: ObservableObject {
    @Published var stats: DiveStats = .zero
    @Published var depthData: [DepthPoint] = []
    @Published var monthlyData: [MonthlyDives] = []
    @Published var conditionsData: [ConditionCount] = []
    @Published var records: PersonalRecords = .empty
    @Published var isLoading = false

    private let database = AppDatabase.shared

    init() {
        Task { await loadData() }
    }

    func refresh() async {
        await loadData()
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let dives = try database.diveRepository.fetchAll()
            stats = try database.diveRepository.calculateStats()

            // Depth progression (last 20 dives)
            depthData = dives.prefix(20).reversed().enumerated().map { index, dive in
                DepthPoint(date: dive.date, depth: dive.maxDepth)
            }

            // Monthly activity (last 6 months)
            monthlyData = calculateMonthlyActivity(dives: dives)

            // Conditions breakdown
            conditionsData = calculateConditionsBreakdown(dives: dives)

            // Personal records
            records = calculateRecords(dives: dives)
        } catch {
            Log.app.error("Failed to load statistics: \(error.localizedDescription)")
        }
    }

    private func calculateMonthlyActivity(dives: [DiveLog]) -> [MonthlyDives] {
        let calendar = Calendar.current
        let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        let recentDives = dives.filter { $0.date >= sixMonthsAgo }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"

        var countsByMonth: [String: Int] = [:]
        var monthDates: [String: Date] = [:]

        for dive in recentDives {
            let month = formatter.string(from: dive.date)
            countsByMonth[month, default: 0] += 1
            if monthDates[month] == nil {
                monthDates[month] = dive.date
            }
        }

        // Build last 6 months in order
        var result: [MonthlyDives] = []
        for i in (0..<6).reversed() {
            if let date = calendar.date(byAdding: .month, value: -i, to: Date()) {
                let month = formatter.string(from: date)
                result.append(MonthlyDives(month: month, count: countsByMonth[month] ?? 0))
            }
        }

        return result
    }

    private func calculateConditionsBreakdown(dives: [DiveLog]) -> [ConditionCount] {
        var counts: [String: Int] = [:]
        for dive in dives {
            counts[dive.conditions.rawValue, default: 0] += 1
        }

        return supportedDiveConditions.map { condition in
            ConditionCount(condition: condition.rawValue, count: counts[condition.rawValue] ?? 0)
        }
    }

    private func calculateRecords(dives: [DiveLog]) -> PersonalRecords {
        guard !dives.isEmpty else { return .empty }

        let deepest = dives.map(\.maxDepth).max() ?? 0
        let longest = dives.map(\.bottomTime).max() ?? 0
        let coldest = dives.map(\.temperature).min() ?? 0
        let bestVis = dives.map(\.visibility).max() ?? 0

        return PersonalRecords(
            deepestDive: deepest,
            longestDive: longest,
            coldestTemp: coldest,
            bestVisibility: bestVis
        )
    }

    private var supportedDiveConditions: [DiveLog.Conditions] {
        [.excellent, .good, .fair, .poor]
    }
}

// MARK: - Data Types

struct DepthPoint: Identifiable {
    let id = UUID()
    let date: Date
    let depth: Double
}

struct MonthlyDives: Identifiable {
    let id = UUID()
    let month: String
    let count: Int
}

struct ConditionCount: Identifiable {
    let id = UUID()
    let condition: String
    let count: Int
}

struct PersonalRecords {
    let deepestDive: Double
    let longestDive: Int
    let coldestTemp: Double
    let bestVisibility: Double

    static let empty = PersonalRecords(
        deepestDive: 0,
        longestDive: 0,
        coldestTemp: 0,
        bestVisibility: 0
    )
}

#Preview {
    NavigationStack {
        StatisticsView()
    }
}
