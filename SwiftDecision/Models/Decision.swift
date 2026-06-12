import Foundation
import SwiftData

@Model
final class Decision {
    var question: String
    var verdict: String
    var reason: String
    var detail: String
    var isTrivial: Bool
    var createdAt: Date
    /// 0 = 未回访, 1 = 结果还行, -1 = 结果不好
    var feedback: Int

    init(question: String, verdict: String, reason: String, detail: String, isTrivial: Bool) {
        self.question = question
        self.verdict = verdict
        self.reason = reason
        self.detail = detail
        self.isTrivial = isTrivial
        self.createdAt = .now
        self.feedback = 0
    }
}
