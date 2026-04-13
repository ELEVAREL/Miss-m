import HealthKit
import Foundation

// MARK: - Health Service
// Phase 6: HealthKit integration — steps, sleep, heart rate, HRV, calories, cycle tracking

@Observable
class HealthService {
    static let shared = HealthService()

    private let store = HKHealthStore()
    var isAuthorized = false

    private init() {}

    // MARK: - Authorization

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAccess() async -> Bool {
        guard isAvailable else { return false }

        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.heartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.appleStandTime),
            HKCategoryType(.sleepAnalysis),
            HKCategoryType(.mindfulSession),
            HKQuantityType(.dietaryWater),
            // Menstrual cycle (reads Flo data synced via HealthKit)
            HKCategoryType(.menstrualFlow),
            HKCategoryType(.ovulationTestResult),
            HKCategoryType(.cervicalMucusQuality),
            HKCategoryType(.intermenstrualBleeding),
        ]

        let writeTypes: Set<HKSampleType> = [
            HKCategoryType(.mindfulSession),
        ]

        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            isAuthorized = true
            return true
        } catch {
            return false
        }
    }

    // MARK: - Steps

    func stepsToday() async -> Int {
        Int(await sumQuantityToday(.stepCount, unit: .count()))
    }

    // MARK: - Heart Rate

    func latestHeartRate() async -> Double {
        await latestQuantity(.heartRate, unit: HKUnit.count().unitDivided(by: .minute()))
    }

    // MARK: - HRV

    func latestHRV() async -> Double {
        await latestQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli))
    }

    // MARK: - Calories

    func caloriesToday() async -> Int {
        Int(await sumQuantityToday(.activeEnergyBurned, unit: .kilocalorie()))
    }

    // MARK: - Exercise Minutes

    func exerciseMinutesToday() async -> Int {
        Int(await sumQuantityToday(.appleExerciseTime, unit: .minute()))
    }

    // MARK: - Stand Hours

    func standHoursToday() async -> Int {
        Int(await sumQuantityToday(.appleStandTime, unit: .minute()) / 60)
    }

    // MARK: - Sleep Hours (last night)

    func sleepHoursLastNight() async -> Double {
        let calendar = Calendar.current
        let now = Date()
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) else { return 0 }

        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: now, options: .strictStartDate)
        let sleepType = HKCategoryType(.sleepAnalysis)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let totalSeconds = (samples as? [HKCategorySample])?.reduce(0.0) { total, sample in
                    if sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                       sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                       sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                       sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                        return total + sample.endDate.timeIntervalSince(sample.startDate)
                    }
                    return total
                } ?? 0
                continuation.resume(returning: totalSeconds / 3600)
            }
            store.execute(query)
        }
    }

    // MARK: - Mindful Minutes

    func mindfulMinutesToday() async -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let type = HKCategoryType(.mindfulSession)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let totalMinutes = (samples as? [HKCategorySample])?.reduce(0.0) { total, sample in
                    total + sample.endDate.timeIntervalSince(sample.startDate) / 60
                } ?? 0
                continuation.resume(returning: Int(totalMinutes))
            }
            self.store.execute(query)
        }
    }

    // MARK: - Water (ml)

    func waterToday() async -> Int {
        Int(await sumQuantityToday(.dietaryWater, unit: .literUnit(with: .milli)))
    }

    // MARK: - Heart Rate Samples (for trend chart)

    func heartRateSamplesToday() async -> [(Date, Double)] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let hrType = HKQuantityType(.heartRate)
        let unit = HKUnit.count().unitDivided(by: .minute())

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: hrType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, _ in
                let points = (samples as? [HKQuantitySample])?.map { sample in
                    (sample.startDate, sample.quantity.doubleValue(for: unit))
                } ?? []
                continuation.resume(returning: points)
            }
            store.execute(query)
        }
    }

    // MARK: - Sleep Data for Week

    func sleepDataForWeek() async -> [Double] {
        var result: [Double] = []
        let calendar = Calendar.current
        for dayOffset in (0..<7).reversed() {
            guard let dayStart = calendar.date(byAdding: .day, value: -dayOffset, to: calendar.startOfDay(for: Date())),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                result.append(0)
                continue
            }
            let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictStartDate)
            let sleepType = HKCategoryType(.sleepAnalysis)

            let hours: Double = await withCheckedContinuation { continuation in
                let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                    let totalSeconds = (samples as? [HKCategorySample])?.reduce(0.0) { total, sample in
                        if sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                           sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                           sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                           sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                            return total + sample.endDate.timeIntervalSince(sample.startDate)
                        }
                        return total
                    } ?? 0
                    continuation.resume(returning: totalSeconds / 3600)
                }
                store.execute(query)
            }
            result.append(hours)
        }
        return result
    }

    // MARK: - Menstrual Cycle (Flo Bridge via HealthKit)

    /// Returns the most recent menstrual flow start date from HealthKit
    /// Flo syncs this data when "Connect to Health app" is enabled
    func lastMenstrualFlowStart() async -> Date? {
        let type = HKCategoryType(.menstrualFlow)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 50, sortDescriptors: [sort]) { _, samples, _ in
                guard let categorySamples = samples as? [HKCategorySample], !categorySamples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                // Find the start of the most recent period (first sample in a cluster)
                var periodStart = categorySamples[0].startDate
                for i in 1..<categorySamples.count {
                    let gap = categorySamples[i-1].startDate.timeIntervalSince(categorySamples[i].startDate)
                    if gap < 3 * 24 * 3600 { // same period cluster (within 3 days)
                        periodStart = categorySamples[i].startDate
                    } else {
                        break
                    }
                }
                continuation.resume(returning: periodStart)
            }
            store.execute(query)
        }
    }

    /// Returns menstrual flow entries for the past N months
    func menstrualFlowHistory(months: Int = 6) async -> [(date: Date, flow: Int)] {
        let type = HKCategoryType(.menstrualFlow)
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .month, value: -months, to: Date()) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                let entries = (samples as? [HKCategorySample])?.map { sample in
                    (date: sample.startDate, flow: sample.value)
                } ?? []
                continuation.resume(returning: entries)
            }
            store.execute(query)
        }
    }

    /// Estimates cycle length from HealthKit menstrual flow data
    func estimatedCycleLength() async -> Int? {
        let history = await menstrualFlowHistory(months: 6)
        guard !history.isEmpty else { return nil }

        // Find period start dates (gaps of 10+ days between flow entries indicate new cycles)
        var periodStarts: [Date] = []
        var lastDate: Date?
        for entry in history {
            if let last = lastDate {
                let gap = entry.date.timeIntervalSince(last) / (24 * 3600)
                if gap > 10 {
                    periodStarts.append(entry.date)
                }
            } else {
                periodStarts.append(entry.date)
            }
            lastDate = entry.date
        }

        guard periodStarts.count >= 2 else { return nil }

        // Average cycle length from consecutive period starts
        var totalDays = 0
        for i in 1..<periodStarts.count {
            totalDays += Int(periodStarts[i].timeIntervalSince(periodStarts[i-1]) / (24 * 3600))
        }
        return totalDays / (periodStarts.count - 1)
    }

    /// Calculates current cycle day based on last period start from HealthKit
    func currentCycleDay() async -> Int? {
        guard let lastStart = await lastMenstrualFlowStart() else { return nil }
        let days = Calendar.current.dateComponents([.day], from: lastStart, to: Date()).day ?? 0
        return max(1, days + 1)
    }

    // MARK: - Helpers

    private func sumQuantityToday(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let type = HKQuantityType(identifier)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                let value = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func latestQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        let type = HKQuantityType(identifier)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
}
