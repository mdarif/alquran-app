import SwiftUI
import WidgetKit

// MARK: - Payload (mirrors lib/core/home_widget/widget_payload.dart)

private struct WidgetMarker: Decodable {
    let name: String
    let isSalah: Bool
    let at: String
}

private struct WidgetDay: Decodable {
    let date: String
    let markers: [WidgetMarker]
}

private struct WidgetPayload: Decodable {
    let schemaVersion: Int
    let generatedAt: String
    let hasLocation: Bool
    let locationLabel: String?
    let days: [WidgetDay]
}

private struct Marker {
    let name: String
    let isSalah: Bool
    let date: Date
}

// MARK: - Shared data access (App Group)

private enum PrayerData {
    static let appGroup = "group.com.almarfa.alQuran"
    static let payloadKey = "prayer_widget_payload"

    // Dart writes device-local wall-clock with no offset; parse in the device's
    // own zone (same device) to recover the right instant.
    static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        f.timeZone = .current
        return f
    }()

    static func load() -> WidgetPayload? {
        guard
            let raw = UserDefaults(suiteName: appGroup)?.string(forKey: payloadKey),
            let data = raw.data(using: .utf8)
        else { return nil }
        return try? JSONDecoder().decode(WidgetPayload.self, from: data)
    }
}

private extension WidgetPayload {
    /// Every marker across the serialised days, chronologically.
    func allMarkers() -> [Marker] {
        days.flatMap { day in
            day.markers.compactMap { m in
                guard let d = PrayerData.isoFormatter.date(from: m.at) else { return nil }
                return Marker(name: m.name, isSalah: m.isSalah, date: d)
            }
        }
    }

    /// Today's five salah (Sunrise excluded), in order.
    func todaySalah() -> [Marker] {
        guard let first = days.first else { return [] }
        return first.markers.compactMap { m in
            guard m.isSalah, let d = PrayerData.isoFormatter.date(from: m.at) else { return nil }
            return Marker(name: m.name, isSalah: m.isSalah, date: d)
        }
    }

    func nextMarker(after date: Date) -> Marker? {
        allMarkers().first { $0.date > date }
    }
}

// MARK: - Palette (mirrors the Android widget colours)

private enum Palette {
    static let surface = Color(red: 0.063, green: 0.251, blue: 0.231) // #10403B
    static let highlight = Color(red: 0.110, green: 0.353, blue: 0.314) // #1C5A50
    static let label = Color(red: 0.498, green: 0.659, blue: 0.620) // #7FA89E
    static let labelBright = Color(red: 0.561, green: 0.702, blue: 0.667) // #8FB3AA
    static let time = Color(red: 0.863, green: 0.910, blue: 0.890) // #DCE8E3
    static let hero = Color(red: 0.957, green: 0.945, blue: 0.914) // #F4F1E9
    static let gold = Color(red: 0.894, green: 0.851, blue: 0.722) // #E4D9B8
}

private extension View {
    /// Fills the widget surface — `containerBackground` on iOS 17+, plain
    /// background below it.
    @ViewBuilder func widgetSurface() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(Palette.surface, for: .widget)
        } else {
            self.background(Palette.surface)
        }
    }
}

// MARK: - Timeline

private struct PrayerEntry: TimelineEntry {
    let date: Date
    let payload: WidgetPayload?
}

private struct PrayerProvider: TimelineProvider {
    func placeholder(in context: Context) -> PrayerEntry {
        PrayerEntry(date: Date(), payload: PrayerData.load())
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        completion(PrayerEntry(date: Date(), payload: PrayerData.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        let payload = PrayerData.load()
        let now = Date()
        // One entry now, then one at each upcoming marker so "next" / the
        // highlight advances without waking the app.
        var dates: [Date] = [now]
        if let payload = payload {
            let upcoming = payload.allMarkers().map { $0.date }.filter { $0 > now }.sorted()
            dates.append(contentsOf: upcoming.prefix(12))
        }
        let entries = dates.map { PrayerEntry(date: $0, payload: payload) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Next prayer (small)

private struct NextPrayerView: View {
    let entry: PrayerEntry

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    var body: some View {
        VStack(spacing: 2) {
            if let payload = entry.payload, payload.hasLocation,
               let next = payload.nextMarker(after: entry.date) {
                Text(next.name.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(Palette.labelBright)
                Text(Self.timeFormatter.string(from: next.date))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Palette.hero)
            } else {
                Text("SET LOCATION")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.0)
                    .foregroundColor(Palette.labelBright)
                Text("Tap to open")
                    .font(.system(size: 14))
                    .foregroundColor(Palette.time)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetSurface()
    }
}

// MARK: - Today's prayers (medium)

private struct ScheduleView: View {
    let entry: PrayerEntry

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm" // no AM/PM — keeps the five columns uniform
        return f
    }()

    var body: some View {
        Group {
            if let payload = entry.payload, payload.hasLocation {
                let salah = payload.todaySalah()
                let nextIndex = salah.firstIndex { $0.date > entry.date }
                HStack(spacing: 0) {
                    ForEach(Array(salah.enumerated()), id: \.offset) { index, marker in
                        let highlighted = index == nextIndex
                        VStack(spacing: 2) {
                            Text(marker.name.uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(highlighted ? Palette.gold : Palette.label)
                            Text(Self.timeFormatter.string(from: marker.date))
                                .font(.system(size: 15, weight: highlighted ? .bold : .regular))
                                .foregroundColor(highlighted ? .white : Palette.time)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(highlighted ? Palette.highlight : Color.clear)
                        )
                    }
                }
                .padding(8)
            } else {
                Text("Set location · tap to open")
                    .font(.system(size: 14))
                    .foregroundColor(Palette.time)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetSurface()
    }
}

// MARK: - Widgets

struct PrayerWidget: Widget {
    let kind = "PrayerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerProvider()) { entry in
            NextPrayerView(entry: entry)
        }
        .configurationDisplayName("Next prayer")
        .description("The next prayer and its time.")
        .supportedFamilies([.systemSmall])
    }
}

struct PrayerScheduleWidget: Widget {
    let kind = "PrayerScheduleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerProvider()) { entry in
            ScheduleView(entry: entry)
        }
        .configurationDisplayName("Today's prayers")
        .description("All five prayer times for today.")
        .supportedFamilies([.systemMedium])
    }
}

@main
struct PrayerWidgetBundle: WidgetBundle {
    var body: some Widget {
        PrayerWidget()
        PrayerScheduleWidget()
    }
}
