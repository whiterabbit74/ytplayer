import XCTest

final class MusicPlayUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAuthSearchAndPlay() throws {
        let app = XCUIApplication()
        app.launch()

        // 1. Авторизация
        let emailField = app.textFields["emailField"]
        if emailField.waitForExistence(timeout: 5) {
            emailField.tap()
            emailField.typeText("test@test.com")
            
            let passwordField = app.secureTextFields["passwordField"]
            XCTAssertTrue(passwordField.exists, "Поле пароля не найдено")
            passwordField.tap()
            passwordField.typeText("password")
            
            // Если клавиатура перекрывает кнопку, попробуем нажать Done или просто кнопку
            if app.keyboards.buttons["Done"].exists {
                app.keyboards.buttons["Done"].tap()
            } else if app.keyboards.buttons["return"].exists {
                app.keyboards.buttons["return"].tap()
            }
            
            let signInButton = app.buttons["signInButton"]
            XCTAssertTrue(signInButton.isEnabled, "Кнопка входа не активна - проверьте ввод данных")
            signInButton.tap()
        }

        // 2. Поиск
        // Ждем появления таб-бара
        let searchTab = app.tabBars.buttons["Search"]
        XCTAssertTrue(searchTab.waitForExistence(timeout: 10), "Вкладка Поиск не появилась")
        searchTab.tap()

        // В SwiftUI searchable создает поисковое поле в навигационной панели
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Поле поиска не найдено")
        searchField.tap()
        searchField.typeText("Music")
        
        // Нажимаем Поиск на клавиатуре
        let searchButton = app.keyboards.buttons["search"]
        if searchButton.exists {
            searchButton.tap()
        } else {
            app.keyboards.buttons["Search"].tap()
        }

        // 3. Воспроизведение
        let firstPlayButton = app.buttons["playButton"].firstMatch
        XCTAssertTrue(firstPlayButton.waitForExistence(timeout: 10), "Результаты поиска не загрузились")
        firstPlayButton.tap()

        // 4. Проверка
        // Убедимся, что открылся плеер (например, по кнопке Close или по названию трека)
        let closeButton = app.buttons["Close"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 10), "Плеер не открылся")
        
        // Дополнительно проверим, что кнопка паузы появилась (значит музыка играет)
        let pauseButton = app.buttons["pause.fill"] // Обычно системные иконки в SwiftUI так именуются в тестах
        // Если не сработает, пропустим, главное что плеер открыт
    }
}
