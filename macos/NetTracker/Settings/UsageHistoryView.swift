import SwiftUI

/// UsageHistoryView delivers a macOS System Settings (Battery-style) interactive
/// usage matrix and chart displaying daily network transfer data.
struct UsageHistoryView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedDayId: String?
    @State private var hoveredDayId: String?

    private var days: [DailyUsage] {
        appState.historyDays.isEmpty ? appState.last7Days : appState.historyDays
    }

    private var activeDay: DailyUsage? {
        if let id = selectedDayId, let match = days.first(where: { $0.id == id }) {
            return match
        }
        return days.last // Default to today
    }

    private var maxDayBytes: UInt64 {
        let highest = days.map { $0.downloadBytes + $0.uploadBytes }.max() ?? 0
        // Ensure non-zero baseline of at least 10 MB for clean rendering
        return max(highest, 10 * 1024 * 1024)
    }

    private var totalDownload: UInt64 {
        days.reduce(0) { $0 + $1.downloadBytes }
    }

    private var totalUpload: UInt64 {
        days.reduce(0) { $0 + $1.uploadBytes }
    }

    private var totalUsage: UInt64 {
        totalDownload + totalUpload
    }

    private var dailyAverage: UInt64 {
        guard !days.isEmpty else { return 0 }
        return totalUsage / UInt64(days.count)
    }

    private var peakDay: DailyUsage? {
        days.max(by: { ($0.downloadBytes + $0.uploadBytes) < ($1.downloadBytes + $1.uploadBytes) })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Top control bar
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Usage History")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Visual breakdown of network upload and download across previous days.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Range segmented picker (7, 14, 30 days)
                    Picker("Time Range", selection: Binding(
                        get: { appState.selectedHistoryRange },
                        set: { newRange in
                            Task { await appState.setHistoryRange(newRange) }
                        }
                    )) {
                        Text("7 Days").tag(7)
                        Text("14 Days").tag(14)
                        Text("30 Days").tag(30)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)

                    // Refresh button
                    Button {
                        Task { await appState.refreshHistory() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh history")
                }

                // Summary metric cards
                summaryCardsSection

                // Interactive Chart Container
                chartContainerSection

                // Selected Day Inspector Card
                if let day = activeDay {
                    selectedDayInspector(day: day)
                }
            }
            .padding(20)
        }
    }

    // MARK: - Summary Cards
    private var summaryCardsSection: some View {
        HStack(spacing: 12) {
            // Card 1: Total Transferred
            summaryCard(
                title: "TOTAL TRANSFERRED",
                value: ByteFormat.string(bytes: totalUsage),
                subtitle: "↓ \(ByteFormat.string(bytes: totalDownload)) • ↑ \(ByteFormat.string(bytes: totalUpload))",
                icon: "arrow.up.arrow.down.circle.fill",
                iconColor: .blue
            )

            // Card 2: Daily Average
            summaryCard(
                title: "DAILY AVERAGE",
                value: "\(ByteFormat.string(bytes: dailyAverage)) / day",
                subtitle: "Across last \(days.count) active days",
                icon: "chart.line.uptrend.xyaxis.circle.fill",
                iconColor: .teal
            )

            // Card 3: Peak Usage
            summaryCard(
                title: "PEAK USAGE",
                value: ByteFormat.string(bytes: (peakDay?.downloadBytes ?? 0) + (peakDay?.uploadBytes ?? 0)),
                subtitle: peakDay?.label ?? "No data",
                icon: "flame.circle.fill",
                iconColor: .orange
            )
        }
    }

    private func summaryCard(
        title: String,
        value: String,
        subtitle: String,
        icon: String,
        iconColor: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundStyle(iconColor)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Chart Container
    private var chartContainerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Network Activity Matrix")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                // Legend
                HStack(spacing: 14) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .top, endPoint: .bottom))
                            .frame(width: 8, height: 8)
                        Text("Download")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 5) {
                        Circle()
                            .fill(LinearGradient(colors: [.purple, .indigo], startPoint: .top, endPoint: .bottom))
                            .frame(width: 8, height: 8)
                        Text("Upload")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if days.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading network history...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
            } else {
                // Chart Box with grid guidelines
                ZStack(alignment: .topLeading) {
                    // Y-axis grid guidelines
                    yAxisGrid

                    // Columns for each day
                    HStack(alignment: .bottom, spacing: dayColumnSpacing) {
                        ForEach(days) { day in
                            dayColumn(day: day)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 16)
                    .padding(.bottom, 28) // Room for day labels
                }
                .frame(height: 190)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 1)
                )
            }
        }
    }

    private var dayColumnSpacing: CGFloat {
        if days.count <= 7 { return 24 }
        if days.count <= 14 { return 12 }
        return 5
    }

    // Reference dashed grid lines for top, mid, and baseline
    private var yAxisGrid: some View {
        VStack(spacing: 0) {
            HStack {
                Text(ByteFormat.string(bytes: maxDayBytes))
                    .font(.system(size: 9))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                Line()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Color(NSColor.separatorColor).opacity(0.4))
            }
            .frame(height: 12)

            Spacer()

            HStack {
                Text(ByteFormat.string(bytes: maxDayBytes / 2))
                    .font(.system(size: 9))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                Line()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Color(NSColor.separatorColor).opacity(0.4))
            }
            .frame(height: 12)

            Spacer()

            HStack {
                Text("0 B")
                    .font(.system(size: 9))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                Line()
                    .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 1)
            }
            .frame(height: 12)
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 8)
        .padding(.top, 14)
    }

    // Individual Day Bar Column
    private func dayColumn(day: DailyUsage) -> some View {
        let isSelected = (activeDay?.id == day.id)
        let isHovered = (hoveredDayId == day.id)
        let total = day.downloadBytes + day.uploadBytes

        // Heights proportional to maxDayBytes within available bar height (120pt)
        let maxBarHeight: CGFloat = 114
        let totalHeightRatio = CGFloat(min(Double(total) / Double(maxDayBytes), 1.0))
        let effectiveBarHeight = max(totalHeightRatio * maxBarHeight, total > 0 ? 6 : 2)

        let downRatio = total > 0 ? CGFloat(Double(day.downloadBytes) / Double(total)) : 0
        let downHeight = effectiveBarHeight * downRatio
        let upHeight = max(effectiveBarHeight - downHeight, 0)

        return Button {
            SoundManager.shared.playSelect()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                selectedDayId = day.id
            }
        } label: {
            VStack(spacing: 6) {
                // Bar Stack
                ZStack(alignment: .bottom) {
                    // Track Pill Background
                    Capsule()
                        .fill(isSelected ? Color.blue.opacity(0.12) : Color(NSColor.quaternaryLabelColor).opacity(0.2))
                        .frame(maxWidth: .infinity)
                        .frame(height: maxBarHeight)

                    // Stacked Usage Bar
                    VStack(spacing: 1) {
                        // Upload (Purple) on top
                        if upHeight > 0 {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.purple, Color.indigo],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: upHeight)
                        }

                        // Download (Blue) at bottom
                        if downHeight > 0 {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue, Color.cyan.opacity(0.85)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: downHeight)
                        }
                    }
                    .clipShape(Capsule())
                    .frame(height: effectiveBarHeight)
                }
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isSelected ? Color.blue : (isHovered ? Color.secondary.opacity(0.4) : Color.clear),
                            lineWidth: isSelected ? 2 : 1
                        )
                )

                // Day Label below bar
                Text(columnLabel(for: day))
                    .font(.system(size: days.count > 14 ? 9 : 10, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? Color.blue : (day.isToday ? Color.primary : Color.secondary))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredDayId = hovering ? day.id : nil
        }
    }

    private func columnLabel(for day: DailyUsage) -> String {
        if day.isToday {
            return "Today"
        }
        if days.count > 14 {
            // Just the day number (e.g. "12")
            let parts = day.date.split(separator: "-")
            return parts.last.map(String.init) ?? day.label
        }
        return day.label
    }

    // MARK: - Selected Day Inspector
    private func selectedDayInspector(day: DailyUsage) -> some View {
        let total = day.downloadBytes + day.uploadBytes
        let downPct = total > 0 ? Int((Double(day.downloadBytes) / Double(total)) * 100) : 0
        let upPct = total > 0 ? (100 - downPct) : 0

        return VStack(alignment: .leading, spacing: 12) {
            // Header of inspector
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: day.isToday ? "clock.arrow.circlepath" : "calendar")
                        .foregroundStyle(day.isToday ? Color.blue : Color.secondary)

                    Text(day.isToday ? "Today's Activity (\(day.date))" : "Usage on \(day.label) (\(day.date))")
                        .font(.headline)

                    if day.isToday {
                        Text("LIVE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.blue))
                    }
                }

                Spacer()

                Text(ByteFormat.string(bytes: total))
                    .font(.title3)
                    .fontWeight(.bold)
                    .monospacedDigit()
            }

            // Proportional Ratio Split Bar
            GeometryReader { geo in
                let width = geo.size.width
                let downWidth = total > 0 ? width * CGFloat(Double(day.downloadBytes) / Double(total)) : 0
                let upWidth = width - downWidth

                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(downWidth - 1, 0))

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(LinearGradient(colors: [.purple, .indigo], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(upWidth - 1, 0))
                }
            }
            .frame(height: 8)
            .clipShape(Capsule())

            // Breakdown Tiles
            HStack(spacing: 12) {
                // Download Tile
                HStack(spacing: 10) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Download")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Text(ByteFormat.string(bytes: day.downloadBytes))
                                .font(.system(size: 15, weight: .semibold))
                                .monospacedDigit()
                            Text("\(downPct)%")
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
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.purple)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Upload")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Text(ByteFormat.string(bytes: day.uploadBytes))
                                .font(.system(size: 15, weight: .semibold))
                                .monospacedDigit()
                            Text("\(upPct)%")
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
}

// Shape helper for horizontal grid lines
private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

#Preview {
    UsageHistoryView()
        .environmentObject(MockAppState())
        .frame(width: 660, height: 500)
}
