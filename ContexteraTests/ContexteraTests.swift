import XCTest
@testable import Contextera

final class ContexteraTests: XCTestCase {

    // MARK: - Mocks

    private struct MockScanner: FolderScanning {
        let nodes: [FileNode]
        func scan(root: URL) throws -> [FileNode] { nodes }
    }

    private struct ThrowingScanner: FolderScanning {
        enum TestError: Error { case boom }
        func scan(root: URL) throws -> [FileNode] { throw TestError.boom }
    }

    // MARK: - Tests

    func test_refreshIndex_sortsFoldersFirst_thenByPath() async {
        let root = URL(fileURLWithPath: "/tmp/root")

        let aFile = FileNode(
            id: root.appendingPathComponent("b.txt").path,
            url: root.appendingPathComponent("b.txt"),
            kind: .file,
            name: "b.txt",
            path: root.appendingPathComponent("b.txt").path,
            modifiedAt: nil,
            sizeBytes: 10
        )

        let zFolder = FileNode(
            id: root.appendingPathComponent("zFolder").path,
            url: root.appendingPathComponent("zFolder"),
            kind: .folder,
            name: "zFolder",
            path: root.appendingPathComponent("zFolder").path,
            modifiedAt: nil,
            sizeBytes: nil
        )

        let aFolder = FileNode(
            id: root.appendingPathComponent("aFolder").path,
            url: root.appendingPathComponent("aFolder"),
            kind: .folder,
            name: "aFolder",
            path: root.appendingPathComponent("aFolder").path,
            modifiedAt: nil,
            sizeBytes: nil
        )

        // Intentionally unsorted input
        let model = AppModel(scanner: MockScanner(nodes: [aFile, zFolder, aFolder]))
        model.setRoot(root)

        await model.refreshIndex()

        XCTAssertEqual(model.nodes.map(\.path), [
            root.path,
            aFolder.path,
            zFolder.path,
            aFile.path
        ])

        let kinds = model.nodes.dropFirst().map(\.kind)
        XCTAssertEqual(kinds, [.folder, .folder, .file])
    }

    func test_refreshIndex_withNilRoot_clearsNodes() async {
        let model = AppModel(scanner: MockScanner(nodes: []))
        model.rootURL = nil

        await model.refreshIndex()

        XCTAssertTrue(model.nodes.isEmpty)
        XCTAssertNil(model.lastIndexError)
        XCTAssertFalse(model.isIndexing)
    }

    func test_refreshIndex_whenScannerThrows_setsError_andClearsNodes() async {
        let root = URL(fileURLWithPath: "/tmp/root")
        let model = AppModel(scanner: ThrowingScanner())
        model.setRoot(root)

        await model.refreshIndex()

        XCTAssertTrue(model.nodes.isEmpty)
        XCTAssertNotNil(model.lastIndexError)
        XCTAssertFalse(model.isIndexing)
    }
}
