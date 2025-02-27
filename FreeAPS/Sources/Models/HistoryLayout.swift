import Foundation

enum HistoryLayout: String, JSON, CaseIterable, Identifiable, Codable {
    var id: String { rawValue }
    case twoTabs
    case threeTabs

    var displayName: String {
        switch self {
        case .twoTabs:
            return NSLocalizedString("2 Tabs", comment: "2 tabbladen")
        case .threeTabs:
            return NSLocalizedString("3 Tabs", comment: "3 tabbladen")
        }
    }
}
