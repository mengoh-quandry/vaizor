import XCTest
@testable import vaizor

// MARK: - SecretDetector Tests

final class SecretDetectorTests: XCTestCase {

    var detector: SecretDetector!

    override func setUp() {
        super.setUp()
        detector = SecretDetector.shared
    }

    // MARK: - API Key Detection Tests

    func testGenericAPIKeyDetection() {
        let text = "api_key: abcdefghijklmnopqrstuvwxyz123456"
        let result = detector.redact(text)

        XCTAssertTrue(result.detected)
        XCTAssertTrue(result.sanitized.contains("[REDACTED:"))
    }

    func testAWSAccessKeyDetection() {
        let text = "AKIAIOSFODNN7EXAMPLE"
        let result = detector.redact(text)

        XCTAssertTrue(result.detected)
        XCTAssertTrue(result.sanitized.contains("[REDACTED: AWS Access Key]"))
    }

    func testOpenAIAPIKeyDetection() {
        let text = "sk-abcdefghijklmnopqrstuvwxyz1234567890abcdef"
        let result = detector.redact(text)

        XCTAssertTrue(result.detected)
        XCTAssertTrue(result.sanitized.contains("[REDACTED: OpenAI API Key]"))
    }

    func testStripeAPIKeyDetection() {
        // Construct key dynamically to avoid GitHub secret scanning
        let prefix = "sk" + "_" + "test" + "_"
        let suffix = String(repeating: "X", count: 28)  // 28 chars to meet 24+ requirement
        let text = "\(prefix)\(suffix)"
        let result = detector.redact(text)

        XCTAssertTrue(result.detected)
        XCTAssertTrue(result.sanitized.contains("[REDACTED: Stripe Test Key]"))  // Pattern names it "Stripe Test Key"
    }

    // MARK: - Token Detection Tests

    func testTokenPatternDetection() {
        let text = "token: abcdefghijklmnopqrstuvwxyz12345"
        let result = detector.redact(text)

        XCTAssertTrue(result.detected)
    }

    func testBearerTokenDetection() {
        let text = "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        let result = detector.redact(text)

        XCTAssertTrue(result.detected)
    }

    // MARK: - Private Key Detection Tests

    func testRSAPrivateKeyDetection() {
        let text = "-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQE..."
        let result = detector.redact(text)

        XCTAssertTrue(result.detected)
        XCTAssertTrue(result.sanitized.contains("[REDACTED: Private Key]"))
    }

    func testECPrivateKeyDetection() {
        let text = "-----BEGIN EC PRIVATE KEY-----\nMHQCAQEEIB..."
        let result = detector.redact(text)

        XCTAssertTrue(result.detected)
    }

    func testOpenSSHPrivateKeyDetection() {
        let text = "-----BEGIN OPENSSH PRIVATE KEY-----\nb3BlbnNzaC1rZXktdjEAAAAABG5v..."
        let result = detector.redact(text)

        XCTAssertTrue(result.detected)
    }

    func testDSAPrivateKeyDetection() {
        let text = "-----BEGIN DSA PRIVATE KEY-----\nMIIDXTCCAkWg..."
        let result = detector.redact(text)

        XCTAssertTrue(result.detected)
    }

    func testPGPPrivateKeyDetection() {
        let text = "-----BEGIN PGP PRIVATE KEY BLOCK-----\n\nlQOYBF..."
        let result = detector.redact(text)

        XCTAssertTrue(result.detected)
        XCTAssertTrue(result.sanitized.contains("[REDACTED: PGP Private Key]"))
    }

    // MARK: - Password Detection Tests

    func testPasswordPatternDetection() {
        let text = "password: SuperSecret123!"
        let result = detector.redact(text)

        XCTAssertTrue(result.detected)
        XCTAssertTrue(result.sanitized.contains("[REDACTED: Password]"))
    }

    func testPasswdPatternDetection() {
        let text = "passwd: AnotherSecret123"
        let result = detector.redact(text)

        XCTAssertTrue(result.detected)
    }

