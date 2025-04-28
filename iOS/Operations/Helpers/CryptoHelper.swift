import CommonCrypto
import Foundation

/// Helper for basic cryptography operations using native iOS libraries
class CryptoHelper {
    // Singleton instance
    static let shared = CryptoHelper()

    private init() {}

    // MARK: - Encryption Methods

    /// Encrypt data using AES with a password
    /// - Parameters:
    ///   - data: Data to encrypt
    ///   - password: Password for encryption
    /// - Returns: Encrypted data as a base64 string
    func encryptAES(_ data: Data, password: String) -> String? {
        // Generate a key from the password
        guard let key = deriveKeyData(from: password, salt: "backdoorsalt", keyLength: 32) else {
            Debug.shared.log(message: "Key derivation failed for encryption", type: .error)
            return nil
        }

        // Generate random IV
        let iv = generateRandomBytes(length: 16)

        // Create a mutable data to store the cipher text
        let cipherData = NSMutableData()

        // Reserve space for the IV at the beginning
        cipherData.append(iv)

        // Create a buffer for the ciphertext
        let bufferSize = data.count + kCCBlockSizeAES128
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        // Perform the encryption
        var numBytesEncrypted = 0

        let cryptStatus = key.withUnsafeBytes { keyBytes in
            iv.withUnsafeBytes { ivBytes in
                data.withUnsafeBytes { dataBytes in
                    CCCrypt(
                        CCOperation(kCCEncrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionPKCS7Padding),
                        keyBytes.baseAddress, key.count,
                        ivBytes.baseAddress,
                        dataBytes.baseAddress, data.count,
                        &buffer, bufferSize,
                        &numBytesEncrypted
                    )
                }
            }
        }

        // Check encryption status
        if cryptStatus == kCCSuccess {
            // Append the encrypted data to the IV
            cipherData.append(buffer, length: numBytesEncrypted)

            // Return as base64 string
            return cipherData.base64EncodedString()
        } else {
            Debug.shared.log(message: "AES encryption failed with error: \(cryptStatus)", type: .error)
            return nil
        }
    }
    
    // MARK: - Helper Methods
    
    /// Derive a key from a password using PBKDF2
    /// - Parameters:
    ///   - password: The password to derive the key from
    ///   - salt: Salt for the key derivation
    ///   - keyLength: Length of the key to generate in bytes
    /// - Returns: The derived key as Data
    func deriveKeyData(from password: String, salt: String, keyLength: Int) -> Data? {
        guard let passwordData = password.data(using: .utf8),
              let saltData = salt.data(using: .utf8) else {
            return nil
        }
        
        var derivedKeyData = Data(count: keyLength)
        
        let derivationStatus = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
            passwordData.withUnsafeBytes { passwordBytes in
                saltData.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress, passwordData.count,
                        saltBytes.baseAddress, saltData.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        10000,
                        derivedKeyBytes.baseAddress, keyLength
                    )
                }
            }
        }
        
        return derivationStatus == kCCSuccess ? derivedKeyData : nil
    }
    
    /// Generate random bytes for cryptographic operations
    /// - Parameter length: Number of random bytes to generate
    /// - Returns: Data containing random bytes
    func generateRandomBytes(length: Int) -> Data {
        var randomBytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, length, &randomBytes)
        
        if status == errSecSuccess {
            return Data(randomBytes)
        } else {
            // Fallback to less secure but functional method if SecRandomCopyBytes fails
            for i in 0..<length {
                randomBytes[i] = UInt8.random(in: 0...255)
            }
            return Data(randomBytes)
        }
    }
    
    /// Calculate CRC32 checksum for data
    /// - Parameter data: The data to calculate checksum for
    /// - Returns: CRC32 checksum as UInt32
    func crc32(of data: Data) -> UInt32 {
        // Initialize with all bits set
        var checksum: UInt32 = 0xFFFFFFFF
        
        // Process each byte
        data.forEach { byte in
            var c = checksum ^ UInt32(byte)
            for _ in 0..<8 {
                // Fix type conversion issues by explicitly casting to UInt32
                let mask: UInt32 = (c & 1 == 0) ? 0 : 0xEDB88320
                c = (c >> 1) ^ mask
            }
            checksum = c
        }
        
        // Return one's complement
        return ~checksum
    }
}
