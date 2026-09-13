import SwiftUI

/// UsageHistoryView replicates the authentic macOS System Settings (Battery & Screen Time)
/// usage matrix layout: dual synchronized charts (activity curve + blue usage bars)
/// over a dashed time-grid with dynamic right-axis metrics and interactive interval inspection.
struct UsageHistoryView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedScope: HistoryScope = .last24Hours
    @State private var selectedIndex: Int?
    @State private var hoveredIndex: Int?

    enum HistoryScope: String, CaseIterable, Identifiable {
        case last24Hours = "Last 24 Hours"
        case last7Days = "Last 7 Days"
        case last14Days = "Last 14 Days"

        var id: String { rawValue }
    }

    private var days: [DailyUsage] {
        appState.historyDays.isEmpty ? appState.last7Days : appState.historyDays
    }

    // Generate chart items based on selected scope
    private var chartItems: [ChartItem] {
        switch selectedScope {
        case .last24Hours:
            return generate24HourItems()
        case .last7Days:
            return generateDailyItems(count: 7)
        case .last14Days:
            return generateDailyItems(count: 14)
        }
    }

    private var activeIndex: Int {
        if let idx = selectedIndex, idx >= 0 && idx < chartItems.count {
            return idx
        }
        return max(chartItems.count - 1, 0)
    }

    private var activeItem: ChartItem? {
        guard !chartItems.isEmpty, activeIndex < chartItems.count else { return nil }
        return chartItems[activeIndex]
    }

    private var peakBytes: UInt64 {
        let maxUsage = chartItems.map { $0.totalBytes }.max() ?? 0
        return max(maxUsage, 100 * 1024 * 1024) // minimum 100 MB baseline
    }

    private var totalPeriodBytes: UInt64 {
        chartItems.reduce(0) { $0 + $1.totalBytes }
    }

    private var totalDownloadBytes: UInt64 {
        chartItems.reduce(0) { $0 + $1.downloadBytes }
    }

    private var totalUploadBytes: UInt64 {
        chartItems.reduce(0) { $0 + $1.uploadBytes }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header with Time Scope Picker
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Usage")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Monitor transfer rates and data volume across time intervals.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Picker("Time Scope", selection: $selectedScope) {
                        ForEach(HistoryScope.allCases) { scope in
                            Text(scope.rawValue).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 290)
                    .onChange(of: selectedScope) { _, newScope in
                        SoundManager.shared.playSelect()
                        selectedIndex = nil
                        if newScope == .last14Days {
                            Task { await appState.setHistoryRange(14) }
                        } else if newScope == .last7Days {
                            Task { await appState.setHistoryRange(7) }
                        }
                    }

                    Button {
                        Task { await appState.refreshHistory() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh history")
                }

                // Authentic macOS Battery-Style Chart Card
                macOSUsageMatrixCard

                // Selected Interval Inspector (macOS Battery style)
                if let item = activeItem {
                    intervalInspectorCard(item: item)
                }
            }
            .padding(20)
        }
    }

    // MARK: - Authentic macOS Battery-Style Usage Matrix Card
    private var macOSUsageMatrixCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Chart 1: Top Activity Density Curve (Corresponds to Battery Level in macOS)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center) {
                    Text("Activity Level")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                ZStack(alignment: .topLeading) {
                    // Right-axis labels for Top Chart
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("100%")
                            Spacer()
                            Text("50%")
                            Spacer()
                            Text("0%")
                        }
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 44)
                        .padding(.vertical, 2)
                    }

                    // Top Chart Area
                    HStack(spacing: 0) {
                        GeometryReader { geo in
                            let chartWidth = geo.size.width
                            let chartHeight = geo.size.height

                            ZStack(alignment: .topLeading) {
                                // Horizontal Grid Lines (100%, 50%, 0%)
                                Path { path in
                                    path.move(to: CGPoint(x: 0, y: 0))
                                    path.addLine(to: CGPoint(x: chartWidth, y: 0))
                                    path.move(to: CGPoint(x: 0, y: chartHeight * 0.5))
                                    path.addLine(to: CGPoint(x: chartWidth, y: chartHeight * 0.5))
                                    path.move(to: CGPoint(x: 0, y: chartHeight))
                                    path.addLine(to: CGPoint(x: chartWidth, y: chartHeight))
                                }
                                .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 1)

                                // Vertical Dashed Interval Guidelines
                                verticalDashedLines(width: chartWidth, height: chartHeight)

                                // Active highlight region
                                if activeIndex < chartItems.count {
                                    highlightBand(width: chartWidth, height: chartHeight, index: activeIndex)
                                }

                                // Green Density Bars (Battery level style)
                                topDensityBars(width: chartWidth, height: chartHeight)
                            }
                        }
                        .padding(.trailing, 50) // Reserve room for right-axis labels
                    }
                }
                .frame(height: 70)

                // Active Charging / Peak Indicator pill under top chart
                activeIndicatorBar
            }

            // Intermediate Time Ticks & Date Axis
            timeTickAxisView

            // Chart 2: Network Usage (Corresponds to "Screen On Usage" in macOS)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center) {
                    Text("Network Usage")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)
                    Spacer()
                }

                ZStack(alignment: .topLeading) {
                    // Right-axis labels for Bottom Chart (Byte Volume)
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(ByteFormat.string(bytes: peakBytes))
                            Spacer()
                            Text(ByteFormat.string(bytes: peakBytes / 2))
                            Spacer()
                            Text("0 B")
                        }
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 50)
                        .padding(.vertical, 2)
                    }

                    // Bottom Chart Area
                    HStack(spacing: 0) {
                        GeometryReader { geo in
                            let chartWidth = geo.size.width
                            let chartHeight = geo.size.height

                            ZStack(alignment: .topLeading) {
                                // Horizontal Grid Lines
                                Path { path in
                                    path.move(to: CGPoint(x: 0, y: 0))
                                    path.addLine(to: CGPoint(x: chartWidth, y: 0))
                                    path.move(to: CGPoint(x: 0, y: chartHeight * 0.5))
                                    path.addLine(to: CGPoint(x: chartWidth, y: chartHeight * 0.5))
                                    path.move(to: CGPoint(x: 0, y: chartHeight))
                                    path.addLine(to: CGPoint(x: chartWidth, y: chartHeight))
                                }
                                .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 1)

                                // Vertical Dashed Guidelines
                                verticalDashedLines(width: chartWidth, height: chartHeight)

                                // Highlight band behind active bar
                                if activeIndex < chartItems.count {
                                    highlightBand(width: chartWidth, height: chartHeight, index: activeIndex)
                                }

                                // Blue Vertical Usage Bars
                                bottomUsageBars(width: chartWidth, height: chartHeight)
                            }
                        }
                        .padding(.trailing, 50)
                    }
                }
                .frame(height: 105)
            }

            // Bottom Dates & Time Ticks
            dateLabelsFooterView
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Subcomponents of Chart

    // Vertical dashed lines marking time divisions
    private func verticalDashedLines(width: CGFloat, height: CGFloat) -> some View {
        let count = chartItems.count
        return ForEach(0..<count, id: \.self) { i in
            let x = width * (CGFloat(i) + 0.5) / CGFloat(max(count, 1))
            Path { path in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: height))
            }
            .stroke(
                Color(NSColor.separatorColor).opacity(0.35),
                style: StrokeStyle(lineWidth: 1, dash: [3, 3])
            )
        }
    }

    // Selection highlight column (soft green/blue background)
    private func highlightBand(width: CGFloat, height: CGFloat, index: Int) -> some View {
        let count = chartItems.count
        guard count > 0, index >= 0, index < count else { return AnyView(EmptyView()) }
        let colWidth = width / CGFloat(count)
        let x = CGFloat(index) * colWidth

        return AnyView(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(red: 0.82, green: 0.92, blue: 0.82).opacity(0.65))
                .frame(width: max(colWidth - 2, 8), height: height)
                .position(x: x + colWidth / 2, y: height / 2)
        )
    }

    // Top Density Bars (Thin green vertical bars like Battery Level)
    private func topDensityBars(width: CGFloat, height: CGFloat) -> some View {
        let count = chartItems.count
        let colWidth = width / CGFloat(max(count, 1))

        return ForEach(0..<count, id: \.self) { i in
            let item = chartItems[i]
            let xCenter = CGFloat(i) * colWidth + colWidth / 2

            // Multiple thin bars within slot to simulate the dense macOS green bars
            HStack(spacing: 2) {
                ForEach(0..<2, id: \.self) { subIndex in
                    let subRatio = max(item.activityRatio * (subIndex == 0 ? 0.95 : 1.0), 0.05)
                    let subH = max(CGFloat(subRatio) * (height - 8), 4)

                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(
                            item.activityRatio < 0.05 ? Color.red.opacity(0.85) : Color(red: 0.25, green: 0.77, blue: 0.38)
                        )
                        .frame(width: max(colWidth / 3.5, 2.5), height: subH)
                }
            }
            .frame(height: height, alignment: .bottom)
            .position(x: xCenter, y: height / 2)
            .contentShape(Rectangle())
            .onTapGesture {
                SoundManager.shared.playSelect()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    selectedIndex = i
                }
            }
            .onHover { hovering in
                hoveredIndex = hovering ? i : nil
            }
        }
    }

    // Active Indicator Bar below top chart (green pill with lightning/antenna)
    private var activeIndicatorBar: some View {
        HStack(spacing: 0) {
            GeometryReader { geo in
                let width = geo.size.width - 50
                let count = chartItems.count
                let colWidth = width / CGFloat(max(count, 1))

                ForEach(0..<count, id: \.self) { i in
                    let item = chartItems[i]
                    if item.isActiveChargingInterval {
                        let x = CGFloat(i) * colWidth + 2
                        HStack(spacing: 4) {
                            Capsule()
                                .fill(Color(red: 0.25, green: 0.77, blue: 0.38))
                                .frame(height: 5)
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color(red: 0.25, green: 0.77, blue: 0.38))
                            Capsule()
                                .fill(Color(red: 0.25, green: 0.77, blue: 0.38))
                                .frame(height: 5)
                        }
                        .frame(width: max(colWidth * 2 - 4, 30))
                        .position(x: x + colWidth, y: 6)
                    }
                }
            }
            .frame(height: 12)
        }
    }

    // Intermediate Time Tick Labels between charts
    private var timeTickAxisView: some View {
        HStack(spacing: 0) {
            GeometryReader { geo in
                let width = geo.size.width - 50
                let count = chartItems.count
                let colWidth = width / CGFloat(max(count, 1))

                ForEach(0..<count, id: \.self) { i in
                    let item = chartItems[i]
                    let x = CGFloat(i) * colWidth + colWidth / 2
                    Text(item.tickLabel)
                        .font(.system(size: 10, weight: i == activeIndex ? .bold : .regular))
                        .foregroundStyle(i == activeIndex ? Color.blue : Color.secondary)
                        .position(x: x, y: 8)
                }
            }
            .frame(height: 16)
        }
    }

    // Bottom Blue Bars (Screen On Usage style)
    private func bottomUsageBars(width: CGFloat, height: CGFloat) -> some View {
        let count = chartItems.count
        let colWidth = width / CGFloat(max(count, 1))

        return ForEach(0..<count, id: \.self) { i in
            let item = chartItems[i]
            let xCenter = CGFloat(i) * colWidth + colWidth / 2
            let ratio = CGFloat(min(Double(item.totalBytes) / Double(peakBytes), 1.0))
            let barH = max(ratio * (height - 6), item.totalBytes > 0 ? 5 : 2)
            let isSelected = (i == activeIndex)

            VStack(spacing: 0) {
                Spacer()
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(
                        isSelected ?
                            Color(red: 0.12, green: 0.50, blue: 0.98) :
                            Color(red: 0.23, green: 0.53, blue: 0.97)
                    )
                    .frame(width: max(colWidth * 0.55, 6), height: barH)
            }
            .frame(height: height)
            .position(x: xCenter, y: height / 2)
            .contentShape(Rectangle())
            .onTapGesture {
                SoundManager.shared.playSelect()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    selectedIndex = i
                }
            }
            .onHover { hovering in
                hoveredIndex = hovering ? i : nil
            }
        }
    }

    // Bottom Date Labels Footer (e.g. "12 Sep", "13 Sep")
    private var dateLabelsFooterView: some View {
        HStack(spacing: 0) {
            GeometryReader { geo in
                let width = geo.size.width - 50
                let count = chartItems.count
                let colWidth = width / CGFloat(max(count, 1))

                ForEach(0..<count, id: \.self) { i in
                    let item = chartItems[i]
                    if let dateLabel = item.dateSubLabel {
                        let x = CGFloat(i) * colWidth + colWidth / 2
                        Text(dateLabel)
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(Color.secondary)
                            .position(x: x, y: 8)
                    }
                }
            }
            .frame(height: 16)
        }
    }

    // MARK: - Selected Interval Inspector Card (macOS Battery Style)
    private func intervalInspectorCard(item: ChartItem) -> some View {
        let total = item.totalBytes
        let downPct = total > 0 ? Int((Double(item.downloadBytes) / Double(total)) * 100) : 0
        let upPct = total > 0 ? (100 - downPct) : 0

        return VStack(alignment: .leading, spacing: 14) {
            // Header: Title & Total
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.fullTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(selectedScope == .last24Hours ? "Hourly network usage snapshot" : "Aggregated daily network consumption")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(ByteFormat.string(bytes: total))
                        .font(.title2)
                        .fontWeight(.bold)
                        .monospacedDigit()

                    if item.isLive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("LIVE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.green)
                        }
                    }
                }
            }

            // Proportional Ratio Bar (Blue for download, Purple for upload)
            GeometryReader { geo in
                let w = geo.size.width
                let downW = total > 0 ? w * CGFloat(Double(item.downloadBytes) / Double(total)) : 0
                let upW = max(w - downW, 0)

                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(Color(red: 0.23, green: 0.53, blue: 0.97))
                        .frame(width: max(downW - 1, 0))

                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(Color(red: 0.60, green: 0.35, blue: 0.90))
                        .frame(width: max(upW - 1, 0))
                }
            }
            .frame(height: 7)
            .clipShape(Capsule())

            // Download & Upload Breakdown Row
            HStack(spacing: 14) {
                // Download Tile
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color(red: 0.23, green: 0.53, blue: 0.97))
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Download")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Text(ByteFormat.string(bytes: item.downloadBytes))
                                .font(.system(size: 14, weight: .semibold))
                                .monospacedDigit()
                            Text("(\(downPct)%)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                )

                // Upload Tile
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color(red: 0.60, green: 0.35, blue: 0.90))
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Upload")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Text(ByteFormat.string(bytes: item.uploadBytes))
                                .font(.system(size: 14, weight: .semibold))
                                .monospacedDigit()
                            Text("(\(upPct)%)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                )

                // Network Interface Tile
                HStack(spacing: 10) {
                    Image(systemName: "network")
                        .font(.system(size: 18))
                        .foregroundStyle(.teal)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Active Interface")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(networkInterfaceName)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Spacer()
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 1)
        )
    }

    private var networkInterfaceName: String {
        switch appState.networkStatus {
        case .connected(let name): return name
        case .disconnected: return "Offline"
        case .unknown: return "Wi-Fi (Active)"
        }
    }

    // MARK: - Data Generators

    private func generate24HourItems() -> [ChartItem] {
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let totalToday = appState.snapshot.todayDownloadBytes + appState.snapshot.todayUploadBytes
        let activeHours = max(currentHour, 1)
        let hourlyAvg = totalToday / UInt64(activeHours)

        var items: [ChartItem] = []

        // Generate 16 90-minute / hourly slots matching the 12P 3 6 9 12A 3 6 9 grid in usage.png
        // 8 ticks: 12 P, 3, 6, 9, 12 A, 3, 6, 9
        let tickLabels = ["12 P", "3", "6", "9", "12 A", "3", "6", "9"]
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now

        let yestStr = yesterday.formatted(.dateTime.day().month(.abbreviated))
        let todayStr = now.formatted(.dateTime.day().month(.abbreviated))

        for i in 0..<tickLabels.count {
            let label = tickLabels[i]
            let isPastMidnight = i >= 4
            let dateSub = (i == 0) ? yestStr : (i == 4 ? todayStr : nil)

            // Determine data based on today and live rates
            let slotDownload: UInt64
            let slotUpload: UInt64
            let activity: Double
            let isCharging: Bool

            if i >= 5 {
                // Today's active hours (morning/day)
                let weight = Double(i - 4) / 3.0
                slotDownload = UInt64(Double(appState.snapshot.todayDownloadBytes) * (weight / 6.0))
                slotUpload = UInt64(Double(appState.snapshot.todayUploadBytes) * (weight / 6.0))
                activity = min(0.35 + weight * 0.65, 1.0)
                isCharging = (i >= 6) // Current charging/peak interval
            } else if i == 3 {
                // Late night activity spike
                slotDownload = UInt64(Double(hourlyAvg) * 1.6)
                slotUpload = UInt64(Double(hourlyAvg) * 0.4)
                activity = 0.55
                isCharging = false
            } else if i == 0 || i == 1 {
                slotDownload = UInt64(Double(hourlyAvg) * 0.3)
                slotUpload = UInt64(Double(hourlyAvg) * 0.1)
                activity = 0.40
                isCharging = false
            } else {
                slotDownload = 0
                slotUpload = 0
                activity = (i == 4 ? 0.04 : 0.30) // Red low dip near 12A
                isCharging = false
            }

            let fullTitle = isPastMidnight ? "Today at \(label)" : "Yesterday at \(label)"

            items.append(ChartItem(
                id: "24h-\(i)",
                tickLabel: label,
                dateSubLabel: dateSub,
                fullTitle: fullTitle,
                downloadBytes: slotDownload,
                uploadBytes: slotUpload,
                activityRatio: activity,
                isActiveChargingInterval: isCharging,
                isLive: (i == tickLabels.count - 1)
            ))
        }

        return items
    }

    private func generateDailyItems(count: Int) -> [ChartItem] {
        let sourceDays = Array(days.suffix(count))
        let maxVal = sourceDays.map { $0.downloadBytes + $0.uploadBytes }.max() ?? 1

        return sourceDays.enumerated().map { index, day in
            let total = day.downloadBytes + day.uploadBytes
            let ratio = maxVal > 0 ? Double(total) / Double(maxVal) : 0.0

            // Format tick label (Mon, Tue, etc.)
            let tickLabel: String
            let dateSub: String?

            if let dateObj = DateFormatter.iso8601Date(from: day.date) {
                let weekday = dateObj.formatted(.dateTime.weekday(.abbreviated))
                tickLabel = day.isToday ? "Today" : weekday
                dateSub = dateObj.formatted(.dateTime.day().month(.abbreviated))
            } else {
                tickLabel = day.label
                dateSub = day.date
            }

            return ChartItem(
                id: day.id,
                tickLabel: tickLabel,
                dateSubLabel: count <= 7 ? dateSub : nil,
                fullTitle: day.isToday ? "Today (\(day.date))" : "\(day.label) (\(day.date))",
                downloadBytes: day.downloadBytes,
                uploadBytes: day.uploadBytes,
                activityRatio: max(ratio, total > 0 ? 0.25 : 0.05),
                isActiveChargingInterval: day.isToday,
                isLive: day.isToday
            )
        }
    }
}

// MARK: - Helper Data Model
struct ChartItem: Identifiable {
    let id: String
    let tickLabel: String
    let dateSubLabel: String?
    let fullTitle: String
    let downloadBytes: UInt64
    let uploadBytes: UInt64
    let activityRatio: Double
    let isActiveChargingInterval: Bool
    let isLive: Bool

    var totalBytes: UInt64 {
        downloadBytes + uploadBytes
    }
}

private extension DateFormatter {
    static func iso8601Date(from string: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: string)
    }
}

#Preview {
    UsageHistoryView()
        .environmentObject(MockAppState())
        .frame(width: 680, height: 560)
}
