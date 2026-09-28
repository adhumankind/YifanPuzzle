import XCTest

final class YifanPuzzleUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchAndEnterGame() throws {
        let app = XCUIApplication()
        app.launch()

        // 主菜单就绪（新版名称）
        print("STAGE: waiting for menu title")
        XCTAssertTrue(app.staticTexts["一凡爱拼图"].waitForExistence(timeout: 10), "主菜单标题未出现")

        // 进入选关页
        print("STAGE: menu title found, locating start button")
        let startButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "开始游戏")).firstMatch
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "开始游戏按钮未出现")
        startButton.tap()
        print("STAGE: start tapped, waiting for level select")

        // 点击"开始拼图"进入真实对局（回归：真机曾在此路径闪退）
        let playButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "开始拼图")).firstMatch
        XCTAssertTrue(playButton.waitForExistence(timeout: 10), "开始拼图按钮未出现")
        playButton.tap()
        print("STAGE: play tapped, entering real game")
        sleep(3) // 等待碎片切片渲染与场景呈现

        // 对局画面截图（SpriteKit 场景已呈现；若进局闪退此用例直接失败）
        let gameScreenshot = XCTAttachment(screenshot: app.screenshot())
        gameScreenshot.name = "Game_Screenshot"
        gameScreenshot.lifetime = .keepAlways
        add(gameScreenshot)
    }
}
