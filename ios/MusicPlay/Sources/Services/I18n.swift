import SwiftUI

enum Locale: String, CaseIterable, Codable {
    case ru = "ru"
    case en = "en"
    case kk = "kk"
    
    var flag: String {
        switch self {
        case .ru: return "🇷🇺"
        case .en: return "🇺🇸"
        case .kk: return "🇰🇿"
        }
    }
    
    var name: String {
        switch self {
        case .ru: return "Русский"
        case .en: return "English"
        case .kk: return "Қазақша"
        }
    }
}

final class I18nManager: ObservableObject {
    @Published var locale: Locale = .ru {
        didSet {
            UserDefaults.standard.set(locale.rawValue, forKey: "app_locale")
        }
    }
    
    private let translations: [Locale: [String: String]] = [
        .ru: [
            "login_title": "MusicPlay",
            "email_placeholder": "Электронная почта",
            "password_placeholder": "Пароль",
            "sign_in_button": "Войти",
            "login_failed": "Ошибка входа",
            "settings": "Настройки",
            "language": "Язык"
        ],
        .en: [
            "login_title": "MusicPlay",
            "email_placeholder": "Email",
            "password_placeholder": "Password",
            "sign_in_button": "Sign In",
            "login_failed": "Login failed",
            "settings": "Settings",
            "language": "Language"
        ],
        .kk: [
            "login_title": "MusicPlay",
            "email_placeholder": "Электрондық пошта",
            "password_placeholder": "Құпия сөз",
            "sign_in_button": "Кіру",
            "login_failed": "Жүйеге кіру қатесі",
            "settings": "Параметрлер",
            "language": "Тіл"
        ]
    ]
    
    init() {
        if let saved = UserDefaults.standard.string(forKey: "app_locale"),
           let locale = Locale(rawValue: saved) {
            self.locale = locale
        } else {
            // Default to system language if supported
            let systemLanguage = Foundation.Locale.current.language.languageCode?.identifier ?? "ru"
            self.locale = Locale(rawValue: systemLanguage) ?? .ru
        }
    }
    
    func t(_ key: String) -> String {
        return translations[locale]?[key] ?? key
    }
}

struct LanguageSwitcher: View {
    @EnvironmentObject var i18n: I18nManager
    
    var body: some View {
        Menu {
            Picker("Language", selection: $i18n.locale) {
                ForEach(Locale.allCases, id: \.self) { locale in
                    HStack {
                        Text(locale.flag)
                        Text(locale.name)
                    }
                    .tag(locale)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(i18n.locale.flag)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .clipShape(Capsule())
        }
    }
}
