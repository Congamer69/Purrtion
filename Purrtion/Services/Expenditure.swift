import Foundation

/// The "real" daily energy expenditure, measured from what was eaten and how the weight changed –
/// independent of formulas and fitness trackers.
///
/// Energy balance: expenditure = intake − (energy stored in the body per day).
/// 1. Weight trend: robust (Huber-weighted) linear regression over the daily mean weights of the window,
///    so single salty or post-workout weigh-ins barely move it. Gives kg/day plus its standard error.
/// 2. Energy density of the weight change follows the Forbes / Hall model: the leaner you are, the more
///    of the change is lean tissue (≈1,800 kcal/kg) instead of fat (≈9,400 kcal/kg). Body fat is estimated
///    from BMI, age and sex (Deurenberg).
/// 3. Intake: mean of fully logged days; days without entries count with that mean (weight still covers them).
/// 4. The measured value is combined with a prior (Apple Health resting + active energy or Mifflin-St Jeor ×
///    activity factor) by inverse-variance weighting – with little data the estimate leans on the prior,
///    with a clean month of data almost entirely on the measurement.
/// 5. Split: resting energy (Apple Health or Mifflin-St Jeor at the trend weight), thermic effect of food
///    (≈10 % of intake) and movement = the rest. Comparing the rest with the active energy from Apple Health
///    gives a calibration factor for the tracker.
struct ExpenditureEstimate {
    enum Confidence { case low, medium, high
        var label: String { self == .high ? "hoch" : self == .medium ? "mittel" : "niedrig" }
    }

    /// Estimated total daily energy expenditure.
    var total: Double
    /// Resting energy (basal metabolic rate).
    var basal: Double
    var basalFromHealth: Bool
    /// Thermic effect of food.
    var digestion: Double
    /// Everything that is movement: training, steps, everyday activity.
    var movement: Double
    /// Mean active energy measured by Apple Health (+ manual) in the window, 0 when unknown.
    var trackedActive: Double
    /// movement / trackedActive – how much of the tracker's number is real (nil without tracker data).
    var trackerFactor: Double? {
        trackedActive > 50 ? movement / trackedActive : nil
    }

    /// Value from energy balance alone (nil when the data is too thin to measure anything).
    var measured: Double?
    /// The formula / Health estimate the measurement is combined with.
    var prior: Double
    /// Share of the measurement in the result (0…1).
    var measuredWeight: Double
    /// 1 σ uncertainty in kcal.
    var uncertainty: Double

    var intake: Double
    /// kg per week (negative = losing).
    var weightPerWeek: Double?
    var trendWeight: Double?
    var energyDensity: Double

    var windowDays: Int
    var loggedDays: Int
    var weighIns: Int
    /// Data still missing for a measured value – empty when ready.
    var missing: [String]

    var isMeasured: Bool { measured != nil }

    var confidence: Confidence {
        guard isMeasured else { return .low }
        return uncertainty < 120 ? .high : uncertainty < 220 ? .medium : .low
    }
}

enum Expenditure {
    static let window = 28
    static let minLoggedDays = 10
    static let minWeighIns = 3
    static let minWeightSpan = 10

    struct DayIntake { let day: Date; let kcal: Double; let active: Double; let basal: Double }

