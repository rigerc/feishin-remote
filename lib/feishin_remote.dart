import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

typedef FeishinTrackDetails = ({
  int releaseYear,
  String genres,
  int bitRate,
  int sampleRate,
  int bitDepth,
  int playCount,
  String container,
  int trackNumber,
  int discNumber,
});

typedef FeishinSong = ({
  String id,
  String name,
  String album,
  String artistName,
  int durationMs,
  bool favorite,
  double rating,
  Uint8List? artworkBytes,
  FeishinTrackDetails details,
});

typedef FeishinState = ({
  double position,
  String repeat,
  bool shuffle,
  String status,
  double volume,
  FeishinSong? song,
});

typedef _ConnectionConfig = ({
  String endpoint,
  String username,
  String password,
});

const emptyFeishinState = (
  position: 0.0,
  repeat: 'none',
  shuffle: false,
  status: 'stopped',
  volume: 0.0,
  song: null,
);

const _reconnectSeconds = [2, 4, 8, 16, 30];
const _maxReconnectAttempts = 8;

Duration reconnectDelay(int attempt) {
  final index = attempt.clamp(0, _reconnectSeconds.length - 1);
  return Duration(seconds: _reconnectSeconds[index]);
}

Uri normalizeRemoteUri(String input) {
  final value = input.trim();
  if (value.isEmpty) throw const FormatException('Enter a Feishin Remote URL.');

  final withScheme = value.contains('://') ? value : 'http://$value';
  final parsed = Uri.parse(withScheme);
  final scheme = switch (parsed.scheme.toLowerCase()) {
    'http' || 'ws' => 'ws',
    'https' || 'wss' => 'wss',
    _ => throw const FormatException('Use an HTTP, HTTPS, WS, or WSS URL.'),
  };

  if (parsed.host.isEmpty) {
    throw const FormatException('Enter a valid host name or IP address.');
  }

  return parsed.replace(
    scheme: scheme,
    path: parsed.path.isEmpty ? '/' : parsed.path,
    query: null,
    fragment: null,
  );
}

extension FeishinStateEvents on FeishinState {
  FeishinState apply(Map<String, Object?> message) {
    final event = message['event'];
    final data = message['data'];

    return switch (event) {
      'state' => _stateFrom(data),
      'song' => _copyState(this, song: _songFrom(data), replaceSong: true),
      'playback' => _copyState(this, status: _text(data, status)),
      'position' => _copyState(this, position: _number(data, position)),
      'volume' => _copyState(this, volume: _number(data, volume)),
      'repeat' => _copyState(this, repeat: _text(data, repeat)),
      'shuffle' => _copyState(this, shuffle: data is bool ? data : shuffle),
      'proxy' => _applyArtwork(this, data),
      'favorite' => _applyFavorite(this, data),
      'rating' => _applyRating(this, data),
      _ => this,
    };
  }
}

FeishinState _stateFrom(Object? value) {
  final data = _objectMap(value);
  return (
    position: _number(data['position'], 0),
    repeat: _text(data['repeat'], 'none'),
    shuffle: data['shuffle'] is bool ? data['shuffle'] as bool : false,
    status: _text(data['status'], 'stopped'),
    volume: _number(data['volume'], 0),
    song: _songFrom(data['song']),
  );
}

FeishinSong? _songFrom(Object? value) {
  if (value == null) return null;

  final data = _objectMap(value);
  final id = _text(data['id'], '');
  if (id.isEmpty) return null;

  return (
    id: id,
    name: _text(data['name'], 'Unknown track'),
    album: _text(data['album'], ''),
    artistName: _text(data['artistName'], ''),
    durationMs: _integer(data['duration'], 0),
    favorite: data['userFavorite'] is bool
        ? data['userFavorite'] as bool
        : false,
    rating: _number(data['userRating'], 0),
    artworkBytes: null,
    details: (
      releaseYear: _integer(data['releaseYear'], 0),
      genres: _genreNames(data['genres']),
      bitRate: _integer(data['bitRate'], 0),
      sampleRate: _integer(data['sampleRate'], 0),
      bitDepth: _integer(data['bitDepth'], 0),
      playCount: _integer(data['playCount'], 0),
      container: _text(data['container'], ''),
      trackNumber: _integer(data['trackNumber'], 0),
      discNumber: _integer(data['discNumber'], 0),
    ),
  );
}

