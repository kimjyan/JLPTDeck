import Foundation

/// Pure SM-2 scheduling function.
///
/// Rules:
/// - Ease factor update: `ef' = ef + (0.1 - (5-q) * (0.08 + (5-q) * 0.02))`, floored at 1.3.
/// - If quality < 3 (we only expose `.again` here): reset reps to 0, interval to 1,
///   increment lapses. Ease still updates.
/// - If quality >= 3: reps += 1
///   - reps == 1 -> interval = 1
///   - reps == 2 -> interval = 6
///   - reps  > 2 -> interval = round(previousInterval * ef')
/// - dueDate = now + intervalDays * 86400
public enum SM2 {
    private static let secondsPerDay: TimeInterval = 86_400
    private static let minEase: Double = 1.3

    public static func nextState(
        current: SRSSnapshot,
        quality: SRSQuality,
        now: Date
    ) -> SRSUpdate {
        let q = Double(quality.rawValue)

        // Ease factor update (standard SM-2 formula, floored at 1.3).
        let delta = 0.1 - (5.0 - q) * (0.08 + (5.0 - q) * 0.02)
        let newEase = max(minEase, current.ease + delta)

        let newReps: Int
        let newInterval: Int
        let newLapses: Int

        if quality.rawValue < 3 {
            // Lapse: reset progress.
            newReps = 0
            newInterval = 1
            newLapses = current.lapses + 1
        } else {
            let incrementedReps = current.reps + 1
            newReps = incrementedReps
            switch incrementedReps {
            case 1:
                newInterval = 1
            case 2:
                newInterval = 6
            default:
                newInterval = Int((Double(current.intervalDays) * newEase).rounded())
            }
            newLapses = current.lapses
        }

        let dueDate = now.addingTimeInterval(TimeInterval(newInterval) * secondsPerDay)

        return SRSUpdate(
            ease: newEase,
            intervalDays: newInterval,
            reps: newReps,
            dueDate: dueDate,
            lapses: newLapses
        )
    }
}
