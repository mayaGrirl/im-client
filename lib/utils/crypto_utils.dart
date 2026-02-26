/// AES-256-GCM transport encryption utilities.
/// Wire format: {"_e": "<base64(nonce[12] + ciphertext + tag[16])>"}

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

class CryptoUtils {
  static Uint8List? _key;
  static final _secureRandom = _createSecureRandom();

  /// Initialize with a 64-char hex key.
  static void init(String hexKey) {
    if (hexKey.isEmpty) return;
    if (hexKey.length != 64) {
      throw ArgumentError('Encryption key must be 64 hex characters (32 bytes)');
    }
    _key = _hexDecode(hexKey);
  }

  /// Whether encryption has been initialized.
  static bool get isInitialized => _key != null;

  /// Encrypt plaintext bytes → base64 string.
  static String encrypt(List<int> plaintext) {
    if (_key == null) throw StateError('CryptoUtils not initialized');

    // Generate 12-byte random nonce
    final nonce = _secureRandom.nextBytes(12);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(_key!),
          128, // tag length in bits
          nonce,
          Uint8List(0),
        ),
      );

    final input = Uint8List.fromList(plaintext);
    final output = Uint8List(cipher.getOutputSize(input.length));
    final len = cipher.processBytes(input, 0, input.length, output, 0);
    cipher.doFinal(output, len);

    // Combine: nonce[12] + ciphertext + tag[16]
    final result = Uint8List(nonce.length + output.length);
    result.setRange(0, nonce.length, nonce);
    result.setRange(nonce.length, result.length, output);

    return base64Encode(result);
  }

  /// Decrypt base64 string → plaintext bytes.
  static List<int> decrypt(String encoded) {
    if (_key == null) throw StateError('CryptoUtils not initialized');

    final data = base64Decode(encoded);
    if (data.length < 12) throw FormatException('Ciphertext too short');

    final nonce = Uint8List.sublistView(data, 0, 12);
    final ciphertext = Uint8List.sublistView(data, 12);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(
          KeyParameter(_key!),
          128,
          nonce,
          Uint8List(0),
        ),
      );

    final output = Uint8List(cipher.getOutputSize(ciphertext.length));
    var offset = cipher.processBytes(ciphertext, 0, ciphertext.length, output, 0);
    offset += cipher.doFinal(output, offset);

    return output.sublist(0, offset);
  }

  /// Encrypt a JSON map → {"_e": "..."}.
  static Map<String, dynamic> encryptJson(Map<String, dynamic> data) {
    final plaintext = utf8.encode(jsonEncode(data));
    return {'_e': encrypt(plaintext)};
  }

  /// Try to decrypt {"_e": "..."} → original map. Returns null if not encrypted.
  static Map<String, dynamic>? tryDecryptJson(Map<String, dynamic> data) {
    final encoded = data['_e'];
    if (encoded == null || encoded is! String) return null;

    try {
      final plaintext = decrypt(encoded);
      final json = jsonDecode(utf8.decode(plaintext));
      if (json is Map<String, dynamic>) return json;
      return null;
    } catch (e) {
      print('[CryptoUtils] Decryption failed: $e');
      return null;
    }
  }

  /// Decode hex string to bytes.
  static Uint8List _hexDecode(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  /// Create a platform-compatible SecureRandom for PointyCastle.
  static SecureRandom _createSecureRandom() {
    final random = Random.secure();
    final seeds = List<int>.generate(32, (_) => random.nextInt(256));
    final secureRandom = FortunaRandom()
      ..seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }
}