FeishinState _copyState(
  FeishinState current, {
  double? position,
  String? repeat,
  bool? shuffle,
  String? status,
  double? volume,
  FeishinSong? song,
  bool replaceSong = false,
}) => (
  position: position ?? current.position,
  repeat: repeat ?? current.repeat,
  shuffle: shuffle ?? current.shuffle,
  status: status ?? current.status,
  volume: volume ?? current.volume,
  song: replaceSong ? song : current.song,
);

FeishinState _applyArtwork(FeishinState current, Object? value) {
  final song = current.song;
  if (song == null || value is! String) return current;

  return _copyState(
    current,
    replaceSong: true,
    song: (
      id: song.id,
      name: song.name,
      album: song.album,
      artistName: song.artistName,
      durationMs: song.durationMs,
      favorite: song.favorite,
      rating: song.rating,
      artworkBytes: base64Decode(value),
      details: song.details,
    ),
  );
}

FeishinState _applyFavorite(FeishinState current, Object? value) {
  final song = current.song;
  final data = _objectMap(value);
  if (song == null || data['id'] != song.id || data['favorite'] is! bool) {
    return current;
  }

  return _copyState(
    current,
    replaceSong: true,
    song: (
      id: song.id,
      name: song.name,
      album: song.album,
      artistName: song.artistName,
      durationMs: song.durationMs,
      favorite: data['favorite'] as bool,
      rating: song.rating,
      artworkBytes: song.artworkBytes,
      details: song.details,
    ),
  );
}

FeishinState _applyRating(FeishinState current, Object? value) {
  final song = current.song;
  final data = _objectMap(value);
  if (song == null || data['id'] != song.id || data['rating'] is! num) {
    return current;
  }

  return _copyState(
    current,
    replaceSong: true,
    song: (
      id: song.id,
      name: song.name,
      album: song.album,
      artistName: song.artistName,
      durationMs: song.durationMs,
      favorite: song.favorite,
      rating: (data['rating'] as num).toDouble(),
      artworkBytes: song.artworkBytes,
      details: song.details,
    ),
  );
}

String _genreNames(Object? value) {
  if (value is! List<Object?>) return '';
  return value
      .map(_objectMap)
      .map((genre) => genre['name'])
      .whereType<String>()
      .where((name) => name.isNotEmpty)
      .join(', ');
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is! Map<Object?, Object?>) return const {};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

double _number(Object? value, double fallback) =>
    value is num ? value.toDouble() : fallback;

int _integer(Object? value, int fallback) =>
    value is num ? value.toInt() : fallback;

String _text(Object? value, String fallback) =>
    value is String ? value : fallback;

enum RemoteConnection { disconnected, connecting, reconnecting, connected }

class FeishinRemoteClient extends ChangeNotifier {
  WebSocket? _socket;
  Timer? _reconnectTimer;
  _ConnectionConfig? _config;
  int _reconnectAttempt = 0;
  bool _manualDisconnect = true;
  bool _usedCredentials = false;

  FeishinState state = emptyFeishinState;
  RemoteConnection connection = RemoteConnection.disconnected;
  String? errorMessage;

  Future<void> connect({
    required String endpoint,
    String username = '',
    String password = '',
  }) async {
    try {
      normalizeRemoteUri(endpoint);
    } on FormatException catch (error) {
      _setDisconnected(error.message);
      return;
    }

    _manualDisconnect = false;
    _config = (endpoint: endpoint, username: username, password: password);
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();
    await _openConnection(reconnecting: false);
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _config = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final socket = _socket;
    _socket = null;
    if (socket != null) await socket.close(4001, 'Disconnected by user');
    state = emptyFeishinState;
    connection = RemoteConnection.disconnected;
    errorMessage = null;
    notifyListeners();
  }

