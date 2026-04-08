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
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CALENDAR")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2.5)
                        .foregroundColor(Theme.Colors.textSoft)
                    Text(monthYearString)
                        .font(.custom("PlayfairDisplay-Italic", size: 18))
                        .foregroundColor(Theme.Colors.rosePrimary)
                }
                Spacer()
                HStack(spacing: 12) {
                    Button(action: { changeMonth(-1) }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.Colors.rosePrimary)
                    }
                    .buttonStyle(.plain)
                    Button("Today") {
                        currentMonth = Date()
                        selectedDate = Date()
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.Colors.rosePrimary)
                    Button(action: { changeMonth(1) }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.Colors.rosePrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

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

// MARK: - Day Cell
struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasEvents: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 11, weight: isToday ? .bold : .regular))
                .foregroundColor(foregroundColor)

            if hasEvents {
                Circle()
                    .fill(Theme.Colors.rosePrimary)
                    .frame(width: 4, height: 4)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 28)
        .background(backgroundColor)
        .cornerRadius(6)
    }

    private var foregroundColor: Color {
        if isSelected { return .white }
        if isToday { return Theme.Colors.rosePrimary }
        return Theme.Colors.textPrimary
    }

    private var backgroundColor: Color {
        if isSelected { return Theme.Colors.rosePrimary }
        if isToday { return Theme.Colors.rosePale }
        return .clear
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

// MARK: - Event Row
struct EventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 10) {
            // Time block
            VStack(spacing: 2) {
                Text(event.timeString)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.Colors.rosePrimary)
                if !event.isAllDay {
                    Text(endTimeString)
                        .font(.system(size: 9))
                        .foregroundColor(Theme.Colors.textXSoft)
                }
            }
            .frame(width: 55)

            // Color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.Gradients.rosePrimary)
                .frame(width: 3)

            // Event details
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                if let location = event.location, !location.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "mappin")
                            .font(.system(size: 8))
                        Text(location)
                            .font(.system(size: 9))
                    }
                    .foregroundColor(Theme.Colors.textSoft)
                }
                Text(event.calendarName)
                    .font(.system(size: 8))
                    .foregroundColor(Theme.Colors.textXSoft)
            }
            Spacer()
        }
        .padding(8)
        .glassCard(padding: 0)
    }

    private var endTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: event.endDate)
    }
}
