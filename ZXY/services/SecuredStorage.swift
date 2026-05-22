import Foundation
import Security

class SecureStorage {
    private static var store: [String: String]?
    private static let storeKey: String = "zxy_data"
    static func saveKey(key: String, value: String) {
        if store == nil {
            store = [:]
        }
        store![key] = value

        let json = try! JSONEncoder().encode(store)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: storeKey,
            kSecValueData as String: json,
        ]

        // Delete any existing item before saving
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func getKey(key: String) -> String? {
        if store == nil {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: storeKey,
                kSecReturnData as String: kCFBooleanTrue!,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]

            var dataTypeRef: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

            if status == errSecSuccess, let data = dataTypeRef as? Data {
                do {
                    store = try JSONDecoder().decode([String: String].self, from: data)
                } catch {
                    store = [:]
                }
            } else {
                store = [:]
            }
        }

        return store![key]
    }
}
