import Foundation
import KeychainAccess

@MainActor
final class KeychainService {
    private let keychain = Keychain(service: "com.vaizor.app")

    func getApiKey(for provider: LLMProvider) -> String? {
        do {
            return try keychain.get(provider.rawValue)
        } catch {
            AppLogger.shared.logError(error, context: "Failed to read API key for \(provider.rawValue)")
            return nil
        }
    }

    func setApiKey(_ key: String, for provider: LLMProvider) {
        do {
            try keychain.set(key, key: provider.rawValue)
        } catch {
            AppLogger.shared.logError(error, context: "Failed to save API key for \(provider.rawValue)")
        }
    }

    func removeApiKey(for provider: LLMProvider) {
        do {
            try keychain.remove(provider.rawValue)
        } catch {
            AppLogger.shared.logError(error, context: "Failed to remove API key for \(provider.rawValue)")
        }
    }
}
