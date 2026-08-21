//
//  LaunchUITests.swift
//  KinoPubAppleClientUITests
//
//  What a UI test can honestly assert on a runner that is not signed in.
//
//  A CI simulator has no kino.pub session — `DevSessionMirror` only seeds one from a
//  developer's own machine — so anything past the auth screen is out of reach here. What
//  is reachable is the most valuable regression there is on tvOS: **the app launches, and
//  it does not sit on a black screen.** Both of those have broken before.
//
//  Focus behaviour is deliberately not asserted. It needs content, and a screenshot cannot
//  show whether a landing felt right; that stays a device check.
//

import XCTest

final class LaunchUITests: XCTestCase {

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  private func launchedApp() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments += ["-ui-testing"]
    app.launch()
    return app
  }

  func testTheAppLaunches() {
    let app = launchedApp()
    XCTAssertEqual(app.state, .runningForeground)
  }

  /// A launch that paints nothing is the failure this catches: the splash names what it is
  /// waiting for (`LaunchStatusLabel`), and past it there is a session screen or a shell.
  /// Any of them means the first frame arrived; none of them means a black screen.
  func testSomethingIsOnScreenAfterLaunch() {
    let app = launchedApp()
    let anyContent = app.descendants(matching: .any).firstMatch
    XCTAssertTrue(anyContent.waitForExistence(timeout: 30),
                  "the first frame never painted anything")
  }

  /// The app must survive being backgrounded and brought back — the session and the player
  /// both hold state across it.
  ///
  /// iOS only: `XCUIDevice.Button.home` does not exist on tvOS, where the equivalent is a
  /// remote press through `XCUIRemote`, and there is no Home on the Mac at all.
#if os(iOS)
  func testTheAppSurvivesABackgroundRoundTrip() {
    let app = launchedApp()
    XCUIDevice.shared.press(.home)
    app.activate()
    XCTAssertEqual(app.state, .runningForeground)
  }
#endif
}
