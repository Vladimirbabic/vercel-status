import Foundation
import LocalAuthentication
import Security

enum KeychainStore {
    private static let service = AppConstants.keychainService
    private static let account = "vercel-token-v2"
    private static let legacyAccounts = ["vercel-token"]

    static func loadToken() -> String {
        if let token = loadToken(account: account) {
            return token
        }

        for legacyAccount in legacyAccounts {
            if let token = loadToken(account: legacyAccount) {
                saveToken(token)
                return token
            }
        }

        return ""
    }

    private static func loadToken(account: String) -> String? {
        let context = LAContext()
        context.interactionNotAllowed = true

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return token
    }

    static func saveToken(_ token: String) {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let context = LAContext()
        context.interactionNotAllowed = true

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseAuthenticationContext as String: context
        ]

        if trimmedToken.isEmpty {
            SecItemDelete(query as CFDictionary)
            return
        }

        let data = Data(trimmedToken.utf8)
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }
}
