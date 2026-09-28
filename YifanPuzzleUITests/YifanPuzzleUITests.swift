import XCTest

final class YifanPuzzleUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchAndEnterGame() throws {
        let app = XCUIApplication()
        app.launch()

        // 主菜单就绪（新版名称）
        XCTAssertTrue(app.staticTexts["一凡爱拼图"].waitForExistence(timeout: 8))

        // 进入选关页
        let startButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "开始游戏")).firstMatch
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()

        // 点击"开始拼图"进入真实对局（回归：真机曾在此路径闪退）
        let playButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "开始拼图")).firstMatch
        XCTAssertTrue(playButton.waitForExistence(timeout: 8))
        playButton.tap()
        sleep(3) // 等待碎片切片渲染与场景呈现

        // 对局画面截图（SpriteKit 场景已呈现；若进局闪退此用例直接失败）
        let gameScreenshot = XCTAttachment(screenshot: app.screenshot())
        gameScreenshot.name = "Game_Screenshot"
        gameScreenshot.lifetime = .keepAlways
        add(gameScreenshot)
    }
}