    /// - Parameters:
    ///   - intakeByDay: kcal eaten per day (only days with entries)
    ///   - weights: all weigh-ins
    static func estimate(intakeByDay: [Date: Double], weights: [(date: Date, kg: Double)], goals: Goals,
                         activityEnabled: Bool, today: Date = .now) -> ExpenditureEstimate {
        let cal = Calendar.current
        let end = cal.startOfDay(for: today)                                   // today is not finished → excluded
        // Use up to 8 weeks if the last 4 weeks have too few weigh-ins.
        var days = window
        func weighInsSince(_ start: Date) -> Int { weights.filter { $0.date >= start && $0.date < end }.count }
        while days < 56, weighInsSince(cal.date(byAdding: .day, value: -days, to: end)!) < 4 { days += 7 }
        let start = cal.date(byAdding: .day, value: -days, to: end)!

        // Weight: one mean value per day.
        var perDay: [Date: [Double]] = [:]
        for w in weights where w.date >= start && w.date < end {
            perDay[cal.startOfDay(for: w.date), default: []].append(w.kg)
        }
        let points = perDay.map { (x: $0.key.timeIntervalSince(start) / 86400, y: $0.value.reduce(0, +) / Double($0.value.count)) }
            .sorted { $0.x < $1.x }
        let latestWeight = weights.max(by: { $0.date < $1.date })?.kg ?? goals.weightKG

        // Intake + tracker data per day of the window.
        let formulaBasal = mifflin(weight: latestWeight, goals: goals)
        var intakes: [Double] = []
        var actives: [Double] = []
        var basals: [Double] = []
        for i in 0..<days {
            let d = cal.date(byAdding: .day, value: i, to: start)!
            let active = (activityEnabled ? ActivityStore.kcal(for: d) : 0) + ActivityStore.manual(for: d)
            actives.append(active)
            let b = activityEnabled ? ActivityStore.basal(for: d) : 0
            if b > 0 { basals.append(b) }
            // Days far below the resting energy are almost always only partly logged.
            if let k = intakeByDay[d], k >= formulaBasal * 0.45 { intakes.append(k) }
        }
        let intake = intakes.isEmpty ? 0 : intakes.reduce(0, +) / Double(intakes.count)
        let trackedActive = actives.reduce(0, +) / Double(max(actives.count, 1))
        let healthBasal = basals.count >= days / 2 ? basals.reduce(0, +) / Double(basals.count) : nil

        // Prior: Health resting + active energy + digestion, else Mifflin × activity factor.
        let prior: Double
        let priorSD: Double
        if let hb = healthBasal, trackedActive > 0 {
            prior = hb + trackedActive + 0.1 * (intake > 0 ? intake : hb * 1.4)
            priorSD = 260
        } else {
            prior = formulaBasal * goals.activity.factor
            priorSD = 330
        }

        // Weight trend.
        let fit = points.count >= 2 ? robustSlope(points) : nil
        let span = (points.last?.x ?? 0) - (points.first?.x ?? 0)
        let trendWeight = fit.map { $0.intercept + $0.slope * Double(days - 1) } ?? latestWeight
        let rho = energyDensity(weight: trendWeight, goals: goals)

        var missing: [String] = []
        if intakes.count < minLoggedDays { missing.append("\(minLoggedDays - intakes.count) weitere Tage vollständig eintragen") }
        if points.count < minWeighIns { missing.append("\(minWeighIns - points.count) weitere Wiegungen") }
        else if span < Double(minWeightSpan) { missing.append("Wiegungen über mind. \(minWeightSpan) Tage verteilt") }

        var measured: Double?
        var result = prior
        var sd = priorSD
        var weight = 0.0
        if missing.isEmpty, let fit {
            let stored = fit.slope * rho                                          // kcal per day put into / taken from the body
            let m = intake - stored
            // Uncertainty of the measurement: weight trend + day-to-day intake noise + unlogged days.
            let intakeSD = standardDeviation(intakes) / sqrt(Double(intakes.count))
            let coverage = Double(intakes.count) / Double(days)
            let missingDaysSD = intake * 0.12 * (1 - coverage)                    // unlogged days are assumed average
            let loggingSD = intake * 0.05                                          // typical under-reporting of careful loggers
            let mSD = sqrt(pow(fit.slopeSE * rho, 2) + pow(intakeSD, 2) + pow(missingDaysSD, 2) + pow(loggingSD, 2))
            // Implausible measurements (e.g. a crash diet start with lots of water) fall back on the prior.
            if m > 900, m < 6000 {
                measured = m
                let wm = 1 / (mSD * mSD), wp = 1 / (priorSD * priorSD)
                result = (m * wm + prior * wp) / (wm + wp)
                sd = sqrt(1 / (wm + wp))
                weight = wm / (wm + wp)
            }
        }

        // Split into resting, digestion and movement.
        let basal = healthBasal ?? mifflin(weight: trendWeight, goals: goals)
        let digestion = 0.1 * (intake > 0 ? intake : result * 0.9)
        var movement = result - basal - digestion
        var shownBasal = basal
        if movement < 0 {                                                          // lower metabolism than the formula says
            shownBasal = max(0, result - digestion)
            movement = 0
        }
        return ExpenditureEstimate(total: result, basal: shownBasal, basalFromHealth: healthBasal != nil, digestion: digestion,
                                   movement: movement, trackedActive: trackedActive, measured: measured, prior: prior,
                                   measuredWeight: weight, uncertainty: sd, intake: intake,
                                   weightPerWeek: fit.map { $0.slope * 7 }, trendWeight: fit != nil ? trendWeight : nil,
                                   energyDensity: rho, windowDays: days, loggedDays: intakes.count, weighIns: points.count,
                                   missing: missing)
    }

