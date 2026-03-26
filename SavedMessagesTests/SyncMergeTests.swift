import XCTest
@testable import SavedMessages

final class SyncMergeTests: XCTestCase {

    // MARK: - Union Merge

    func testLocalOnlyItemsArePreserved() {
        let local = [
            DataItem(id: "a", type: .text, title: "Local", tags: ["Text"], textContent: "hello", createdAt: 100)
        ]
        let result = StorageService.mergeItems(local: local, remote: [], deletedIDs: [])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, "a")
    }

    func testRemoteOnlyItemsAreDownloaded() {
        let remote = [
            DataItem(id: "b", type: .text, title: "Remote", tags: ["Text"], textContent: "world", createdAt: 200)
        ]
        let result = StorageService.mergeItems(local: [], remote: remote, deletedIDs: [])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, "b")
    }

    func testUnionOfLocalAndRemoteItems() {
        let local = [DataItem(id: "a", type: .text, title: "A", tags: ["Text"], createdAt: 100)]
        let remote = [DataItem(id: "b", type: .text, title: "B", tags: ["Text"], createdAt: 200)]
        let result = StorageService.mergeItems(local: local, remote: remote, deletedIDs: [])
        XCTAssertEqual(result.count, 2)
        let ids = Set(result.map { $0.id })
        XCTAssertTrue(ids.contains("a"))
        XCTAssertTrue(ids.contains("b"))
    }

    // MARK: - LWW Conflict Resolution

    func testRemoteWinsWhenNewerModifiedAt() {
        let local = [DataItem(id: "x", type: .text, title: "Old", tags: ["Text"], createdAt: 100, modifiedAt: 150)]
        let remote = [DataItem(id: "x", type: .text, title: "New", tags: ["Text", "Updated"], createdAt: 100, modifiedAt: 200)]
        let result = StorageService.mergeItems(local: local, remote: remote, deletedIDs: [])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].title, "New")
        XCTAssertTrue(result[0].tags.contains("Updated"))
    }

    func testLocalWinsWhenNewerModifiedAt() {
        let local = [DataItem(id: "x", type: .text, title: "Newer", tags: ["Text"], createdAt: 100, modifiedAt: 300)]
        let remote = [DataItem(id: "x", type: .text, title: "Older", tags: ["Text"], createdAt: 100, modifiedAt: 200)]
        let result = StorageService.mergeItems(local: local, remote: remote, deletedIDs: [])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].title, "Newer")
    }

    func testEqualTimestampsPreservesLocalItem() {
        let local = [DataItem(id: "x", type: .text, title: "Local", tags: ["Text"], createdAt: 100)]
        let remote = [DataItem(id: "x", type: .text, title: "Remote", tags: ["Text"], createdAt: 100)]
        let result = StorageService.mergeItems(local: local, remote: remote, deletedIDs: [])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].title, "Local")
    }

    // MARK: - Deleted IDs (Tombstones)

    func testDeletedIDsAreRemoved() {
        let local = [
            DataItem(id: "a", type: .text, title: "Keep", tags: ["Text"], createdAt: 100),
            DataItem(id: "b", type: .text, title: "Delete", tags: ["Text"], createdAt: 200)
        ]
        let result = StorageService.mergeItems(local: local, remote: [], deletedIDs: ["b"])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, "a")
    }

    func testBothLocalAndRemoteDeletionsApplied() {
        let items = [
            DataItem(id: "a", type: .text, title: "A", tags: ["Text"], createdAt: 100),
            DataItem(id: "b", type: .text, title: "B", tags: ["Text"], createdAt: 200),
            DataItem(id: "c", type: .text, title: "C", tags: ["Text"], createdAt: 300)
        ]
        let localDeleted: Set<String> = ["a"]
        let remoteDeleted: Set<String> = ["c"]
        let mergedDeleted = localDeleted.union(remoteDeleted)
        let result = StorageService.mergeItems(local: items, remote: [], deletedIDs: mergedDeleted)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, "b")
    }

    func testDeletedRemoteItemNotAdded() {
        let remote = [DataItem(id: "r", type: .text, title: "Deleted", tags: ["Text"], createdAt: 100)]
        let result = StorageService.mergeItems(local: [], remote: remote, deletedIDs: ["r"])
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Edge Cases

    func testEmptyMergeProducesEmptyResult() {
        let result = StorageService.mergeItems(local: [], remote: [], deletedIDs: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testResultSortedByCreatedAtDescending() {
        let local = [
            DataItem(id: "a", type: .text, title: "Oldest", tags: ["Text"], createdAt: 100),
            DataItem(id: "c", type: .text, title: "Newest", tags: ["Text"], createdAt: 300)
        ]
        let remote = [DataItem(id: "b", type: .text, title: "Middle", tags: ["Text"], createdAt: 200)]
        let result = StorageService.mergeItems(local: local, remote: remote, deletedIDs: [])
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].id, "c")
        XCTAssertEqual(result[1].id, "b")
        XCTAssertEqual(result[2].id, "a")
    }

    // MARK: - Backward Compatibility

    func testModifiedAtFallsBackToCreatedAt() {
        let item = DataItem(id: "old", type: .text, title: "Old", tags: ["Text"], createdAt: 100)
        XCTAssertNil(item.modifiedAt)
        XCTAssertEqual(item.effectiveModifiedAt, 100)
    }

    func testModifiedAtTakesPrecedence() {
        let oldItem = DataItem(id: "x", type: .text, title: "Old", tags: ["Text"], createdAt: 100)
        let newItem = DataItem(id: "x", type: .text, title: "Updated", tags: ["Text", "New"], createdAt: 100, modifiedAt: 200)
        let result = StorageService.mergeItems(local: [oldItem], remote: [newItem], deletedIDs: [])
        XCTAssertEqual(result[0].title, "Updated")
    }

    func testJSONRoundtripPreservesModifiedAt() throws {
        let item = DataItem(id: "test", type: .text, title: "Test", tags: ["Text"], createdAt: 100, modifiedAt: 200)
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(DataItem.self, from: data)
        XCTAssertEqual(decoded.modifiedAt, 200)
        XCTAssertEqual(decoded.effectiveModifiedAt, 200)
    }

    func testJSONWithoutModifiedAtDecodesAsNil() throws {
        let json = """
        {"id":"old","type":"text","title":"Old","tags":["Text"],"createdAt":100}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(DataItem.self, from: json)
        XCTAssertNil(decoded.modifiedAt)
        XCTAssertEqual(decoded.effectiveModifiedAt, 100)
    }
}
