import Foundation
import SwiftUI

final class AppModel: ObservableObject {
    @Published var rootURL: URL? {
        didSet {
            guard oldValue != rootURL else { return }
            Task { await refreshIndex() }
        }
    }

    @Published var selectionURL: URL?
    @Published var currentView: AppView = .table
    @Published private(set) var nodes: [FileNode] = []
    @Published private(set) var isIndexing: Bool = false
    @Published private(set) var lastIndexError: String?

    private let scanner: any FolderScanning

    init(scanner: FolderScanning = DefaultFolderScanner()) {
        self.scanner = scanner
    }

    func setRoot(_ url: URL) {
        rootURL = url
        selectionURL = url
    }

    @MainActor
    func refreshIndex() async {
        guard let rootURL else {
            nodes = []
            return
        }

        isIndexing = true
        lastIndexError = nil

        do {
            let scanner = self.scanner
            let rootURL = rootURL

            let scanned = try await Task.detached(priority: .userInitiated) {
                try scanner.scan(root: rootURL)
            }.value

            var allNodes = scanned

            // root node is always present
            if !allNodes.contains(where: { $0.path == rootURL.path }) {
                allNodes.insert(
                    FileNode(
                        id: rootURL.path,
                        url: rootURL,
                        kind: .folder,
                        name: rootURL.lastPathComponent,
                        path: rootURL.path,
                        modifiedAt: nil,
                        sizeBytes: nil
                    ),
                    at: 0
                )
            }

            let rootPath = rootURL.path

            nodes = allNodes.sorted {
                // Root always first
                if $0.path == rootPath { return true }
                if $1.path == rootPath { return false }

                // Folders before files
                if $0.kind != $1.kind { return $0.kind == .folder }

                // Same type -> path order
                return $0.path.localizedStandardCompare($1.path) == .orderedAscending
            }
        } catch {
            lastIndexError = String(describing: error)
            nodes = []
        }

        isIndexing = false
    }
}
