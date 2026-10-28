import Foundation
import Security

class KeychainManager {
    
    enum KeychainError: Error {
        case duplicateEntry
        case itemNotFound
        case unknown(OSStatus)
        case failedToConvertPassword
    }
    
    
    static func storeCredentials(username: String, password: String) -> Bool {
        let service = "com.olimel.abra"
        let account = "credentials"


        let credentials = "\(username):\(password)"
        guard let credentialsData = credentials.data(using: .utf8) else {
            return false
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: credentialsData
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    static func deleteCredentials() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.olimel.abra",
            kSecAttrAccount as String: "credentials"
        ]

        let status = SecItemDelete(query as CFDictionary)
    }
    
    static func retrieveCredentials() -> (username: String, password: String)? {
        let service = "com.olimel.abra"
        let account = "credentials"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let retrievedData = item as? Data,
              let credentials = String(data: retrievedData, encoding: .utf8) else {
            return nil
        }

        let credentialsArray = credentials.split(separator: ":")
        guard credentialsArray.count == 2 else {
            return nil
        }

        let username = String(credentialsArray[0])
        let password = String(credentialsArray[1])

        return (username, password)
    }

    
    static func saveSessionId(_ sessionId: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.olimel.abra",
            kSecAttrAccount as String: "SessionID",
            kSecValueData as String: sessionId.data(using: .utf8)!
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            try updateSessionId(sessionId)
        } else if status != errSecSuccess {
            throw KeychainError.unknown(status)
        }
    }
    
    static func retrieveSessionId() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.olimel.abra",
            kSecAttrAccount as String: "SessionID",
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess else {
            return nil
        }
        
        guard let sessionData = item as? Data,
              let sessionId = String(data: sessionData, encoding: .utf8)
        else {
            return nil
        }
        
        return sessionId
    }
    
    static func updateSessionId(_ newSessionId: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.olimel.abra",
            kSecAttrAccount as String: "SessionID"
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: newSessionId.data(using: .utf8)!
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        guard status != errSecItemNotFound else {
            throw KeychainError.itemNotFound
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.unknown(status)
        }
    }
    
    static func deleteSessionId() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.olimel.abra",
            kSecAttrAccount as String: "SessionID"
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }
}
