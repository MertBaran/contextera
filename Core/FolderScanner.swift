import Foundation

protocol FolderScanning: Sendable {
    func scan(root: URL) throws -> [FileNode]
}

struct DefaultFolderScanner: FolderScanning {
    func scan(root: URL) throws -> [FileNode] {
        var results: [FileNode] = []

        let keys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .contentModificationDateKey,
            .fileSizeKey,
            .isRegularFileKey
        ]

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return []
        }

        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: keys)
            let isDir = values?.isDirectory ?? false
            let isFile = values?.isRegularFile ?? (!isDir)

            // index folders and regular files.
            if !(isDir || isFile) { continue }

            let kind: NodeKind = isDir ? .folder : .file
            let name = url.lastPathComponent
            let path = url.path
            let modifiedAt = values?.contentModificationDate
            let sizeBytes = values?.fileSize.map { Int64($0) }

            // not a stable identity across moves/renames.
            // TODO: replace this with a true file identifier later.
            let id = path

            results.append(
                FileNode(
                    id: id,
                    url: url,
                    kind: kind,
                    name: name,
                    path: path,
                    modifiedAt: modifiedAt,
                    sizeBytes: sizeBytes
                )
            )
        }

        // Also include the root itself.
        let rootValues = try? root.resourceValues(forKeys: keys)
        let rootIsDir = rootValues?.isDirectory ?? true
        results.insert(
            FileNode(
                id: root.path,
                url: root,
                kind: rootIsDir ? .folder : .file,
                name: root.lastPathComponent,
                path: root.path,
                modifiedAt: rootValues?.contentModificationDate,
                sizeBytes: rootValues?.fileSize.map { Int64($0) }
            ),
            at: 0
        )

        return results
    }
}

