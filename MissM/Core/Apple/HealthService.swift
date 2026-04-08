import HealthKit
import Foundation

// MARK: - Health Service
// Reads HealthKit data for wellness dashboard — Phase 6
// Steps, sleep, heart rate, HRV, active calories, mindful sessions, mood logging

@Observable
class HealthService {
    static let shared = HealthService()

    private let store = HKHealthStore()

    var isAuthorized = false
    var authorizationError: HealthServiceError?

    // MARK: - Latest readings (observable for UI)
    var todaySteps: Double = 0
    var todayActiveCalories: Double = 0
    var latestHeartRate: Double = 0
    var latestHRV: Double = 0
    var todaySleepHours: Double = 0
    var todayMindfulMinutes: Double = 0

    // MARK: - HealthKit Type Identifiers

    private var stepType: HKQuantityType {
        HKQuantityType.quantityType(forIdentifier: .stepCount)!
    }
    private var activeCaloriesType: HKQuantityType {
        HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
    }
    private var heartRateType: HKQuantityType {
        HKQuantityType.quantityType(forIdentifier: .heartRate)!
    }
    private var hrvType: HKQuantityType {
        HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    }
    private var sleepType: HKCategoryType {
        HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
    }
    private var mindfulType: HKCategoryType {
        HKCategoryType.categoryType(forIdentifier: .mindfulSession)!
    }

    // MARK: - Cycle Tracking Types (Phase 6)

    private var menstrualFlowType: HKCategoryType {
        HKCategoryType.categoryType(forIdentifier: .menstrualFlow)!
    }
    private var cervicalMucusType: HKCategoryType {
        HKCategoryType.categoryType(forIdentifier: .cervicalMucusQuality)!
    }
    private var ovulationTestType: HKCategoryType {
        HKCategoryType.categoryType(forIdentifier: .ovulationTestResult)!
    }
    private var intermenstrualBleedingType: HKCategoryType {
        HKCategoryType.categoryType(forIdentifier: .intermenstrualBleeding)!
    }

    // MARK: - Cycle Tracking Observable State
    var currentCycleDay: Int = 0
    var currentPhase: CyclePhase = .unknown
    var lastPeriodStart: Date?

    // MARK: - Types to Read & Share

    private var readTypes: Set<HKObjectType> {
        [
            stepType,
            activeCaloriesType,
            heartRateType,
            hrvType,
            sleepType,
            mindfulType,
            menstrualFlowType,
            cervicalMucusType,
            ovulationTestType,
            intermenstrualBleedingType
        ]
    }

    private var shareTypes: Set<HKSampleType> {
        [
            mindfulType,
            menstrualFlowType
        ]
    }

    // MARK: - Initialization

