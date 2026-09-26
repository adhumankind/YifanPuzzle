import XCTest

final class YifanPuzzleUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchAndTakeScreenshot() throws {
        let app = XCUIApplication()
        app.launch()

        // 等待界面就绪
        XCTAssertTrue(app.staticTexts["一凡拼图"].waitForExistence(timeout: 5))

        // 截取主菜单画面
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "MainMenu_Screenshot"
        attachment.lifetime = .keepAlways
        add(attachment)

        // 点击开始游戏
        let startButton = app.buttons["开始游戏"]
        if startButton.exists {
            startButton.tap()

            // 截取关卡选择画面
            let levelSelectScreenshot = app.screenshot()
            let levelAttachment = XCTAttachment(screenshot: levelSelectScreenshot)
            levelAttachment.name = "LevelSelect_Screenshot"
            levelAttachment.lifetime = .keepAlways
            add(levelAttachment)
        }
    }
}
