import 'package:feishin_remote/feishin_remote.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeRemoteUri', () {
    test('should create WebSocket URI when HTTP URL has no scheme', () {
      // Arrange
      const input = '192.168.1.20:9180';

      // Act
      final uri = normalizeRemoteUri(input);

      // Assert
      expect(uri, Uri.parse('ws://192.168.1.20:9180/'));
    });

    test('should reject unsupported URL when scheme is invalid', () {
      // Arrange
      const input = 'ftp://192.168.1.20:9180';

      // Act
      Uri parse() => normalizeRemoteUri(input);

      // Assert
      expect(parse, throwsFormatException);
    });
  });

  group('reconnectDelay', () {
    test('should exponentially back off and cap retries at thirty seconds', () {
      // Arrange
      const attempts = [0, 1, 2, 3, 4, 8];

      // Act
      final delays = attempts.map(reconnectDelay).toList();

      // Assert
      expect(delays, const [
        Duration(seconds: 2),
        Duration(seconds: 4),
        Duration(seconds: 8),
        Duration(seconds: 16),
        Duration(seconds: 30),
        Duration(seconds: 30),
      ]);
    });
  });

  group('FeishinState', () {
    test('should replace playback data when state event arrives', () {
      // Arrange
      const event = <String, Object?>{
        'event': 'state',
        'data': <String, Object?>{
          'position': 12.5,
          'repeat': 'all',
          'shuffle': true,
          'status': 'playing',
          'volume': 42,
          'song': <String, Object?>{
            'id': 'song-1',
            'name': 'Signal',
            'album': 'Remote',
            'artistName': 'Feishin',
            'duration': 180000,
            'userFavorite': true,
            'userRating': 4,
            'releaseYear': 2025,
            'genres': <Object?>[
              <String, Object?>{'id': 'genre-1', 'name': 'Electronic'},
            ],
            'bitRate': 320,
            'sampleRate': 48000,
            'bitDepth': 24,
            'playCount': 7,
            'container': 'flac',
            'trackNumber': 3,
            'discNumber': 1,
          },
        },
      };

      // Act
      final state = emptyFeishinState.apply(event);

      // Assert
      expect(
        (
          state.position,
          state.repeat,
          state.shuffle,
          state.status,
          state.volume,
          state.song?.id,
          state.song?.name,
          state.song?.album,
          state.song?.artistName,
          state.song?.durationMs,
          state.song?.favorite,
          state.song?.rating,
          state.song?.details.releaseYear,
          state.song?.details.genres,
          state.song?.details.bitRate,
          state.song?.details.sampleRate,
          state.song?.details.bitDepth,
          state.song?.details.playCount,
          state.song?.details.container,
          state.song?.details.trackNumber,
          state.song?.details.discNumber,
        ),
        (
          12.5,
          'all',
          true,
          'playing',
          42.0,
          'song-1',
          'Signal',
          'Remote',
          'Feishin',
          180000,
          true,
          4.0,
          2025,
          'Electronic',
          320,
          48000,
          24,
          7,
          'flac',
          3,
          1,
        ),
      );
    });

    test('should merge incremental events when playback changes', () {
      // Arrange
      final state = emptyFeishinState.apply(const <String, Object?>{
        'event': 'song',
        'data': <String, Object?>{
          'id': 'song-1',
          'name': 'Signal',
          'duration': 180000,
        },
      });

      // Act
      final updated = state
          .apply(const <String, Object?>{'event': 'volume', 'data': 73})
          .apply(const <String, Object?>{
            'event': 'playback',
            'data': 'paused',
          });

      // Assert
      expect(
        (updated.status, updated.volume, updated.song?.id, updated.song?.name),
        ('paused', 73.0, 'song-1', 'Signal'),
      );
    });
  });
}