  void send(String event, [Map<String, Object?> data = const {}]) {
    final socket = _socket;
    if (socket == null || socket.readyState != WebSocket.open) {
      if (connection != RemoteConnection.reconnecting) {
        errorMessage = 'Connect to Feishin first.';
        notifyListeners();
      }
      return;
    }

    socket.add(jsonEncode(<String, Object?>{'event': event, ...data}));
  }

  Future<void> _openConnection({required bool reconnecting}) async {
    final config = _config;
    if (_manualDisconnect || config == null) return;

    final previousSocket = _socket;
    _socket = null;
    if (previousSocket != null) {
      await previousSocket.close(4001, 'Reconnecting');
    }

    connection = reconnecting
        ? RemoteConnection.reconnecting
        : RemoteConnection.connecting;
    if (!reconnecting) errorMessage = null;
    notifyListeners();

    try {
      final uri = normalizeRemoteUri(config.endpoint);
      final socket = await WebSocket.connect(uri.toString());
      if (_manualDisconnect || config != _config) {
        await socket.close(4001, 'Connection superseded');
        return;
      }

      _socket = socket;
      _usedCredentials =
          config.username.isNotEmpty || config.password.isNotEmpty;
      _reconnectAttempt = 0;
      connection = RemoteConnection.connected;
      errorMessage = null;
      notifyListeners();

      if (_usedCredentials) {
        final header =
            'Basic ${base64Encode(utf8.encode('${config.username}:${config.password}'))}';
        socket.add(
          jsonEncode(<String, Object?>{
            'event': 'authenticate',
            'header': header,
          }),
        );
      }

      socket.listen(
        (Object? message) => _onMessage(socket, message),
        onError: (Object error) => _onSocketError(socket),
        onDone: () => _onSocketDone(socket),
      );
    } on SocketException catch (_) {
      _scheduleReconnect('Could not reach Feishin.');
    } on WebSocketException catch (_) {
      _scheduleReconnect('Feishin rejected the WebSocket connection.');
    } catch (_) {
      _scheduleReconnect('Could not connect to Feishin.');
    }
  }

  void _onMessage(WebSocket socket, Object? rawMessage) {
    if (!identical(_socket, socket)) return;

    try {
      final text = switch (rawMessage) {
        String value => value,
        List<int> bytes => utf8.decode(bytes),
        _ => '',
      };
      final Object? decoded = jsonDecode(text);
      final message = _objectMap(decoded);
      final previousSongId = state.song?.id;
      state = state.apply(message);
      errorMessage = message['event'] == 'error'
          ? _text(message['data'], 'Remote error')
          : null;
      notifyListeners();

      if (state.song?.id != null && state.song?.id != previousSongId) {
        send('proxy');
      }
    } on FormatException catch (_) {
      errorMessage = 'Feishin sent an invalid response.';
      notifyListeners();
    }
  }

  void _onSocketError(WebSocket socket) {
    if (!identical(_socket, socket)) return;
    _socket = null;
    _scheduleReconnect('The Feishin connection failed.');
  }

  void _onSocketDone(WebSocket socket) {
    if (!identical(_socket, socket)) return;
    _socket = null;
    final message = _usedCredentials
        ? 'Connection closed. Check the Remote credentials.'
        : 'Connection closed by Feishin.';
    _scheduleReconnect(message);
  }

  void _scheduleReconnect(String message) {
    if (_manualDisconnect || _config == null) {
      _setDisconnected(message);
      return;
    }
    if (_reconnectTimer?.isActive ?? false) return;
    if (_reconnectAttempt >= _maxReconnectAttempts) {
      _setDisconnected('$message Automatic reconnect stopped.');
      return;
    }

    final delay = reconnectDelay(_reconnectAttempt);
    _reconnectAttempt += 1;
    connection = RemoteConnection.reconnecting;
    errorMessage = '$message Reconnecting in ${delay.inSeconds}s…';
    notifyListeners();
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      unawaited(_openConnection(reconnecting: true));
    });
  }

  void _setDisconnected(String message) {
    _socket = null;
    connection = RemoteConnection.disconnected;
    errorMessage = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    unawaited(_socket?.close(4001, 'App closed'));
    super.dispose();
  }
}
