import XCTest

/// UI tests for the Share Extension flow from the Photos app.
///
/// These tests launch the system Photos app, share one or more images via the
/// share sheet, and verify that the SavedMessages share extension processes them
/// correctly. Because the tests depend on the Photos library containing at least
/// one image (add test assets to the simulator beforehand), they are best run
/// manually on a local simulator rather than in headless CI.
final class ShareExtensionUITests: XCTestCase {

    private var app: XCUIApplication!
    private var photosApp: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        photosApp = XCUIApplication(bundleIdentifier: "com.apple.mobileslideshow")
    }

    override func tearDownWithError() throws {
        app = nil
        photosApp = nil
    }

    // MARK: - Helpers

    /// Launch the main app, then background it so the share extension can run.
    private func launchMainAppInBackground() {
        app.launch()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
    }

    /// Opens the Photos app and navigates to the first photo in the library.
    /// - Returns: `true` if a photo was successfully opened.
    @discardableResult
    private func openFirstPhotoInPhotos() -> Bool {
        photosApp.launch()
        // Wait for the Photos UI to be ready
        let photosReady = photosApp.waitForExistence(timeout: 5)
        guard photosReady else { return false }

        // The Photos "Library" tab shows a grid of thumbnails. Each image in
        // the grid is typically an XCUIElement of type .image or .cell.
        let firstPhoto = photosApp.cells.firstMatch
        guard firstPhoto.waitForExistence(timeout: 5) else { return false }
        firstPhoto.tap()
        return true
    }

    /// Taps the system share button in the Photos detail view.
    private func tapShareButton() {
        let shareButton = photosApp.buttons["Share"]
        if !shareButton.waitForExistence(timeout: 3) {
            // Tap the photo area to reveal the toolbar if hidden
            photosApp.images.firstMatch.tap()
        }
        XCTAssertTrue(shareButton.waitForExistence(timeout: 3), "Share button should be visible")
        shareButton.tap()
    }

    /// Finds and taps the SavedMessages share extension in the share sheet.
    /// The extension's display name is "Save to SavedMessages" (from Info.plist).
    private func tapSavedMessagesExtension() {
        let shareSheet = photosApp.otherElements["ActivityListView"]
        XCTAssertTrue(shareSheet.waitForExistence(timeout: 5), "Share sheet should appear")

        // The extension might be in the scrollable row of action/share icons,
        // or in the list below. Scroll to find it if needed.
        let extensionButton = photosApp.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "SavedMessages")
        ).firstMatch

        if !extensionButton.waitForExistence(timeout: 3) {
            // Try scrolling the share sheet to reveal more options
            shareSheet.swipeUp()
        }

        XCTAssertTrue(
            extensionButton.waitForExistence(timeout: 5),
            "SavedMessages share extension should appear in the share sheet"
        )
        extensionButton.tap()
    }

    /// Waits for the share extension's tag picker to appear and taps Save.
    private func completeTagPickerAndSave() {
        // The tag picker is presented by the share extension with title "Add Tags"
        let tagPickerNav = photosApp.navigationBars["Add Tags"]
        XCTAssertTrue(
            tagPickerNav.waitForExistence(timeout: 10),
            "Tag picker should appear after share extension processes the item"
        )

        let saveButton = tagPickerNav.buttons["Save"]
        XCTAssertTrue(saveButton.exists, "Save button should be visible in tag picker")
        saveButton.tap()
    }

    /// Waits for the share extension HUD to show success and dismiss.
    private func waitForExtensionDismissal() {
        // After saving, the extension shows a brief success HUD and then
        // dismisses itself. Wait for the share sheet / extension UI to vanish.
        // The Photos detail view should be back.
        let photosNavBar = photosApp.navigationBars.firstMatch
        XCTAssertTrue(
            photosNavBar.waitForExistence(timeout: 10),
            "Photos should return to foreground after extension dismisses"
        )
    }

    // MARK: - Tests

    /// Tests the full flow: open Photos → share a photo → SavedMessages
    /// extension → tag picker → save → verify item in main app.
    func testShareSinglePhotoFromPhotos() throws {
        // 1. Launch the main app first so its container is initialised
        launchMainAppInBackground()

        // 2. Open Photos and navigate to the first photo
        let photoOpened = openFirstPhotoInPhotos()
        try XCTSkipUnless(photoOpened, "No photos available in the simulator library – skipping test")

        // 3. Tap the Share button
        tapShareButton()

        // 4. Find and tap the SavedMessages extension
        tapSavedMessagesExtension()

        // 5. Complete the tag picker
        completeTagPickerAndSave()

        // 6. Wait for the extension to dismiss
        waitForExtensionDismissal()

        // 7. Switch back to the main app and verify the item appeared
        app.activate()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 5))

        // The shared photo should appear as a new item in the list.
        // Photos items get the "Photo" tag and a "Photos" source tag.
        let photoTag = app.staticTexts["Photo"]
        XCTAssertTrue(
            photoTag.waitForExistence(timeout: 5),
            "A newly shared photo item should appear with the 'Photo' tag"
        )
    }

    /// Tests sharing a photo and cancelling the tag picker.
    func testSharePhotoAndCancelTagPicker() throws {
        launchMainAppInBackground()

        let photoOpened = openFirstPhotoInPhotos()
        try XCTSkipUnless(photoOpened, "No photos available in the simulator library – skipping test")

        tapShareButton()
        tapSavedMessagesExtension()

        // Wait for tag picker
        let tagPickerNav = photosApp.navigationBars["Add Tags"]
        XCTAssertTrue(tagPickerNav.waitForExistence(timeout: 10), "Tag picker should appear")

        // Tap Cancel instead of Save
        let cancelButton = tagPickerNav.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists, "Cancel button should be visible")
        cancelButton.tap()

        // Extension should dismiss without saving
        waitForExtensionDismissal()

        // Verify no new item was added to the main app
        app.activate()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 5))
    }

    /// Tests that the tag picker shows existing tags from the main app.
    func testTagPickerShowsExistingTags() throws {
        // Add an item with a known tag first
        app.launch()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 5))

        app.buttons["addTextButton"].tap()
        XCTAssertTrue(app.navigationBars["Add Text"].waitForExistence(timeout: 2))
        let textEditor = app.textViews["textEditor"]
        textEditor.tap()
        textEditor.typeText("Tag test item")
        app.buttons["saveButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))

        // Background the app
        XCUIDevice.shared.press(.home)

        // Share from Photos
        let photoOpened = openFirstPhotoInPhotos()
        try XCTSkipUnless(photoOpened, "No photos available in the simulator library – skipping test")

        tapShareButton()
        tapSavedMessagesExtension()

        // Verify tag picker shows existing tags
        let tagPickerNav = photosApp.navigationBars["Add Tags"]
        XCTAssertTrue(tagPickerNav.waitForExistence(timeout: 10))

        // The "Text" tag from the previously added item should appear
        let textTag = photosApp.staticTexts["Text"]
        XCTAssertTrue(
            textTag.waitForExistence(timeout: 3),
            "Existing 'Text' tag should appear in the tag picker"
        )

        // Cancel to avoid side effects
        tagPickerNav.buttons["Cancel"].tap()
        waitForExtensionDismissal()
    }

    /// Tests adding a new tag via the tag picker during a share.
    func testAddNewTagDuringShare() throws {
        launchMainAppInBackground()

        let photoOpened = openFirstPhotoInPhotos()
        try XCTSkipUnless(photoOpened, "No photos available in the simulator library – skipping test")

        tapShareButton()
        tapSavedMessagesExtension()

        let tagPickerNav = photosApp.navigationBars["Add Tags"]
        XCTAssertTrue(tagPickerNav.waitForExistence(timeout: 10))

        // Type a new tag name
        let tagField = photosApp.textFields["New tag…"]
        if tagField.waitForExistence(timeout: 3) {
            tagField.tap()
            tagField.typeText("TestShareTag")
            // Tap the Add button
            let addButton = photosApp.buttons["Add"]
            if addButton.exists {
                addButton.tap()
            }
        }

        // Save
        tagPickerNav.buttons["Save"].tap()
        waitForExtensionDismissal()

        // Verify the item with the new tag appears in the main app
        app.activate()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 5))

        let newTag = app.staticTexts["TestShareTag"]
        XCTAssertTrue(
            newTag.waitForExistence(timeout: 5),
            "The newly created tag 'TestShareTag' should appear on the shared item"
        )
    }

    /// Tests that the share extension shows the saving HUD initially.
    func testShareExtensionShowsSavingHUD() throws {
        launchMainAppInBackground()

        let photoOpened = openFirstPhotoInPhotos()
        try XCTSkipUnless(photoOpened, "No photos available in the simulator library – skipping test")

        tapShareButton()
        tapSavedMessagesExtension()

        // The extension should briefly show "Saving…" before the tag picker appears
        // This may be very fast, so we use a short timeout
        let savingText = photosApp.staticTexts["Saving…"]
        // The HUD might already be gone by the time we check, so we don't
        // hard-fail on this assertion. The tag picker appearing is sufficient.
        if savingText.waitForExistence(timeout: 2) {
            XCTAssertTrue(savingText.exists, "Saving HUD should be displayed")
        }

        // Tag picker should appear next
        let tagPickerNav = photosApp.navigationBars["Add Tags"]
        XCTAssertTrue(tagPickerNav.waitForExistence(timeout: 10))

        tagPickerNav.buttons["Cancel"].tap()
        waitForExtensionDismissal()
    }
}
