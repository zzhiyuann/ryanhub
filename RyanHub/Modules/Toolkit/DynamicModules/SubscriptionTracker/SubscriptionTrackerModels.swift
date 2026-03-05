import Foundation

struct SubscriptionTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var name: String = ""
    var amount: Double = 0.0
    var category: SubscriptionCategory = .other
    var billingCycle: BillingCycle = .monthly
    var renewalDay: Int = 1
    var isActive: Bool = true
    var notes: String = ""

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        guard let d = f.date(from: date) else { return date }
        let out = DateFormatter()
        out.dateStyle = .medium
        out.timeStyle = .none
        return out.string(from: d)
    }

    var summaryLine: String {
        "\(name) — \(billingCycle.displayName) $\(String(format: "%.2f", amount))"
    }

    var monthlyCost: Double {
        switch billingCycle {
        case .weekly:    return amount * 4.33
        case .monthly:   return amount
        case .quarterly: return amount / 3.0
        case .yearly:    return amount / 12.0
        }
    }

    var yearlyCost: Double {
        monthlyCost * 12.0
    }

    var dailyCost: Double {
        monthlyCost / 30.0
    }

    var formattedAmount: String {
        "$\(String(format: "%.2f", amount))"
    }

    var formattedMonthlyCost: String {
        "$\(String(format: "%.2f", monthlyCost))/mo"
    }

    var renewalDayOrdinal: String {
        let suffix: String
        switch renewalDay % 10 {
        case 1 where renewalDay != 11: suffix = "st"
        case 2 where renewalDay != 12: suffix = "nd"
        case 3 where renewalDay != 13: suffix = "rd"
        default: suffix = "th"
        }
        return "\(renewalDay)\(suffix)"
    }

    var daysUntilRenewal: Int {
        let calendar = Calendar.current
        let today = calendar.component(.day, from: Date())
        let daysInMonth = calendar.range(of: .day, in: .month, for: Date())?.count ?? 30
        if renewalDay >= today {
            return renewalDay - today
        } else {
            return (daysInMonth - today) + renewalDay
        }
    }

    var isRenewingSoon: Bool {
        isActive && daysUntilRenewal <= 7
    }

    var renewalLabel: String {
        guard isActive else { return "Inactive" }
        switch daysUntilRenewal {
        case 0:  return "Renews today"
        case 1:  return "Renews tomorrow"
        default: return "Renews in \(daysUntilRenewal) days"
        }
    }

    var statusLabel: String {
        isActive ? "Active" : "Inactive"
    }
}

enum SubscriptionCategory: String, CaseIterable, Codable, Identifiable {
    case entertainment
    case music
    case productivity
    case cloud
    case health
    case news
    case gaming
    case education
    case finance
    case utilities
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .entertainment: return "Entertainment"
        case .music:         return "Music"
        case .productivity:  return "Productivity"
        case .cloud:         return "Cloud & Storage"
        case .health:        return "Health & Fitness"
        case .news:          return "News & Reading"
        case .gaming:        return "Gaming"
        case .education:     return "Education"
        case .finance:       return "Finance"
        case .utilities:     return "Utilities"
        case .other:         return "Other"
        }
    }

    var icon: String {
        switch self {
        case .entertainment: return "tv"
        case .music:         return "music.note"
        case .productivity:  return "hammer"
        case .cloud:         return "cloud"
        case .health:        return "heart"
        case .news:          return "newspaper"
        case .gaming:        return "gamecontroller"
        case .education:     return "graduationcap"
        case .finance:       return "dollarsign.circle"
        case .utilities:     return "wrench.and.screwdriver"
        case .other:         return "ellipsis.circle"
        }
    }

    var chartColor: String {
        switch self {
        case .entertainment: return "hubPrimary"
        case .music:         return "hubAccentGreen"
        case .productivity:  return "hubAccentYellow"
        case .cloud:         return "hubPrimaryLight"
        case .health:        return "hubAccentRed"
        case .news:          return "gray"
        case .gaming:        return "purple"
        case .education:     return "teal"
        case .finance:       return "orange"
        case .utilities:     return "brown"
        case .other:         return "secondary"
        }
    }
}

enum BillingCycle: String, CaseIterable, Codable, Identifiable {
    case weekly
    case monthly
    case quarterly
    case yearly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weekly:    return "Weekly"
        case .monthly:   return "Monthly"
        case .quarterly: return "Quarterly"
        case .yearly:    return "Yearly"
        }
    }

    var icon: String {
        switch self {
        case .weekly:    return "calendar.badge.clock"
        case .monthly:   return "calendar"
        case .quarterly: return "calendar.badge.3"
        case .yearly:    return "calendar.circle"
        }
    }

    var shortLabel: String {
        switch self {
        case .weekly:    return "wk"
        case .monthly:   return "mo"
        case .quarterly: return "qtr"
        case .yearly:    return "yr"
        }
    }
}

struct SubscriptionCategoryGroup: Identifiable {
    let id: String
    let category: SubscriptionCategory
    let entries: [SubscriptionTrackerEntry]

    var totalMonthlyCost: Double {
        entries.filter { $0.isActive }.reduce(0) { $0 + $1.monthlyCost }
    }
}