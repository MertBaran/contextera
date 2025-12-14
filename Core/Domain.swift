import Foundation

enum NodeKind: String, Codable {
    case file
    case folder
}

enum AppView: String, CaseIterable, Identifiable, Codable {
    case tree = "Tree"
    case table = "Table"
    case graph = "Graph"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .tree: return "list.bullet.indent"
        case .table: return "tablecells"
        case .graph: return "circle.grid.2x2"
        }
    }
}

struct FileNode: Identifiable, Hashable {
    let id: String
    let url: URL
    let kind: NodeKind
    let name: String
    let path: String
    let modifiedAt: Date?
    let sizeBytes: Int64?
}