    init() {
        // HealthKit availability is checked before any requests
    }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthServiceError.healthDataUnavailable
        }

        try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
        isAuthorized = true
    }

    var authorizationStatus: HKAuthorizationStatus {
        store.authorizationStatus(for: stepType)
    }

    // MARK: - Refresh All Data

    /// Fetches all health metrics for today in parallel
    func refreshAll() async {
        async let steps = fetchTodaySteps()
        async let calories = fetchTodayActiveCalories()
        async let heartRate = fetchLatestHeartRate()
        async let hrv = fetchLatestHRV()
        async let sleep = fetchTodaySleepHours()
        async let mindful = fetchTodayMindfulMinutes()

        let results = await (steps, calories, heartRate, hrv, sleep, mindful)
        todaySteps = results.0
        todayActiveCalories = results.1
        latestHeartRate = results.2
        latestHRV = results.3
        todaySleepHours = results.4
        todayMindfulMinutes = results.5
    }

    // MARK: - Steps

    func fetchTodaySteps() async -> Double {
        await fetchTodayCumulativeSum(for: stepType, unit: .count())
    }

    // MARK: - Active Calories

    func fetchTodayActiveCalories() async -> Double {
        await fetchTodayCumulativeSum(for: activeCaloriesType, unit: .kilocalorie())
    }

    // MARK: - Heart Rate (latest)

    func fetchLatestHeartRate() async -> Double {
        await fetchLatestQuantitySample(
            for: heartRateType,
            unit: HKUnit.count().unitDivided(by: .minute())
        )
    }

    // MARK: - HRV (latest)

    func fetchLatestHRV() async -> Double {
        await fetchLatestQuantitySample(for: hrvType, unit: .secondUnit(with: .milli))
    }

    // MARK: - Sleep (last night)

    func fetchTodaySleepHours() async -> Double {
        let calendar = Calendar.current
        let now = Date()
        // Look back from 8pm yesterday to now for last night's sleep
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        var startComponents = calendar.dateComponents([.year, .month, .day], from: yesterday)
        startComponents.hour = 20
        let startDate = calendar.date(from: startComponents) ?? calendar.startOfDay(for: yesterday)

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: .strictStartDate
        )

        do {
            let samples = try await fetchCategorySamples(for: sleepType, predicate: predicate)
            // Only count asleep states (not inBed)
            let asleepSamples = samples.filter { sample in
                let value = sample.value
                // HKCategoryValueSleepAnalysis: asleepUnspecified = 1, asleepCore = 3, asleepDeep = 4, asleepREM = 5
                return value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                    || value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
                    || value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                    || value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
            }

            let totalSeconds = asleepSamples.reduce(0.0) { total, sample in
                total + sample.endDate.timeIntervalSince(sample.startDate)
            }
            return totalSeconds / 3600.0 // Convert to hours
        } catch {
            return 0
        }
    }

    // MARK: - Mindful Minutes

    func fetchTodayMindfulMinutes() async -> Double {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: Date(),
            options: .strictStartDate
        )

        do {
            let samples = try await fetchCategorySamples(for: mindfulType, predicate: predicate)
            let totalSeconds = samples.reduce(0.0) { total, sample in
                total + sample.endDate.timeIntervalSince(sample.startDate)
            }
            return totalSeconds / 60.0 // Convert to minutes
        } catch {
            return 0
        }
    }

    // MARK: - Log Mood (as mindful session with metadata)

    /// Logs mood as a mindful session with mood level in metadata.
    /// Mood levels: 1 = terrible, 2 = bad, 3 = okay, 4 = good, 5 = great
    func logMood(_ level: Int, note: String? = nil) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthServiceError.healthDataUnavailable
        }

        let clampedLevel = max(1, min(5, level))
        let now = Date()
        // Create a 1-minute mindful session to record the mood entry
        let startDate = now.addingTimeInterval(-60)

        let sample = HKCategorySample(
            type: mindfulType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: startDate,
            end: now,
            metadata: [
                "MissMmoodLevel": clampedLevel,
                "MissMmoodNote": note ?? "",
                HKMetadataKeyWasUserEntered: true
            ]
        )

        try await store.save(sample)
    }

    // MARK: - Private Helpers

    /// Fetches cumulative sum for a quantity type from start of today
    private func fetchTodayCumulativeSum(for quantityType: HKQuantityType, unit: HKUnit) async -> Double {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: Date(),
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    /// Fetches the most recent sample for a quantity type
    private func fetchLatestQuantitySample(for quantityType: HKQuantityType, unit: HKUnit) async -> Double {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: 0)
                    return
                }
                let value = sample.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    /// Fetches category samples matching a predicate
    private func fetchCategorySamples(
        for categoryType: HKCategoryType,
        predicate: NSPredicate
    ) async throws -> [HKCategorySample] {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: categoryType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let categorySamples = (samples as? [HKCategorySample]) ?? []
                continuation.resume(returning: categorySamples)
            }
            store.execute(query)
        }
    }

    // MARK: - Formatted Summaries

    /// Returns a text summary of today's wellness data for Claude briefings
    func wellnessSummary() async -> String {
        await refreshAll()

        var lines: [String] = []
        lines.append("Steps: \(Int(todaySteps)) / 10,000")
        lines.append("Active calories: \(Int(todayActiveCalories)) kcal")

        if latestHeartRate > 0 {
            lines.append("Heart rate: \(Int(latestHeartRate)) bpm")
        }
        if latestHRV > 0 {
            lines.append("HRV: \(Int(latestHRV)) ms")
        }
        if todaySleepHours > 0 {
            let hours = Int(todaySleepHours)
            let minutes = Int((todaySleepHours - Double(hours)) * 60)
            lines.append("Sleep: \(hours)h \(minutes)m")
        }
        if todayMindfulMinutes > 0 {
            lines.append("Mindful: \(Int(todayMindfulMinutes)) min")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Cycle Tracking (Phase 6)

    /// Fetch recent menstrual flow data and estimate current cycle day/phase
    func fetchCycleData() async {
        let calendar = Calendar.current
        let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: Date())!

        let predicate = HKQuery.predicateForSamples(
            withStart: threeMonthsAgo,
            end: Date(),
            options: .strictStartDate
        )

        do {
            let samples = try await fetchCategorySamples(for: menstrualFlowType, predicate: predicate)

            // Find the most recent period start (flow value > 0, preceded by no-flow)
            let flowDays = samples.filter { $0.value != HKCategoryValueMenstrualFlow.none.rawValue }
                .sorted { $0.startDate > $1.startDate }

            if let lastFlow = flowDays.first {
                // Walk back to find the start of the most recent period
                var periodStart = lastFlow.startDate
                for sample in flowDays {
                    if calendar.isDate(sample.startDate, equalTo: periodStart, toGranularity: .day) ||
                       calendar.dateComponents([.day], from: sample.startDate, to: periodStart).day ?? 99 <= 1 {
                        periodStart = sample.startDate
                    }
                }

                lastPeriodStart = periodStart
                let daysSincePeriod = calendar.dateComponents([.day], from: periodStart, to: Date()).day ?? 0
                currentCycleDay = daysSincePeriod + 1

                // Estimate phase (28-day cycle)
                if daysSincePeriod <= 5 {
                    currentPhase = .menstrual
                } else if daysSincePeriod <= 13 {
                    currentPhase = .follicular
                } else if daysSincePeriod <= 16 {
                    currentPhase = .ovulation
                } else if daysSincePeriod <= 28 {
                    currentPhase = .luteal
                } else {
                    currentPhase = .unknown
                }
            }
        } catch {
            currentPhase = .unknown
        }
    }

    /// Log menstrual flow
    func logMenstrualFlow(_ flowLevel: Int) async throws {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)

        let sample = HKCategorySample(
            type: menstrualFlowType,
            value: flowLevel,
            start: startOfDay,
            end: now,
            metadata: [HKMetadataKeyWasUserEntered: true]
        )

        try await store.save(sample)
    }

    // MARK: - Error Types

    enum HealthServiceError: Error, LocalizedError {
        case healthDataUnavailable
        case notAuthorized
        case queryFailed(String)
        case saveFailed(String)

        var errorDescription: String? {
            switch self {
            case .healthDataUnavailable:
                return "Health data is not available on this device."
            case .notAuthorized:
                return "Health data access not granted. Please allow in System Settings → Privacy → Health."
            case .queryFailed(let detail):
                return "Failed to read health data: \(detail)"
            case .saveFailed(let detail):
                return "Failed to save health data: \(detail)"
            }
        }
    }
}

