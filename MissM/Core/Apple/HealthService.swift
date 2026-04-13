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
