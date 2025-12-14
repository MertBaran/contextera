import SwiftUI

struct ContentView: View {
    @StateObject private var model: AppModel

    init(model: AppModel = AppModel()) {
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        NavigationSplitView {
            Sidebar(rootURL: $model.rootURL, selectionURL: $model.selectionURL, currentView: $model.currentView) {
                pickRootFolder()
            }
            .navigationTitle("Contextera")
        } detail: {
            Detail(
                selectionURL: model.selectionURL,
                rootURL: model.rootURL,
                currentView: model.currentView,
                nodes: model.nodes,
                isIndexing: model.isIndexing,
                lastIndexError: model.lastIndexError
            ) {
                Task { await model.refreshIndex() }
            }
        }
    }

    private func pickRootFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose a folder to index"
        panel.message = "Contextera needs access to a folder to start building context."
        panel.prompt = "Choose"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            // In a sandboxed app, you will later replace this with security-scoped bookmarks.
            // For now we store the URL in memory and show it in the UI.
            model.setRoot(url)
        } else {
            // User cancelled; no-op.
        }
    }
}

private struct Sidebar: View {
    @Binding var rootURL: URL?
    @Binding var selectionURL: URL?
    @Binding var currentView: AppView
    let onPickRoot: () -> Void

    var body: some View {
        List(selection: $selectionURL) {
            Section("Workspace") {
                Button {
                    onPickRoot()
                } label: {
                    Label("Choose Root Folder", systemImage: "folder")
                }

                if let rootURL {
                    HStack(spacing: 8) {
                        Image(systemName: "externaldrive")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rootURL.lastPathComponent)
                                .font(.headline)
                            Text(rootURL.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 6)
                    .tag(rootURL as URL?)
                } else {
                    Text("No folder selected")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Views") {
                ForEach(AppView.allCases) { view in
                    Button {
                        currentView = view
                    } label: {
                        Label(view.rawValue, systemImage: view.systemImage)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 2)
                    .opacity(rootURL == nil ? 0.4 : 1.0)
                    .disabled(rootURL == nil)
                }
            }
        }
        .listStyle(.sidebar)
        .onChange(of: rootURL) { _, newValue in
            // Keep selection in sync on first pick
            if selectionURL == nil {
                selectionURL = newValue
            }
        }
    }
}

private struct Detail: View {
    let selectionURL: URL?
    let rootURL: URL?
    let currentView: AppView
    let nodes: [FileNode]
    let isIndexing: Bool
    let lastIndexError: String?
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let rootURL {
                Text("Selected Root")
                    .font(.title2)
                Text(rootURL.path)
                    .font(.body)
                    .textSelection(.enabled)

                Divider()

                HStack(spacing: 10) {
                    Text(currentView.rawValue)
                        .font(.headline)

                    Spacer()

                    if isIndexing {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Button {
                        onRefresh()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(rootURL.path.isEmpty)
                }

                if let lastIndexError {
                    Text(lastIndexError)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }

                switch currentView {
                case .tree:
                    Text("Tree view next: we’ll build a hierarchical model and render it with OutlineGroup.")
                        .foregroundStyle(.secondary)

                case .graph:
                    Text("Graph view next: we’ll render relationships once Edge storage exists.")
                        .foregroundStyle(.secondary)

                case .table:
                    Table(nodes) {
                        TableColumn("Type") { node in
                            Image(systemName: node.kind == .folder ? "folder" : "doc")
                        }
                        .width(40)

                        TableColumn("Name", value: \.name)

                        TableColumn("Modified") { node in
                            if let d = node.modifiedAt {
                                Text(d, style: .date)
                            } else {
                                Text("—")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .width(120)

                        TableColumn("Size") { node in
                            if let s = node.sizeBytes, node.kind == .file {
                                Text(ByteCountFormatter.string(fromByteCount: s, countStyle: .file))
                            } else {
                                Text("—")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .width(90)

                        TableColumn("Path") { node in
                            Text(node.path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("Choose a folder", systemImage: "folder")
                } description: {
                    Text("Pick a root folder to start building your contextual filesystem.")
                } actions: {
                    Text("Use the sidebar button: Choose Root Folder")
                }
            }
        }
        .padding(24)
    }
}


#if DEBUG
#Preview {
    let mock: AppModel = {
        let model = AppModel(scanner: PreviewMockFolderScanner())
        model.rootURL = URL(fileURLWithPath: "/Users/example")
        return model
    }()

    return ContentView(model: mock)
}

private struct PreviewMockFolderScanner: FolderScanning {
    func scan(root: URL) throws -> [FileNode] {
        [
            FileNode(id: root.path, url: root, kind: .folder, name: root.lastPathComponent, path: root.path, modifiedAt: Date(), sizeBytes: nil),
            FileNode(id: root.appendingPathComponent("Docs").path, url: root.appendingPathComponent("Docs"), kind: .folder, name: "Docs", path: root.appendingPathComponent("Docs").path, modifiedAt: Date(), sizeBytes: nil),
            FileNode(id: root.appendingPathComponent("Notes.md").path, url: root.appendingPathComponent("Notes.md"), kind: .file, name: "Notes.md", path: root.appendingPathComponent("Notes.md").path, modifiedAt: Date(), sizeBytes: 12_345),
            FileNode(id: root.appendingPathComponent("Design.pdf").path, url: root.appendingPathComponent("Design.pdf"), kind: .file, name: "Design.pdf", path: root.appendingPathComponent("Design.pdf").path, modifiedAt: Date(), sizeBytes: 987_654)
        ]
    }
}
#endif