    // MARK: Building blocks

    static func mifflin(weight: Double, goals: Goals) -> Double {
        10 * weight + 6.25 * goals.heightCM - 5 * Double(goals.age) + (goals.sex == .male ? 5 : -161)
    }

    /// kcal per kg of body weight change (Forbes partitioning, Hall energy contents).
    static func energyDensity(weight: Double, goals: Goals) -> Double {
        let h = goals.heightCM / 100
        let bmi = weight / max(h * h, 0.5)
        let bodyFat = min(max(1.2 * bmi + 0.23 * Double(goals.age) - 10.8 * (goals.sex == .male ? 1 : 0) - 5.4, 5), 55) / 100
        let fatMass = weight * bodyFat
        let fatShare = fatMass / (fatMass + 10.4)
        return fatShare * 9440 + (1 - fatShare) * 1816
    }

    struct Fit { let slope: Double; let intercept: Double; let slopeSE: Double }

    /// Linear regression with Huber weights (iteratively reweighted) – robust against water-weight outliers.
    static func robustSlope(_ pts: [(x: Double, y: Double)]) -> Fit? {
        guard pts.count >= 2 else { return nil }
        var w = Array(repeating: 1.0, count: pts.count)
        var fit = weightedFit(pts, w)
        for _ in 0..<4 {
            guard let f = fit else { return nil }
            let residuals = pts.map { $0.y - (f.intercept + f.slope * $0.x) }
            let mad = median(residuals.map(abs)) * 1.4826
            let k = 1.345 * max(mad, 0.25)                                          // never trust weights below ±0.25 kg
            w = residuals.map { abs($0) <= k ? 1 : k / abs($0) }
            fit = weightedFit(pts, w)
        }
        return fit
    }

    private static func weightedFit(_ pts: [(x: Double, y: Double)], _ w: [Double]) -> Fit? {
        let sw = w.reduce(0, +)
        let mx = zip(pts, w).reduce(0) { $0 + $1.0.x * $1.1 } / sw
        let my = zip(pts, w).reduce(0) { $0 + $1.0.y * $1.1 } / sw
        let sxx = zip(pts, w).reduce(0) { $0 + $1.1 * pow($1.0.x - mx, 2) }
        guard sxx > 0 else { return nil }
        let sxy = zip(pts, w).reduce(0) { $0 + $1.1 * ($1.0.x - mx) * ($1.0.y - my) }
        let slope = sxy / sxx
        let intercept = my - slope * mx
        let n = Double(pts.count)
        let sse = zip(pts, w).reduce(0) { $0 + $1.1 * pow($1.0.y - (intercept + slope * $1.0.x), 2) }
        // Day-to-day weight noise is at least ~0.4 kg, even if a few weigh-ins happen to line up.
        let sigma2 = max(n > 2 ? sse / (sw * (n - 2) / n) : 0.25, 0.16)
        return Fit(slope: slope, intercept: intercept, slopeSE: sqrt(sigma2 / sxx))
    }

    private static func median(_ v: [Double]) -> Double {
        guard !v.isEmpty else { return 0 }
        let s = v.sorted()
        return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
    }

    private static func standardDeviation(_ v: [Double]) -> Double {
        guard v.count > 1 else { return 400 }
        let m = v.reduce(0, +) / Double(v.count)
        return sqrt(v.reduce(0) { $0 + pow($1 - m, 2) } / Double(v.count - 1))
    }
}
