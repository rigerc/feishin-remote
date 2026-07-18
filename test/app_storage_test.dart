import 'package:feishin_remote/app_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('saved server serialization', () {
    test('should preserve profile fields when JSON is decoded', () {
      // Arrange
      const server = (
        id: 'home',
        endpoint: 'http://192.168.1.20:4333',
        username: 'remote',
      );

      // Act
      final decoded = decodeSavedServer(encodeSavedServer(server));

      // Assert
      expect(decoded, server);
    });

    test('should reject malformed profile when required fields are absent', () {
      // Arrange
      const encoded = '{"id":"home"}';

      // Act
      final decoded = decodeSavedServer(encoded);

      // Assert
      expect(decoded, isNull);
    });
  });
}