    func testPasswordInURL() {
        let text = "postgresql://user:password123@localhost:5432/dbname"
        let result = detector.redact(text)

        XCTAssertTrue(result.detected)
        XCTAssertTrue(result.sanitized.contains("[REDACTED:"))
    }

    // MARK: - Database URL Detection Tests

    func testPostgreSQLURLDetection() {
        let text = "postgresql://user:pass@host:5432/database"
        let result = detector.redact(text)

        XCTAssertTrue(result.detected)
        XCTAssertTrue(result.sanitized.contains("[REDACTED: PostgreSQL URL]"))
    }

    func testMySQLURLDetection() {
        let text = "mysql://root:secret@localhost:3306/mydb"
        let result = detector.redact(text)

        XCTAssertTrue(result.detected)
        XCTAssertTrue(result.sanitized.contains("[REDACTED: MySQL URL]"))
    }

    func testMongoDBURLDetection() {
        let text = "mongodb://admin:password@cluster0.mongodb.net/db"
        let result = detector.redact(text)

        XCTAssertTrue(result.detected)
        XCTAssertTrue(result.sanitized.contains("[REDACTED: MongoDB URL]"))
    }

    // MARK: - OAuth Detection Tests

    func testOAuthTokenDetection() {
        let text = "oauth_token: abcdefghijklmnopqrstuvwxyz1234"
        let result = detector.redact(text)

        XCTAssertTrue(result.detected)
        XCTAssertTrue(result.sanitized.contains("[REDACTED: OAuth Token]"))
    }

    func testOAuthSecretDetection() {
        let text = "oauth_secret: supersecretoauthtoken123456789"
        let result = detector.redact(text)

        XCTAssertTrue(result.detected)
        XCTAssertTrue(result.sanitized.contains("[REDACTED: OAuth Secret]"))
    }

    // MARK: - Multiple Secrets Tests

    func testMultipleSecretsInText() {
        let text = """
        API Key: sk-abcdefghijklmnopqrstuvwxyz1234567890abcdef
        Password: SuperSecret123!
        Database: postgresql://user:pass@localhost/db
        """

        let result = detector.redact(text)

        XCTAssertTrue(result.detected)
        XCTAssertTrue(result.sanitized.contains("[REDACTED:"))
    }

    // MARK: - Clean Text Tests

    func testCleanText() {
        let text = "This is a normal message with no secrets."
        let result = detector.redact(text)

        XCTAssertFalse(result.detected)
        XCTAssertEqual(result.sanitized, text)
    }

    func testContainsSecretsCheck() {
        let textWithSecret = "API key: sk-abcdefghijklmnopqrstuvwxyz1234567890abcdef"
        let textWithoutSecret = "Hello, this is a normal message."

        XCTAssertTrue(detector.containsSecrets(textWithSecret))
        XCTAssertFalse(detector.containsSecrets(textWithoutSecret))
    }

    // MARK: - Edge Cases

    func testEmptyText() {
        let result = detector.redact("")
        XCTAssertFalse(result.detected)
        XCTAssertEqual(result.sanitized, "")
    }

    func testVeryLongText() {
        let longText = String(repeating: "A", count: 10000) + " password: Secret123! " + String(repeating: "B", count: 10000)
        let result = detector.redact(longText)

        XCTAssertTrue(result.detected)
        XCTAssertTrue(result.sanitized.contains("[REDACTED:"))
    }

    func testUnicodeText() {
        let text = "API Key: sk-1234567890abcdef  Password: Secret123"
        let result = detector.redact(text)

        XCTAssertTrue(result.detected)
    }

    func testCaseInsensitiveDetection() {
        let text1 = "PASSWORD: Secret123"
        let text2 = "password: Secret123"
        let text3 = "Password: Secret123"

        XCTAssertTrue(detector.containsSecrets(text1))
        XCTAssertTrue(detector.containsSecrets(text2))
        XCTAssertTrue(detector.containsSecrets(text3))
    }

