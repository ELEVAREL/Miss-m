import SwiftUI

// MARK: - Calendar Full View (Phase 2)
// Month grid + day time blocks + AI scheduling

struct CalendarFullView: View {
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var events: [CalendarEvent] = []
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            // Header (per design: Playfair title + action buttons)
            HStack(alignment: .firstTextBaseline) {
                Text("Calendar & ")
                    .font(.custom("PlayfairDisplay-Italic", size: 20))
                    .foregroundColor(Theme.Colors.textPrimary)
                + Text("Schedule")
                    .font(.custom("PlayfairDisplay-Italic", size: 20))
                    .foregroundColor(Theme.Colors.rosePrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Navigation bar
            HStack {
                Text(monthYearString)
                    .font(.custom("PlayfairDisplay-Italic", size: 18))
                    .foregroundColor(Theme.Colors.textPrimary)
                Spacer()
                HStack(spacing: 8) {
                    CalNavButton(icon: "‹") { changeMonth(-1) }
                    CalNavButton(icon: "›") { changeMonth(1) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            // Month grid
            MonthGridView(
                currentMonth: currentMonth,
                selectedDate: $selectedDate,
                events: events
            )
            .padding(.horizontal, 16)

            Divider().padding(.vertical, 6)

            // Day detail
            DayDetailView(date: selectedDate, events: eventsForSelectedDate)
        }
        .task { await loadEvents() }
        .onChange(of: currentMonth) { await loadEvents() }
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    private var eventsForSelectedDate: [CalendarEvent] {
        let calendar = Calendar.current
        return events.filter { calendar.isDate($0.startDate, inSameDayAs: selectedDate) }
    }

    private func changeMonth(_ delta: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: delta, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    private func loadEvents() async {
        isLoading = true
        defer { isLoading = false }
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let start = calendar.date(from: comps),
              let end = calendar.date(byAdding: .month, value: 1, to: start) else { return }
        events = await CalendarService.shared.getEvents(from: start, to: end)
    }
}

// MARK: - Month Grid
struct MonthGridView: View {
    let currentMonth: Date
    @Binding var selectedDate: Date
    let events: [CalendarEvent]

    private let calendar = Calendar.current
    private let weekdays = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(spacing: 4) {
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Theme.Colors.textSoft)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            let days = daysInMonth()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                ForEach(days, id: \.self) { date in
                    if let date {
                        DayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            hasEvents: events.contains { calendar.isDate($0.startDate, inSameDayAs: date) }
                        )
                        .onTapGesture { selectedDate = date }
                    } else {
                        Text("")
                            .frame(maxWidth: .infinity, minHeight: 28)
                    }
                }
            }
        }
    }

    private func daysInMonth() -> [Date?] {
        let comps = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let firstDay = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: firstDay) else { return [] }

        // Weekday offset (Monday = 0)
        var weekday = calendar.component(.weekday, from: firstDay) - 2
        if weekday < 0 { weekday += 7 }

        var days: [Date?] = Array(repeating: nil, count: weekday)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        // Pad to fill last row
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }
}

// MARK: - Day Cell (per design: gradient today, event dots)
struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasEvents: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 12, weight: isToday ? .bold : .medium))
                .foregroundColor(foregroundColor)

            if hasEvents {
                HStack(spacing: 2) {
                    Circle()
                        .fill(isToday ? Color.white.opacity(0.8) : Theme.Colors.rosePrimary)
                        .frame(width: 4, height: 4)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 32)
        .background(backgroundColor)
        .cornerRadius(10)
    }

    private var foregroundColor: Color {
        if isToday { return .white }
        if isSelected { return Theme.Colors.rosePrimary }
        return Theme.Colors.textPrimary
    }

    private var backgroundColor: Color {
        if isToday {
            return Color.clear // Use overlay for gradient
        }
        return .clear
    }
}

// MARK: - Calendar Navigation Button
struct CalNavButton: View {
    let icon: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(icon)
                .font(.system(size: 13))
                .frame(width: 30, height: 30)
                .background(isHovered ? Color.white : Color.white.opacity(0.8))
                .clipShape(Circle())
                .overlay(Circle().stroke(isHovered ? Theme.Colors.roseMid : Theme.Colors.roseLight, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Day Detail View
struct DayDetailView: View {
    let date: Date
    let events: [CalendarEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(dayHeaderString)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.Colors.textPrimary)
                .padding(.horizontal, 16)

            ScrollView {
                if events.isEmpty {
                    VStack(spacing: 8) {
                        Text("No events")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textXSoft)
                        Text("Your day is free!")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textXSoft)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    LazyVStack(spacing: 6) {
                        ForEach(events) { event in
                            EventRow(event: event)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private var dayHeaderString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: date)
    }
}

// MARK: - Event Row (per design: colored dot, info, time)
struct EventRow: View {
    let event: CalendarEvent
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Colored dot
            Circle()
                .fill(Theme.Colors.rosePrimary)
                .frame(width: 10, height: 10)

            // Event info
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if let location = event.location, !location.isEmpty {
                        Text(location)
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textSoft)
                    }
                    Text(event.calendarName)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textSoft)
                }
            }

            Spacer()

            // Time
            Text(event.timeString)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Theme.Colors.rosePrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isHovered ? Color.white : Color.white.opacity(0.6))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.glassBorder, lineWidth: 1))
        .offset(x: isHovered ? 2 : 0)
        .animation(.easeOut(duration: 0.18), value: isHovered)
        .onHover { isHovered = $0 }
    }
}
