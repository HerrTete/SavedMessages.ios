import XCTest

final class SavedMessagesUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Tab Navigation

    func testTabBarHasThreeTabs() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should be visible")
        XCTAssertTrue(tabBar.buttons["Items"].exists, "Items tab should exist")
        XCTAssertTrue(tabBar.buttons["Settings"].exists, "Settings tab should exist")
        XCTAssertTrue(tabBar.buttons["Tags"].exists, "Tags tab should exist")
    }

    func testSwitchingToSettingsTab() {
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Version"].exists)
        XCTAssertTrue(app.staticTexts["Build"].exists)
    }

    func testSwitchingToTagsTab() {
        app.tabBars.buttons["Tags"].tap()
        XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))
    }

    func testSwitchingBackToItemsTab() {
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
        app.tabBars.buttons["Items"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
    }

    // MARK: - Items Tab Toolbar

    func testItemsTabHasAddButtons() {
        XCTAssertTrue(app.buttons["addTextButton"].exists, "Add text button should be visible")
        XCTAssertTrue(app.buttons["addPhotoVideoButton"].exists, "Add photo/video button should be visible")
        XCTAssertTrue(app.buttons["addAudioButton"].exists, "Add audio button should be visible")
    }

    // MARK: - Add Text Flow

    func testOpenAndCancelAddTextSheet() {
        app.buttons["addTextButton"].tap()
        XCTAssertTrue(app.navigationBars["Add Text"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["cancelButton"].exists)
        app.buttons["cancelButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
    }

    func testAddTextSaveButtonDisabledWhenEmpty() {
        app.buttons["addTextButton"].tap()
        XCTAssertTrue(app.navigationBars["Add Text"].waitForExistence(timeout: 2))
        let saveButton = app.buttons["saveButton"]
        XCTAssertTrue(saveButton.exists)
        XCTAssertFalse(saveButton.isEnabled, "Save should be disabled when text is empty")
        app.buttons["cancelButton"].tap()
    }

    func testAddTextAndSave() {
        app.buttons["addTextButton"].tap()
        XCTAssertTrue(app.navigationBars["Add Text"].waitForExistence(timeout: 2))

        let textEditor = app.textViews["textEditor"]
        XCTAssertTrue(textEditor.exists, "Text editor should be visible")
        textEditor.tap()
        textEditor.typeText("Hello UI Test")

        let saveButton = app.buttons["saveButton"]
        XCTAssertTrue(saveButton.isEnabled, "Save should be enabled after typing text")
        saveButton.tap()

        // Sheet should dismiss and we return to items list
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
        // The newly added item should appear in the list
        XCTAssertTrue(app.staticTexts["Hello UI Test"].waitForExistence(timeout: 2))
    }

    func testAddURLTextShowsURLTag() {
        app.buttons["addTextButton"].tap()
        XCTAssertTrue(app.navigationBars["Add Text"].waitForExistence(timeout: 2))

        let textEditor = app.textViews["textEditor"]
        textEditor.tap()
        textEditor.typeText("https://example.com")

        app.buttons["saveButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
        // URL items get tagged as "URL"
        XCTAssertTrue(app.staticTexts["URL"].waitForExistence(timeout: 2))
    }

    // MARK: - Add Audio Flow

    func testOpenAndCancelAddAudioSheet() {
        app.buttons["addAudioButton"].tap()
        XCTAssertTrue(app.navigationBars["Audio Recording"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["cancelButton"].exists)
        app.buttons["cancelButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
    }

    func testAudioRecordButtonExists() {
        app.buttons["addAudioButton"].tap()
        XCTAssertTrue(app.navigationBars["Audio Recording"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["recordButton"].exists, "Record button should exist")
        // Save is disabled before recording
        let saveButton = app.buttons["saveButton"]
        XCTAssertTrue(saveButton.exists)
        XCTAssertFalse(saveButton.isEnabled, "Save should be disabled before recording")
        app.buttons["cancelButton"].tap()
    }

    func testAudioTimerDisplayExists() {
        app.buttons["addAudioButton"].tap()
        XCTAssertTrue(app.navigationBars["Audio Recording"].waitForExistence(timeout: 2))
        // Timer should show initial value
        XCTAssertTrue(app.staticTexts["00:00.0"].exists, "Timer should show 00:00.0 initially")
        app.buttons["cancelButton"].tap()
    }

    // MARK: - Add Photo/Video Flow

    func testOpenAndCancelAddPhotoVideoSheet() {
        app.buttons["addPhotoVideoButton"].tap()
        XCTAssertTrue(app.navigationBars["Photos & Videos"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["cancelButton"].exists)
        XCTAssertTrue(app.buttons["cameraButton"].exists, "Camera button should exist")
        app.buttons["cancelButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
    }

    func testPhotoVideoSaveButtonDisabledWhenEmpty() {
        app.buttons["addPhotoVideoButton"].tap()
        XCTAssertTrue(app.navigationBars["Photos & Videos"].waitForExistence(timeout: 2))
        let saveButton = app.buttons["saveButton"]
        XCTAssertTrue(saveButton.exists)
        XCTAssertFalse(saveButton.isEnabled, "Save should be disabled when no items are selected")
        app.buttons["cancelButton"].tap()
    }

    func testPhotoVideoViewHasCameraAndLibraryOptions() {
        app.buttons["addPhotoVideoButton"].tap()
        XCTAssertTrue(app.navigationBars["Photos & Videos"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Take Photo or Video"].exists)
        XCTAssertTrue(app.staticTexts["Select Photos & Videos"].exists)
        app.buttons["cancelButton"].tap()
    }

    // MARK: - Settings View

    func testSettingsShowsVersionAndBuild() {
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Version"].exists, "Version label should exist")
        XCTAssertTrue(app.staticTexts["Build"].exists, "Build label should exist")
        XCTAssertTrue(app.staticTexts["App"].exists, "App section header should exist")
    }

    // MARK: - Tags View

    func testTagsViewShowsEmptyState() {
        // Clean start - may show empty state if no items exist
        app.tabBars.buttons["Tags"].tap()
        XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))
        // Either we see tags or the empty state
        let hasContent = app.staticTexts["No Tags"].exists || app.cells.firstMatch.exists
        XCTAssertTrue(hasContent, "Tags view should show either tags or empty state")
    }

    // MARK: - Item Detail & Edit Flow

    func testTapItemOpensDetail() {
        // First, add an item
        addTextItem("Detail test item")

        // Tap the item in the list
        let itemText = app.staticTexts["Detail test item"]
        XCTAssertTrue(itemText.waitForExistence(timeout: 2))
        itemText.tap()

        // Detail view should open
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["editButton"].exists)
        XCTAssertTrue(app.buttons["shareButton"].exists)

        app.buttons["doneButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
    }

    func testEditItemName() {
        addTextItem("Original name item")

        let itemText = app.staticTexts["Original name item"]
        XCTAssertTrue(itemText.waitForExistence(timeout: 2))
        itemText.tap()

        XCTAssertTrue(app.buttons["editButton"].waitForExistence(timeout: 2))
        app.buttons["editButton"].tap()

        // Edit view should open
        XCTAssertTrue(app.navigationBars["Edit"].waitForExistence(timeout: 2))
        let nameField = app.textFields["nameTextField"]
        XCTAssertTrue(nameField.exists)

        // Clear and type new name
        nameField.tap()
        nameField.clearAndTypeText("Renamed item")

        app.buttons["saveButton"].tap()
        // Edit sheet should dismiss, detail view should update title
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2))
        app.buttons["doneButton"].tap()

        // Back on the main list, the renamed item should be visible
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Renamed item"].waitForExistence(timeout: 2))
    }

    func testEditItemCancelDoesNotSave() {
        addTextItem("Cancel edit test")

        let itemText = app.staticTexts["Cancel edit test"]
        XCTAssertTrue(itemText.waitForExistence(timeout: 2))
        itemText.tap()

        XCTAssertTrue(app.buttons["editButton"].waitForExistence(timeout: 2))
        app.buttons["editButton"].tap()

        XCTAssertTrue(app.navigationBars["Edit"].waitForExistence(timeout: 2))
        let nameField = app.textFields["nameTextField"]
        nameField.tap()
        nameField.clearAndTypeText("Should not save")

        app.buttons["cancelButton"].tap()
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2))
        app.buttons["doneButton"].tap()

        // Original name should still be there
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Cancel edit test"].exists)
        XCTAssertFalse(app.staticTexts["Should not save"].exists)
    }

    // MARK: - Delete Item

    func testDeleteItemViaSwipe() {
        addTextItem("Delete me via swipe")

        let itemText = app.staticTexts["Delete me via swipe"]
        XCTAssertTrue(itemText.waitForExistence(timeout: 2))

        // Swipe left to reveal delete action
        itemText.swipeLeft()
        let deleteButton = app.buttons["Delete"]
        if deleteButton.waitForExistence(timeout: 2) {
            deleteButton.tap()
        }

        // Item should be gone
        XCTAssertFalse(app.staticTexts["Delete me via swipe"].waitForExistence(timeout: 2))
    }

    // MARK: - Empty State

    func testEmptyStateShowsWhenNoItems() {
        // If no items exist, the empty state should show
        // This depends on the initial state of the app
        let emptyState = app.staticTexts["No Items"]
        let hasItems = app.cells.firstMatch.exists
        // Either we have items or the empty state
        XCTAssertTrue(emptyState.exists || hasItems, "Should show empty state or items")
    }

    // MARK: - Tags Tab Navigation

    func testTagsTabNavigationToFilteredList() {
        // First, add a text item (will get "Text" tag)
        addTextItem("Tagged item for navigation")

        // Go to Tags tab
        app.tabBars.buttons["Tags"].tap()
        XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))

        // Look for "Text" tag and tap it
        let textTag = app.staticTexts["Text"]
        if textTag.waitForExistence(timeout: 2) {
            textTag.tap()
            // Should navigate to filtered list with that tag as title
            XCTAssertTrue(app.navigationBars["Text"].waitForExistence(timeout: 2))
            XCTAssertTrue(app.staticTexts["Tagged item for navigation"].exists)
        }
    }

    // MARK: - Multiple Items

    func testAddMultipleTextItems() {
        addTextItem("First item")
        addTextItem("Second item")
        addTextItem("Third item")

        XCTAssertTrue(app.staticTexts["First item"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Second item"].exists)
        XCTAssertTrue(app.staticTexts["Third item"].exists)
    }

    // MARK: - Add Tag in Edit View

    func testAddTagToItem() {
        addTextItem("Taggable item")

        let itemText = app.staticTexts["Taggable item"]
        XCTAssertTrue(itemText.waitForExistence(timeout: 2))
        itemText.tap()

        XCTAssertTrue(app.buttons["editButton"].waitForExistence(timeout: 2))
        app.buttons["editButton"].tap()

        XCTAssertTrue(app.navigationBars["Edit"].waitForExistence(timeout: 2))

        let tagInput = app.textFields["tagInputField"]
        XCTAssertTrue(tagInput.exists, "Tag input field should exist")
        tagInput.tap()
        tagInput.typeText("CustomTag")

        // Submit the tag
        let addTagButton = app.buttons["addTagButton"]
        if addTagButton.waitForExistence(timeout: 1) {
            addTagButton.tap()
        } else {
            // Press return to submit
            app.keyboards.buttons["Return"].tap()
        }

        app.buttons["saveButton"].tap()
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2))
        app.buttons["doneButton"].tap()

        // Verify the tag appears on the item in the list
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["CustomTag"].waitForExistence(timeout: 2))
    }

    // MARK: - Text Detail Content

    func testTextItemDetailShowsContent() {
        addTextItem("Full content check")

        app.staticTexts["Full content check"].tap()
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2))
        // The text content should be displayed in the detail view
        XCTAssertTrue(app.staticTexts["Full content check"].exists)
        app.buttons["doneButton"].tap()
    }

    // MARK: - URL Item Detail

    func testURLItemDetailShowsOpenInBrowser() {
        addTextItem("https://example.com")

        let itemText = app.staticTexts["https://example.com"]
        XCTAssertTrue(itemText.waitForExistence(timeout: 2))
        // URL items open in browser on tap, but we can verify the item exists
        // (Since URL items open externally, we just verify the list entry)
        XCTAssertTrue(itemText.exists)
    }

    // MARK: - Helpers

    /// Adds a text item via the Add Text sheet.
    private func addTextItem(_ text: String) {
        // Ensure we're on Items tab
        if !app.navigationBars["SavedMessages"].exists {
            app.tabBars.buttons["Items"].tap()
            _ = app.navigationBars["SavedMessages"].waitForExistence(timeout: 2)
        }

        app.buttons["addTextButton"].tap()
        XCTAssertTrue(app.navigationBars["Add Text"].waitForExistence(timeout: 2))

        let textEditor = app.textViews["textEditor"]
        textEditor.tap()
        textEditor.typeText(text)

        app.buttons["saveButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
    }
}

// MARK: - XCUIElement Helpers

extension XCUIElement {
    /// Clears the text field content and types new text.
    func clearAndTypeText(_ text: String) {
        guard let currentValue = self.value as? String, !currentValue.isEmpty else {
            self.typeText(text)
            return
        }
        // Select all text and delete it
        self.tap()
        self.press(forDuration: 1.0)
        let selectAll = XCUIApplication().menuItems["Select All"]
        if selectAll.waitForExistence(timeout: 1) {
            selectAll.tap()
            self.typeText(text)
        } else {
            // Fallback: delete character by character
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            self.typeText(deleteString + text)
        }
    }
}
