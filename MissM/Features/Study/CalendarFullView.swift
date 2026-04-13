import SwiftUI
import EventKit

// MARK: - Calendar Full View

struct CalendarFullView: View {
    @State private var selectedDate = Date()
    @State private var events: [EKEvent] = []
    @State private var displayedMonth = Date()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Text("Calendar")
                        .font(Theme.Fonts.display(18))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    Spacer()
                    HStack(spacing: 12) {
                        Button(action: { changeMonth(-1) }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Theme.Colors.textSoft)
                        }
                        .buttonStyle(.plain)
                        Text(monthYearString)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Theme.Colors.textPrimary)
                        Button(action: { changeMonth(1) }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Theme.Colors.textSoft)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)

                // Month Grid
                MonthGridView(
                    displayedMonth: displayedMonth,
                    selectedDate: $selectedDate,
                    events: events
                )
                .padding(.horizontal, 14)

                // Selected Day Events
                VStack(alignment: .leading, spacing: 8) {
                    Text(selectedDayString.uppercased())
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2)
                        .foregroundColor(Theme.Colors.textSoft)

                    let dayEvents = eventsForSelectedDay
                    if dayEvents.isEmpty {
                        HStack {
                            Text("No events on this day")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textXSoft)
                            Spacer()
                        }
                    } else {
                        ForEach(dayEvents, id: \.eventIdentifier) { event in
                            CalendarEventRow(event: event)
                        }
                    }
                }
                .glassCard(padding: 10)
                .padding(.horizontal, 14)

                // Upcoming Deadlines
                VStack(alignment: .leading, spacing: 8) {
                    Text("UPCOMING THIS WEEK")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2)
                        .foregroundColor(Theme.Colors.textSoft)

                    let upcoming = upcomingEvents
                    if upcoming.isEmpty {
                        Text("Nothing scheduled this week")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textXSoft)
                    } else {
                        ForEach(upcoming.prefix(5), id: \.eventIdentifier) { event in
                            HStack(spacing: 8) {
                                VStack {
                                    Text(dayOfWeek(event.startDate))
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(Theme.Colors.rosePrimary)
                                    Text("\(Calendar.current.component(.day, from: event.startDate))")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Theme.Colors.textPrimary)
                                }
                                .frame(width: 36)
                                .padding(.vertical, 4)
                                .background(Theme.Colors.rosePale)
                                .cornerRadius(8)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title ?? "Untitled")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(Theme.Colors.textPrimary)
                                    Text(timeString(event.startDate))
                                        .font(.system(size: 9))
                                        .foregroundColor(Theme.Colors.textSoft)
                                }
                                Spacer()
                            }
                        }
                    }
                }
                .glassCard(padding: 10)
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
            .padding(.top, 10)
        }
        .task { await loadEvents() }
        .onChange(of: displayedMonth) { Task { await loadEvents() } }
    }

    // MARK: - Helpers

    var monthYearString: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayedMonth)
    }

    var selectedDayString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: selectedDate)
    }

    var eventsForSelectedDay: [EKEvent] {
        events.filter { Calendar.current.isDate($0.startDate, inSameDayAs: selectedDate) }
    }

    var upcomingEvents: [EKEvent] {
        let cal = Calendar.current
        let start = Date()
        guard let end = cal.date(byAdding: .day, value: 7, to: start) else { return [] }
        return events.filter { $0.startDate >= start && $0.startDate <= end }
            .sorted { $0.startDate < $1.startDate }
    }

    func changeMonth(_ delta: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

    func loadEvents() async {
        let cal = Calendar.current
        guard let start = cal.date(from: cal.dateComponents([.year, .month], from: displayedMonth)),
              let end = cal.date(byAdding: .month, value: 1, to: start) else { return }
        events = CalendarService.shared.getEvents(from: start, to: end)
    }

    func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    func dayOfWeek(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }
}

// MARK: - Month Grid

struct MonthGridView: View {
    let displayedMonth: Date
    @Binding var selectedDate: Date
    let events: [EKEvent]

    let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    let weekdays = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

    var body: some View {
        VStack(spacing: 4) {
            // Weekday headers
            HStack(spacing: 2) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Theme.Colors.textXSoft)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day cells
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(daysInMonth, id: \.self) { date in
                    let isCurrentMonth = Calendar.current.isDate(date, equalTo: displayedMonth, toGranularity: .month)
                    let isToday = Calendar.current.isDateInToday(date)
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                    let hasEvents = events.contains { Calendar.current.isDate($0.startDate, inSameDayAs: date) }

                    VStack(spacing: 2) {
                        Text("\(Calendar.current.component(.day, from: date))")
                            .font(.system(size: 11, weight: isToday ? .bold : .regular))
                            .foregroundColor(isSelected ? .white : (isCurrentMonth ? Theme.Colors.textPrimary : Theme.Colors.textXSoft))
                        if hasEvents {
                            Circle()
                                .fill(isSelected ? Color.white : Theme.Colors.rosePrimary)
                                .frame(width: 4, height: 4)
                        } else {
                            Spacer().frame(height: 4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        isSelected ? AnyView(Theme.Gradients.rosePrimary) :
                        isToday ? AnyView(Theme.Colors.rosePale) :
                        AnyView(Color.clear)
                    )
                    .cornerRadius(8)
                    .onTapGesture { selectedDate = date }
                }
            }
        }
        .glassCard(padding: 8)
    }

    var daysInMonth: [Date] {
        let cal = Calendar.current
        guard let monthInterval = cal.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let firstDay = monthInterval.start
        let firstWeekday = cal.component(.weekday, from: firstDay)
        let startOffset = -(firstWeekday - 1)

        return (0..<42).compactMap { i in
            cal.date(byAdding: .day, value: startOffset + i, to: firstDay)
        }
    }
}

// MARK: - Calendar Event Row

struct CalendarEventRow: View {
    let event: EKEvent

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(cgColor: event.calendar.cgColor))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title ?? "Untitled")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Colors.textPrimary)
                HStack(spacing: 4) {
                    Text({
                        let f = DateFormatter()
                        f.dateFormat = "h:mm a"
                        return "\(f.string(from: event.startDate)) - \(f.string(from: event.endDate))"
                    }())
                        .font(.system(size: 9))
                        .foregroundColor(Theme.Colors.textSoft)
                    if let location = event.location, !location.isEmpty {
                        Text("\u{2022} \(location)")
                            .font(.system(size: 9))
                            .foregroundColor(Theme.Colors.textXSoft)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
