//
//  cool_iosUITests.swift
//  cool-iosUITests
//
//  Created by Amorn Apichattanakul on 21/11/2567 BE.
//

import XCTest

final class cool_iosUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    /// Tab 4 end to end: the native page and the Flutter badge share one
    /// scroll view, and each side owns what the promo contract says it owns.
    func testShopBadgeOwnsItsDragsAndClaimsTheNativePrice() throws {
        let app = XCUIApplication()
        app.launch()
        signIn(app)
        // A tab tap can land while a system sheet is still animating away.
        let price = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '$249.00'")).firstMatch
        for _ in 0..<3 where !price.exists {
            app.tabBars.buttons["Shop"].tap()
            _ = price.waitForExistence(timeout: 3)
        }
        XCTAssertTrue(price.exists)
        attachScreenshot(app, named: "shop-top")

        // Park the tile with its top 140pt down the screen, so the badge and
        // the native promo field below it are both in view and clear of the
        // navigation bar and the HUD. Scroll only from the page margin, which
        // never belongs to the tile.
        let specifications = app.staticTexts["SPECIFICATIONS"]
        let promoField = app.textFields["promoCodeField"]
        let window = app.windows.firstMatch
        let tileHeight: CGFloat = 340
        let tileTop = { specifications.frame.minY - 22 - tileHeight }
        let parkedTop: CGFloat = 140
        for _ in 0..<12 where abs(tileTop() - parkedTop) > 12 {
            dragPage(app, by: max(-300, min(300, parkedTop - tileTop())))
        }
        XCTAssertEqual(tileTop(), parkedTop, accuracy: 12, "Could not scroll the tile into place")
        XCTAssertLessThan(promoField.frame.maxY, window.frame.height - 90, "The promo field is not in view")
        sleep(2) // The engine resumes as the tile nears the viewport.
        attachScreenshot(app, named: "shop-badge")

        // The hanging badge's center is 178pt below the tile's top.
        let badge = window.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: window.frame.midX, dy: tileTop() + 178))

        let before = specifications.frame.minY
        badge.press(forDuration: 0.05, thenDragTo: badge.withOffset(CGVector(dx: 60, dy: -140)))
        XCTAssertEqual(specifications.frame.minY, before, accuracy: 1, "A drag on the badge scrolled the page")
        attachScreenshot(app, named: "shop-badge-thrown")

        sleep(6) // Let the swing die down, so the tap finds the badge at rest.
        badge.tap()
        let filled = NSPredicate(format: "value == 'HOLO20'")
        expectation(for: filled, evaluatedWith: promoField)
        waitForExpectations(timeout: 5)
        let claimed = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '$199.20'")).firstMatch
        XCTAssertTrue(claimed.waitForExistence(timeout: 5), "Claiming in Flutter did not update the native price")
        sleep(1)
        attachScreenshot(app, named: "shop-claimed")

        // Playing with the badge must never leave the page unable to scroll.
        for (attempt, distance) in [-140, 140, -140, 140, -140].enumerated() {
            let start = specifications.frame.minY
            dragPage(app, by: CGFloat(distance))
            let moved = specifications.frame.minY - start
            XCTAssertEqual(moved, CGFloat(distance), accuracy: 40, "Margin drag \(attempt) moved the page by \(moved)")
        }
    }

    private func signIn(_ app: XCUIApplication) {
        let username = app.textFields["Username"]
        XCTAssertTrue(username.waitForExistence(timeout: 10))
        focus(username)
        username.typeText("demo")
        let password = app.secureTextFields["Password"]
        focus(password)
        password.typeText("demo")
        app.buttons["Sign In"].tap()
        XCTAssertTrue(app.tabBars.buttons["Shop"].waitForExistence(timeout: 10))

        // AutoFill offers to save the demo password in a system sheet that
        // covers the app and swallows every gesture until it is dismissed.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for notNow in [app.buttons["Not Now"], springboard.buttons["Not Now"]]
        where notNow.waitForExistence(timeout: 3) {
            notNow.tap()
            _ = notNow.waitForNonExistence(timeout: 5)
            break
        }
    }

    /// Taps until the field really has keyboard focus: right after launch a
    /// tap can land before the field accepts it, and typeText then fails.
    private func focus(_ field: XCUIElement) {
        let focused = NSPredicate(format: "hasKeyboardFocus == true")
        for _ in 0..<3 {
            field.tap()
            let wait = XCTNSPredicateExpectation(predicate: focused, object: field)
            if XCTWaiter.wait(for: [wait], timeout: 2) == .completed { return }
        }
        XCTFail("Could not give \(field) keyboard focus")
    }

    /// Drags vertically in the page's left margin, outside every tile. Slow,
    /// and held at the end, so the page moves by `distance` without coasting.
    private func dragPage(_ app: XCUIApplication, by distance: CGFloat) {
        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: 6, dy: window.frame.height * 0.6))
        start.press(
            forDuration: 0.05,
            thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)),
            withVelocity: .slow,
            thenHoldForDuration: 0.3
        )
    }

    private func attachScreenshot(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
