import XCTest
@testable import TennisCoach

/// Comprehensive test suite for SecureKeyManager.
///
/// These tests verify Keychain operations including save, retrieve, update,
/// delete, and error handling scenarios.
@available(iOS 13.0, macOS 10.15, *)
final class SecureKeyManagerTests: XCTestCase {

    // MARK: - Properties

    var sut: SecureKeyManager!
    let testAPIKey = "AIzaSyTest123456789-TestKeyForUnitTests"

    // MARK: - Setup & Teardown

    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = SecureKeyManager.shared

        // Clean up any existing test data
        try? sut.deleteGeminiAPIKey()
    }

    override func tearDownWithError() throws {
        // Clean up after tests
        try? sut.deleteGeminiAPIKey()
        sut = nil
        try super.tearDownWithError()
    }

    // MARK: - Save Tests

    func testSaveAPIKey_Success() throws {
        // Given
        let apiKey = testAPIKey

        // When
        try sut.saveGeminiAPIKey(apiKey)

        // Then
        XCTAssertTrue(sut.hasGeminiAPIKey(), "API key should exist in Keychain")
    }

    func testSaveAPIKey_EmptyString() throws {
        // Given
        let emptyKey = ""

        // When
        try sut.saveGeminiAPIKey(emptyKey)

        // Then
        let retrieved = try sut.getGeminiAPIKey()
        XCTAssertEqual(retrieved, "", "Empty string should be saved successfully")
    }

    func testSaveAPIKey_OverwritesExisting() throws {
        // Given
        let firstKey = "first-key"
        let secondKey = "second-key"

        // When
        try sut.saveGeminiAPIKey(firstKey)
        try sut.saveGeminiAPIKey(secondKey)

        // Then
        let retrieved = try sut.getGeminiAPIKey()
        XCTAssertEqual(retrieved, secondKey, "Second key should overwrite first")
    }

    func testSaveAPIKey_SpecialCharacters() throws {
        // Given
        let keyWithSpecialChars = "AIza-_./!@#$%^&*()+={}[]|\\:;\"'<>?~`"

        // When
        try sut.saveGeminiAPIKey(keyWithSpecialChars)

        // Then
        let retrieved = try sut.getGeminiAPIKey()
        XCTAssertEqual(retrieved, keyWithSpecialChars, "Special characters should be preserved")
    }

    func testSaveAPIKey_UnicodeCharacters() throws {
        // Given
        let keyWithUnicode = "key-with-emoji-🔑-and-unicode-字符"

        // When
        try sut.saveGeminiAPIKey(keyWithUnicode)

        // Then
        let retrieved = try sut.getGeminiAPIKey()
        XCTAssertEqual(retrieved, keyWithUnicode, "Unicode characters should be preserved")
    }

    // MARK: - Retrieve Tests

    func testGetAPIKey_Success() throws {
        // Given
        try sut.saveGeminiAPIKey(testAPIKey)

        // When
        let retrieved = try sut.getGeminiAPIKey()

        // Then
        XCTAssertEqual(retrieved, testAPIKey, "Retrieved key should match saved key")
    }

    func testGetAPIKey_NotFound() throws {
        // Given - no key saved

        // When
        let retrieved = try sut.getGeminiAPIKey()

        // Then
        XCTAssertNil(retrieved, "Should return nil when key doesn't exist")
    }

    func testGetAPIKey_AfterDelete() throws {
        // Given
        try sut.saveGeminiAPIKey(testAPIKey)
        try sut.deleteGeminiAPIKey()

        // When
        let retrieved = try sut.getGeminiAPIKey()

        // Then
        XCTAssertNil(retrieved, "Should return nil after deletion")
    }

    // MARK: - Update Tests

    func testUpdateAPIKey_ExistingKey() throws {
        // Given
        let originalKey = "original-key"
        let updatedKey = "updated-key"
        try sut.saveGeminiAPIKey(originalKey)

        // When
        try sut.updateGeminiAPIKey(updatedKey)

        // Then
        let retrieved = try sut.getGeminiAPIKey()
        XCTAssertEqual(retrieved, updatedKey, "Key should be updated")
    }

    func testUpdateAPIKey_NonExistingKey() throws {
        // Given - no existing key

        // When
        try sut.updateGeminiAPIKey(testAPIKey)

        // Then
        let retrieved = try sut.getGeminiAPIKey()
        XCTAssertEqual(retrieved, testAPIKey, "Update should create key if it doesn't exist")
    }

    // MARK: - Delete Tests

    func testDeleteAPIKey_Success() throws {
        // Given
        try sut.saveGeminiAPIKey(testAPIKey)
        XCTAssertTrue(sut.hasGeminiAPIKey())

        // When
        try sut.deleteGeminiAPIKey()

        // Then
        XCTAssertFalse(sut.hasGeminiAPIKey(), "Key should be deleted")
    }

    func testDeleteAPIKey_NonExisting() throws {
        // Given - no key exists

        // When/Then - should not throw
        XCTAssertNoThrow(try sut.deleteGeminiAPIKey())
    }

    func testDeleteAPIKey_MultipleTimes() throws {
        // Given
        try sut.saveGeminiAPIKey(testAPIKey)

        // When/Then - deleting multiple times should not throw
        XCTAssertNoThrow(try sut.deleteGeminiAPIKey())
        XCTAssertNoThrow(try sut.deleteGeminiAPIKey())
        XCTAssertNoThrow(try sut.deleteGeminiAPIKey())
    }

    // MARK: - Existence Tests

    func testExists_WhenKeyExists() throws {
        // Given
        try sut.saveGeminiAPIKey(testAPIKey)

        // When
        let exists = sut.hasGeminiAPIKey()

        // Then
        XCTAssertTrue(exists, "Should return true when key exists")
    }

    func testExists_WhenKeyDoesNotExist() {
        // Given - no key saved

        // When
        let exists = sut.hasGeminiAPIKey()

        // Then
        XCTAssertFalse(exists, "Should return false when key doesn't exist")
    }

    // MARK: - Thread Safety Tests

    func testConcurrentSaveOperations() throws {
        let expectation = XCTestExpectation(description: "Concurrent saves")
        let iterations = 100
        var completedCount = 0

        // When - perform multiple concurrent saves
        for i in 0..<iterations {
            DispatchQueue.global().async {
                do {
                    try self.sut.saveGeminiAPIKey("key-\(i)")
                    DispatchQueue.main.async {
                        completedCount += 1
                        if completedCount == iterations {
                            expectation.fulfill()
                        }
                    }
                } catch {
                    XCTFail("Save operation failed: \(error)")
                }
            }
        }

        wait(for: [expectation], timeout: 10.0)

        // Then - should have a valid key stored
        XCTAssertTrue(sut.hasGeminiAPIKey())
    }

    func testConcurrentReadOperations() throws {
        // Given
        try sut.saveGeminiAPIKey(testAPIKey)

        let expectation = XCTestExpectation(description: "Concurrent reads")
        let iterations = 100
        var completedCount = 0
        var successCount = 0

        // When - perform multiple concurrent reads
        for _ in 0..<iterations {
            DispatchQueue.global().async {
                do {
                    let key = try self.sut.getGeminiAPIKey()
                    DispatchQueue.main.async {
                        if key == self.testAPIKey {
                            successCount += 1
                        }
                        completedCount += 1
                        if completedCount == iterations {
                            expectation.fulfill()
                        }
                    }
                } catch {
                    XCTFail("Read operation failed: \(error)")
                }
            }
        }

        wait(for: [expectation], timeout: 10.0)

        // Then - all reads should have succeeded
        XCTAssertEqual(successCount, iterations, "All concurrent reads should succeed")
    }

    // MARK: - Performance Tests

    func testPerformanceSave() throws {
        measure {
            do {
                try sut.saveGeminiAPIKey(testAPIKey)
            } catch {
                XCTFail("Save operation failed: \(error)")
            }
        }
    }

    func testPerformanceRetrieve() throws {
        // Given
        try sut.saveGeminiAPIKey(testAPIKey)

        // Measure
        measure {
            do {
                _ = try sut.getGeminiAPIKey()
            } catch {
                XCTFail("Retrieve operation failed: \(error)")
            }
        }
    }

    func testPerformanceUpdate() throws {
        // Given
        try sut.saveGeminiAPIKey(testAPIKey)

        // Measure
        measure {
            do {
                try sut.updateGeminiAPIKey("updated-\(testAPIKey)")
            } catch {
                XCTFail("Update operation failed: \(error)")
            }
        }
    }

    // MARK: - Integration Tests

    func testFullCycleOperation() throws {
        // Save
        try sut.saveGeminiAPIKey(testAPIKey)
        XCTAssertTrue(sut.hasGeminiAPIKey())

        // Retrieve
        let retrieved = try sut.getGeminiAPIKey()
        XCTAssertEqual(retrieved, testAPIKey)

        // Update
        let updatedKey = "updated-\(testAPIKey)"
        try sut.updateGeminiAPIKey(updatedKey)
        let afterUpdate = try sut.getGeminiAPIKey()
        XCTAssertEqual(afterUpdate, updatedKey)

        // Delete
        try sut.deleteGeminiAPIKey()
        XCTAssertFalse(sut.hasGeminiAPIKey())

        // Verify deletion
        let afterDelete = try sut.getGeminiAPIKey()
        XCTAssertNil(afterDelete)
    }

    // MARK: - Generic Service Tests

    func testGenericServiceOperations() throws {
        // Given
        let testKey = "test-service-key"
        let service = SecureKeyManager.ServiceIdentifier.geminiAPI

        // When - save using generic method
        try sut.save(key: testKey, forService: service)

        // Then - retrieve using generic method
        let retrieved = try sut.get(forService: service)
        XCTAssertEqual(retrieved, testKey)

        // When - update using generic method
        let updatedKey = "updated-test-key"
        try sut.update(key: updatedKey, forService: service)

        // Then - verify update
        let afterUpdate = try sut.get(forService: service)
        XCTAssertEqual(afterUpdate, updatedKey)

        // When - delete using generic method
        try sut.delete(forService: service)

        // Then - verify deletion
        let afterDelete = try sut.get(forService: service)
        XCTAssertNil(afterDelete)
    }

    // MARK: - Edge Cases

    func testVeryLongAPIKey() throws {
        // Given - a very long key (10KB)
        let longKey = String(repeating: "A", count: 10_000)

        // When
        try sut.saveGeminiAPIKey(longKey)

        // Then
        let retrieved = try sut.getGeminiAPIKey()
        XCTAssertEqual(retrieved, longKey)
        XCTAssertEqual(retrieved?.count, 10_000)
    }

    func testSingleCharacterKey() throws {
        // Given
        let singleChar = "A"

        // When
        try sut.saveGeminiAPIKey(singleChar)

        // Then
        let retrieved = try sut.getGeminiAPIKey()
        XCTAssertEqual(retrieved, singleChar)
    }

    func testWhitespaceKey() throws {
        // Given
        let whitespaceKey = "   key with   spaces   "

        // When
        try sut.saveGeminiAPIKey(whitespaceKey)

        // Then
        let retrieved = try sut.getGeminiAPIKey()
        XCTAssertEqual(retrieved, whitespaceKey, "Whitespace should be preserved")
    }

    func testNewlineInKey() throws {
        // Given
        let keyWithNewlines = "line1\nline2\nline3"

        // When
        try sut.saveGeminiAPIKey(keyWithNewlines)

        // Then
        let retrieved = try sut.getGeminiAPIKey()
        XCTAssertEqual(retrieved, keyWithNewlines, "Newlines should be preserved")
    }
}
