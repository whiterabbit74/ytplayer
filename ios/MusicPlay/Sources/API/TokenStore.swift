import Foundation
import Security

final class TokenStore {
    private let accessKey = "musicplay_access_token"
    private let refreshKey = "musicplay_refresh_token"

    var accessToken: String? {
        get { read(key: accessKey) }
        set {
            if let value = newValue {
                save(key: accessKey, value: value)
            } else {
                delete(key: accessKey)
            }
        }
    }

    var refreshToken: String? {
        get { read(key: refreshKey) }
        set {
            if let value = newValue {
                save(key: refreshKey, value: value)
            } else {
                delete(key: refreshKey)
            }
        }
    }

    func clear() {
        accessToken = nil
        refreshToken = nil
    }

    private func save(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
