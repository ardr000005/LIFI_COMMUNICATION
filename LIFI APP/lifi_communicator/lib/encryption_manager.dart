import 'dart:convert';

class EncryptionManager {
  // Simple and reliable encryption with shorter output
  String encrypt(String plaintext, String key) {
    try {
      final keyBytes = _deriveKeyBytes(key);
      final plaintextBytes = utf8.encode(plaintext);
      final encryptedBytes = List<int>.filled(plaintextBytes.length, 0);

      // Simple addition-based encryption
      for (int i = 0; i < plaintextBytes.length; i++) {
        encryptedBytes[i] =
            (plaintextBytes[i] + keyBytes[i % keyBytes.length]) % 256;
      }

      return base64Url.encode(encryptedBytes);
    } catch (e) {
      throw Exception('Encryption failed: $e');
    }
  }

  String decrypt(String encryptedData, String key) {
    try {
      final keyBytes = _deriveKeyBytes(key);
      final encryptedBytes = base64Url.decode(encryptedData);
      final decryptedBytes = List<int>.filled(encryptedBytes.length, 0);

      // Reverse the encryption
      for (int i = 0; i < encryptedBytes.length; i++) {
        decryptedBytes[i] =
            (encryptedBytes[i] - keyBytes[i % keyBytes.length] + 256) % 256;
      }

      return utf8.decode(decryptedBytes);
    } catch (e) {
      throw Exception('Decryption failed: $e');
    }
  }

  List<int> _deriveKeyBytes(String key) {
    // Create a consistent 16-byte key from the input key
    final keyBytes = utf8.encode(key);
    final derivedKey = List<int>.filled(16, 0);

    for (int i = 0; i < 16; i++) {
      derivedKey[i] = keyBytes[i % keyBytes.length];
    }

    return derivedKey;
  }

  // Test method to verify encryption/decryption works
  void testEncryption(String testMessage, String key) {
    print("=== Testing Encryption ===");
    print("Original: '$testMessage' (${testMessage.length} chars)");

    String encrypted = encrypt(testMessage, key);
    print("Encrypted: '$encrypted' (${encrypted.length} chars)");

    String decrypted = decrypt(encrypted, key);
    print("Decrypted: '$decrypted'");
    print("Success: ${testMessage == decrypted}");
    print("========================");
  }
}
