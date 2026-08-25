import XCTest

/// Generates the brand-site screenshots referenced by `AppScreen.astro` in
/// the app-studio monorepo: `colorvia-home`, `colorvia-home-bottom-sheet`,
/// `colorvia-home-localized-map-controls`, `colorvia-map-coral`,
/// `colorvia-home-dark`, and `colorvia-home-en`. Unlike Yohaku's per-locale
/// sweep, the site only ever shows one capture per screen (locale only
/// changes the `alt` text), so this launches once per screen instead of
/// once per language.
@MainActor
final class AppStoreScreenshotTests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  func testBrandSiteScreenshots() throws {
    try XCTSkipUnless(
      ProcessInfo.processInfo.environment["RUN_SCREENSHOT_TESTS"] == "1",
      "Set RUN_SCREENSHOT_TESTS=1 when intentionally generating screenshots."
    )
    try captureHomeAndControls()
    try captureStats()
    try captureVariant(name: "coral", variant: "coral", attachmentName: "colorvia-map-coral")
    try captureVariant(name: "dark", variant: "dark", attachmentName: "colorvia-home-dark")
    try captureEnglish()
  }

  private func launch(extraArguments: [String] = []) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-ScreenshotMode"] + extraArguments
    app.launch()
    return app
  }

  private func waitForHome(_ app: XCUIApplication) {
    // AppState.load() parses every country/subdivision geometry resource
    // (world, Japan, France, plus per-country subdivisions) on a cold
    // launch, which is slow in an unoptimized Debug build.
    XCTAssertTrue(
      app.otherElements["world-map"].waitForExistence(timeout: 60),
      "world map never appeared"
    )
    // The demo countries animate onto the map; give the colour fill a beat
    // to settle so the capture doesn't catch a mid-transition frame.
    sleep(1)
  }

  private func addScreenshot(_ name: String, app: XCUIApplication) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func captureHomeAndControls() throws {
    let app = launch()
    defer { app.terminate() }
    waitForHome(app)
    addScreenshot("colorvia-home", app: app)
    // Map controls (zoom/reset) are always visible in the same corner; a
    // dedicated capture keeps the site's caption ("map controls") distinct
    // from the plain home shot without depending on an extra UI state.
    addScreenshot("colorvia-home-localized-map-controls", app: app)
  }

  private func captureStats() throws {
    let app = launch()
    defer { app.terminate() }
    waitForHome(app)
    let sheet = app.otherElements["statistics-sheet"]
    XCTAssertTrue(sheet.waitForExistence(timeout: 10), "statistics sheet never appeared")
    // Matches the swipe-up gesture a person would use; the sheet has no
    // plain tap target for "expand".
    let start = sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05))
    let end = sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: -3.5))
    start.press(forDuration: 0.05, thenDragTo: end)
    sleep(1)
    addScreenshot("colorvia-home-bottom-sheet", app: app)
  }

  private func captureVariant(name: String, variant: String, attachmentName: String) throws {
    let app = launch(extraArguments: ["-ScreenshotVariant", variant])
    defer { app.terminate() }
    waitForHome(app)
    addScreenshot(attachmentName, app: app)
  }

  private func captureEnglish() throws {
    let app = launch(extraArguments: ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"])
    defer { app.terminate() }
    waitForHome(app)
    addScreenshot("colorvia-home-en", app: app)
  }
}