// MARK: - Mood Level Model

enum MoodLevel: Int, CaseIterable, Identifiable {
    case terrible = 1
    case bad = 2
    case okay = 3
    case good = 4
    case great = 5

    var id: Int { rawValue }

    var emoji: String {
        switch self {
        case .terrible: return "😫"
        case .bad:      return "😔"
        case .okay:     return "😐"
        case .good:     return "😊"
        case .great:    return "🤩"
        }
    }

    var label: String {
        switch self {
        case .terrible: return "Terrible"
        case .bad:      return "Bad"
        case .okay:     return "Okay"
        case .good:     return "Good"
        case .great:    return "Great"
        }
    }

    var color: some ShapeStyle {
        switch self {
        case .terrible: return Color(hex: "#E53935")
        case .bad:      return Color(hex: "#FF7043")
        case .okay:     return Color(hex: "#FFA726")
        case .good:     return Color(hex: "#66BB6A")
        case .great:    return Color(hex: "#E91E8C")
        }
    }
}

// MARK: - Cycle Phase Model (Phase 6)

enum CyclePhase: String, CaseIterable {
    case menstrual = "Menstrual"
    case follicular = "Follicular"
    case ovulation = "Ovulation"
    case luteal = "Luteal"
    case unknown = "Unknown"

    var icon: String {
        switch self {
        case .menstrual: return "🩸"
        case .follicular: return "🌱"
        case .ovulation: return "🌸"
        case .luteal: return "🌙"
        case .unknown: return "❓"
        }
    }

    var color: Color {
        switch self {
        case .menstrual: return Color(hex: "#FF3B30")
        case .follicular: return Color(hex: "#34C759")
        case .ovulation: return Color(hex: "#FF9500")
        case .luteal: return Color(hex: "#AF52DE")
        case .unknown: return Color(hex: "#8E8E93")
        }
    }

    var energyLevel: String {
        switch self {
        case .menstrual: return "Rest & recover"
        case .follicular: return "Rising energy"
        case .ovulation: return "Peak energy"
        case .luteal: return "Winding down"
        case .unknown: return "Track to learn"
        }
    }
}