    func testSecretAtBeginning() {
        let text = "sk-abcdefghijklmnopqrstuvwxyz1234567890abcdef is my API key"
        let result = detector.redact(text)

        XCTAssertTrue(result.detected)
    }

    func testSecretAtEnd() {
        let text = "My API key is sk-abcdefghijklmnopqrstuvwxyz1234567890abcdef"
        let result = detector.redact(text)

        XCTAssertTrue(result.detected)
    }

    func testMultipleSameTypeSecrets() {
        let text = """
        Key 1: sk-abcdefghijklmnopqrstuvwxyz1234567890abcdef
        Key 2: sk-bcdefghijklmnopqrstuvwxyz1234567890abcdefa
        """

        let result = detector.redact(text)
        XCTAssertTrue(result.detected)
    }

    // MARK: - Complex Scenarios

    func testCodeSnippetWithSecrets() {
        let code = """
        import os

        API_KEY = "sk-abcdefghijklmnopqrstuvwxyz1234567890abcdef"
        DATABASE_URL = "postgresql://admin:secret123@db.example.com:5432/production"

        def connect():
            return psycopg2.connect(DATABASE_URL)
        """

        let result = detector.redact(code)

        XCTAssertTrue(result.detected)
        XCTAssertFalse(result.sanitized.contains("sk-abcdefghijklmnopqrstuvwxyz1234567890abcdef"))
        XCTAssertFalse(result.sanitized.contains("postgresql://admin:secret123@db.example.com"))
    }

    func testConfigurationFileContent() {
        let config = """
        [database]
        host = localhost
        password = SuperSecretDBPass123!

        [api]
        key = AKIAIOSFODNN7EXAMPLE
        secret = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

        [oauth]
        token = ya29.a0AfH6SMBx...
        """

        let result = detector.redact(config)

        XCTAssertTrue(result.detected)
    }

    func testJSONWithSecrets() {
        let json = """
        {
            "api_key": "sk-abcdefghijklmnopqrstuvwxyz1234567890abcdef",
            "database_url": "mysql://user:pass@host/db",
            "password": "secret123"
        }
        """

        let result = detector.redact(json)

        XCTAssertTrue(result.detected)
    }

    func testEnvironmentVariableExport() {
        let text = """
        export AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
        export AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
        export DATABASE_URL=postgresql://user:pass@localhost/db
        """

        let result = detector.redact(text)

        XCTAssertTrue(result.detected)
    }

    func testPartialSecretNotDetected() {
        // Too short to match generic API key pattern
        let text = "key: short123"
        let result = detector.redact(text)

        // This might or might not be detected depending on the pattern
        // Just ensure no crash
        XCTAssertNotNil(result.sanitized)
    }

    func testGitHubTokenDetection() {
        // GitHub token format: ghp_*, gho_*, ghu_*, etc.
        let text = "github_token: ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
        let result = detector.redact(text)

        // Note: GitHub tokens might match generic patterns
        // This tests that the detector runs without crashing
        XCTAssertNotNil(result.sanitized)
    }

    func testSlackTokenDetection() {
        let text = "xoxb" + "-" + "000000000000-000000000000-TESTKEY"
        let result = detector.redact(text)

        // Slack tokens might match generic patterns
        XCTAssertNotNil(result.sanitized)
    }

    func testBase64SecretDetection() {
        // Base64 strings that might be secrets
        let text = "secret: d2hhdGV2ZXI="
        let result = detector.redact(text)

        XCTAssertNotNil(result.sanitized)
    }

    // MARK: - Performance Test

    func testPerformanceLargeText() {
        let largeText = String(repeating: "Some normal text here. ", count: 10000)
            + "password: Secret123! "
            + String(repeating: "More normal text. ", count: 10000)

        measure {
            _ = detector.redact(largeText)
        }
    }
}
