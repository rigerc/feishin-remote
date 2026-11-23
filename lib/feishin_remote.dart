import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

part 'remote_protocol.dart';

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
  Uri? image,
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
    image: remoteImageUri(data['imageUrl']),
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

FeishinSong _withArtwork(FeishinSong song, Uint8List bytes) => (
  id: song.id,
  name: song.name,
  album: song.album,
  artistName: song.artistName,
  durationMs: song.durationMs,
  favorite: song.favorite,
  rating: song.rating,
  artworkBytes: bytes,
  image: song.image,
  details: song.details,
);

FeishinState _applyArtwork(FeishinState current, Object? value) {
  final song = current.song;
  if (song == null || value is! String) return current;
  return _copyState(
    current,
    song: _withArtwork(song, base64Decode(value)),
    replaceSong: true,
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
      image: song.image,
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
      image: song.image,
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
  if (value is Map<String, Object?>) return value;
  return const {};
}

double _number(Object? value, double fallback) =>
    value is num ? value.toDouble() : fallback;

int _integer(Object? value, int fallback) =>
    value is num ? value.toInt() : fallback;

String _text(Object? value, String fallback) =>
    value is String ? value : fallback;

enum RemoteConnection { disconnected, connecting, reconnecting, connected }

class FeishinRemoteClient extends ChangeNotifier {
  FeishinRemoteClient({
    this.requestTimeout = const Duration(seconds: 16),
    this.updateTimeout = const Duration(seconds: 6),
  });

  final Duration requestTimeout;
  final Duration updateTimeout;
  final _random = Random.secure();
  final _pending =
      <String, ({String event, Completer<Map<String, Object?>> completer})>{};
  WebSocket? _socket;
  HttpClient? _connectingClient;
  Timer? _reconnectTimer;
  Timer? _handshakeTimer;
  _ConnectionConfig? _config;
  int _reconnectAttempt = 0;
  int _session = 0;
  int? _artworkRequest;
  int _songRevision = 0;
  bool _artworkAttempted = false;
  bool _artworkWanted = false;
  bool _disposed = false;

  int get session => _session;
  bool get expanded => queue != null;
  bool get online => connection == RemoteConnection.connected;

  FeishinState state = emptyFeishinState;
  RemoteConnection connection = RemoteConnection.disconnected;
  String? errorMessage;
  RemoteQueue? queue;
  RemoteItem? _upNext;
  RemoteItem? get upNext => radio == null ? _upNext : null;
  RemoteRadio? radio;
  RemoteAccent? accent;
  bool confirmQueueChanges = true;
  double _lastVolume = 30;

  Future<void> connect({
    required String endpoint,
    String username = '',
    String password = '',
  }) async {
    _reconnectTimer?.cancel();
    _reconnectAttempt = 0;
    _resetSession();
    try {
      normalizeRemoteUri(endpoint);
    } on FormatException catch (error) {
      _config = null;
      _setDisconnected(error.message);
      return;
    }
    _config = (endpoint: endpoint, username: username, password: password);
    await _openConnection(reconnecting: false);
  }

  Future<void> disconnect() async {
    _config = null;
    _reconnectTimer?.cancel();
    final closed = _resetSession(4001);
    _setDisconnected(null);
    await closed;
  }

  void send(String event, [Map<String, Object?> data = const {}]) {
    if (!online) return;
    try {
      _write(event, data);
    } on RemoteException catch (error) {
      errorMessage = error.message;
      notifyListeners();
    }
  }

  void _write(String event, Map<String, Object?> fields) {
    final socket = _socket;
    if (socket == null || socket.readyState != WebSocket.open) {
      throw const RemoteException('Connect to Feishin first.');
    }
    try {
      socket.add(jsonEncode({'event': event, ...fields}));
    } on StateError {
      throw const RemoteException('The Feishin connection closed.');
    }
  }

  Future<RemotePage> browse(
    RemoteCatalog catalog, {
    required int offset,
    required int limit,
    required String search,
  }) async {
    final data =
        await _request('${catalog.name}-request', '${catalog.name}-response', {
          'startIndex': offset,
          'limit': limit,
          if (search.isNotEmpty) 'searchTerm': search,
        });
    try {
      return _remotePage(data);
    } on TypeError {
      throw const RemoteException('Feishin returned an invalid page.');
    }
  }

  Future<void> playItem(
    RemoteCatalog catalog,
    String id,
    RemotePlayType mode,
  ) async {
    final event = switch (catalog) {
      RemoteCatalog.tracks => 'play-track',
      RemoteCatalog.albums => 'play-album',
      RemoteCatalog.playlists => 'play-playlist',
      RemoteCatalog.radio => throw ArgumentError.value(catalog, 'catalog'),
    };
    await _operation(event, {'id': id, 'playType': mode.name});
  }

  Future<void> playTrackRadio(String songId, RemotePlayType mode) =>
      _operation('play-track-radio', {'id': songId, 'playType': mode.name});

  Future<void> addToPlaylist(String songId, String playlistId) => _operation(
    'add-to-playlist',
    {'songId': songId, 'playlistId': playlistId},
  );

  Future<void> clearQueue() => _operation('clear-queue', const {});

  Future<void> jumpTo(String id) => _observe('queue-jump', {
    'uniqueId': id,
  }, () => queue?.currentId == id && radio == null);

  Future<void> removeFromQueue(String id) => _observe('remove-from-queue', {
    'uniqueId': id,
  }, () => queue?.items.every((entry) => entry.uniqueId != id) ?? false);

  Future<void> reorderQueue(String id, String targetId, QueueEdge edge) =>
      _observe(
        'reorder-queue',
        {'uniqueId': id, 'targetUniqueId': targetId, 'edge': edge.name},
        () {
          final items = queue?.items;
          if (items == null) return false;
          final from = items.indexWhere((entry) => entry.uniqueId == id);
          final to = items.indexWhere((entry) => entry.uniqueId == targetId);
          return from >= 0 &&
              to >= 0 &&
              from == to + (edge == QueueEdge.top ? -1 : 1);
        },
      );

  Future<void> playStation(RemoteItem station) => _observe(
    'play-radio',
    {'id': station.id},
    () => radio?.name == station.name,
    alwaysSend: true,
  );

  Future<void> _observe(
    String event,
    Map<String, Object?> fields,
    bool Function() observed, {
    bool alwaysSend = false,
  }) async {
    _requireExpanded();
    if (observed()) {
      if (alwaysSend) _write(event, fields);
      return;
    }
    final session = _session;
    final result = Completer<void>();
    var previousQueue = queue;
    var previousRadio = radio;
    void check() {
      if (result.isCompleted) return;
      if (session != _session) {
        result.completeError(const RemoteException('Connection changed.'));
      } else if (!identical(previousQueue, queue) || previousRadio != radio) {
        previousQueue = queue;
        previousRadio = radio;
        if (observed()) result.complete();
      }
    }

    addListener(check);
    try {
      _write(event, fields);
      await result.future.timeout(
        updateTimeout,
        onTimeout: () => throw const RemoteException(
          'Feishin did not confirm the change. Check the current state.',
        ),
      );
    } finally {
      removeListener(check);
    }
  }

  Future<void> _operation(String event, Map<String, Object?> fields) async {
    final data = await _request(event, 'operation-ack', fields);
    if (data['error'] case final String message when message.isNotEmpty) {
      throw RemoteException(message);
    }
  }

  Future<Map<String, Object?>> _request(
    String event,
    String expected,
    Map<String, Object?> fields,
  ) async {
    _requireExpanded();
    // Feishin correlates IDs across all clients attached to the desktop.
    final id = List.generate(
      4,
      (_) => _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0'),
    ).join();
    final completer = Completer<Map<String, Object?>>();
    _pending[id] = (event: expected, completer: completer);
    try {
      _write(event, {...fields, 'requestId': id});
      return await completer.future.timeout(
        requestTimeout,
        onTimeout: () =>
            throw const RemoteException('Feishin did not respond in time.'),
      );
    } finally {
      _pending.remove(id);
    }
  }

  void _requireExpanded() {
    if (!online || !expanded) {
      throw const RemoteException('Connect to Feishin 1.16 or later first.');
    }
  }

  void toggleMute() =>
      send('volume', {'volume': state.volume > 0 ? 0 : _lastVolume});

  void requestArtwork() {
    if (!online ||
        radio != null ||
        state.song?.image == null ||
        _artworkAttempted) {
      return;
    }
    if (_artworkRequest != null) {
      _artworkWanted = true;
      return;
    }
    _artworkWanted = false;
    _artworkAttempted = true;
    _artworkRequest = _songRevision;
    send('proxy');
  }

  Future<void> _openConnection({required bool reconnecting}) async {
    final config = _config;
    if (config == null || _disposed) return;
    final session = _session;
    connection = reconnecting
        ? RemoteConnection.reconnecting
        : RemoteConnection.connecting;
    if (!reconnecting) errorMessage = null;
    notifyListeners();

    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    _connectingClient = httpClient;
    try {
      final uri = normalizeRemoteUri(config.endpoint);
      final socket =
          await WebSocket.connect(
            uri.toString(),
            customClient: httpClient,
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              httpClient.close(force: true);
              throw TimeoutException('WebSocket connection timed out.');
            },
          );
      if (_disposed || session != _session) {
        await socket.close(4001, 'Connection superseded');
        return;
      }
      _socket = socket;
      socket.listen(
        (Object? message) => _onMessage(socket, message),
        onError: (Object error) => _onSocketClosed(socket, failed: true),
        onDone: () => _onSocketClosed(socket),
      );
      if (config.username.isNotEmpty || config.password.isNotEmpty) {
        final header = base64Encode(
          utf8.encode('${config.username}:${config.password}'),
        );
        _write('authenticate', {'header': 'Basic $header'});
      }
      _handshakeTimer = Timer(const Duration(seconds: 12), () {
        if (identical(_socket, socket) && !online) {
          _onSocketClosed(socket, failed: true);
        }
      });
    } catch (_) {
      if (!_disposed && session == _session) {
        _resetSession();
        _scheduleReconnect('Could not connect to Feishin.');
      }
    } finally {
      if (identical(_connectingClient, httpClient)) _connectingClient = null;
      httpClient.close();
    }
  }

  void _onMessage(WebSocket socket, Object? rawMessage) {
    if (!identical(_socket, socket)) return;
    try {
      final text = switch (rawMessage) {
        String value => value,
        List<int> bytes => utf8.decode(bytes),
        _ => throw const FormatException(),
      };
      final message = _objectMap(jsonDecode(text));
      final event = message['event'];
      final data = message['data'];
      final fields = _objectMap(data);
      if (fields['requestId'] case final String id) {
        final pending = _pending[id];
        if (pending != null &&
            pending.event == event &&
            !pending.completer.isCompleted) {
          pending.completer.complete(fields);
        }
        return;
      }

      switch (event) {
        case 'queue-state':
          final snapshot = _remoteQueue(fields);
          queue = snapshot;
          final index = snapshot.currentId == null
              ? -1
              : snapshot.items.indexWhere(
                  (entry) => entry.uniqueId == snapshot.currentId,
                );
          _upNext = index >= 0 && index + 1 < snapshot.items.length
              ? snapshot.items[index + 1].item
              : null;
        case 'radio-status':
          radio = fields['isActive'] == true
              ? (
                  name: _text(fields['stationName'], 'Radio'),
                  image: remoteImageUri(fields['imageUrl']),
                )
              : null;
        case 'confirm-queue-changes-setting':
          if (data is bool) confirmQueueChanges = data;
        case 'accent-color':
          if ((fields['light'], fields['dark']) case (
            final String light,
            final String dark,
          )) {
            accent = (light: light, dark: dark);
          }
        case 'error':
          // These errors have no request ID. Request timers settle their own work.
          if (_text(data, '') == 'Request timed out') return;
          if (_artworkRequest != null) {
            _artworkRequest = null;
            if (_artworkWanted) requestArtwork();
            return;
          }
          errorMessage = _text(data, 'Remote error');

        case 'proxy':
          final revision = _artworkRequest;
          _artworkRequest = null;
          if (revision != _songRevision) {
            if (_artworkWanted) requestArtwork();
            return;
          }
          state = state.apply(message);
        case 'state':
        case 'song':
        case 'playback':
        case 'position':
        case 'volume':
        case 'shuffle':
        case 'repeat':
        case 'favorite':
        case 'rating':
          final previous = state.song;
          state = state.apply(message);
          final current = state.song;
          if (current?.id != previous?.id ||
              current?.image != previous?.image) {
            _songRevision++;
            _artworkAttempted = false;
            _artworkWanted = false;
          } else if ((event == 'song' || event == 'state') &&
              previous?.artworkBytes != null &&
              current != null) {
            state = _copyState(
              state,
              song: _withArtwork(current, previous!.artworkBytes!),
              replaceSong: true,
            );
          }
          if (state.volume > 0 && state.volume <= 100) {
            _lastVolume = state.volume;
          }
        default:
          return;
      }
      if (event == 'queue-state') {
        _handshakeTimer?.cancel();
        _reconnectAttempt = 0;
      }
      if (!online && (event == 'state' || event == 'queue-state')) {
        _handshakeTimer?.cancel();
        // Legacy hosts can send state before checking credentials. Keep the
        // retry count until that socket has survived the server's auth timeout.
        if (event == 'state') {
          _handshakeTimer = Timer(const Duration(seconds: 12), () {
            _reconnectAttempt = 0;
          });
        }
        connection = RemoteConnection.connected;
        errorMessage = null;
      }
      if (_artworkWanted && radio == null) requestArtwork();
      notifyListeners();
    } on FormatException {
      _invalidResponse();
    } on TypeError {
      _invalidResponse();
    }
  }

  void dismissError() {
    errorMessage = null;
    notifyListeners();
  }

  void _invalidResponse() {
    errorMessage = 'Feishin sent an invalid response.';
    notifyListeners();
  }

  void _onSocketClosed(WebSocket socket, {bool failed = false}) {
    if (!identical(_socket, socket)) return;
    final code = socket.closeCode;
    _resetSession();
    switch (code) {
      case 4000:
        _setDisconnected('Feishin Remote was turned off.');
      case 4004:
        _setDisconnected('Check the Feishin Remote username and password.');
      default:
        _scheduleReconnect(
          code == 4002
              ? 'Feishin Remote is restarting.'
              : failed
              ? 'The Feishin connection failed.'
              : 'Connection closed by Feishin.',
        );
    }
  }

  Future<void>? _resetSession([int? closeCode]) {
    _session++;
    _handshakeTimer?.cancel();
    _connectingClient?.close(force: true);
    _connectingClient = null;
    final socket = _socket;
    _socket = null;
    final closed = socket
        ?.close(closeCode)
        .then<void>((_) {}, onError: (Object _) {});
    unawaited(closed);
    for (final pending in _pending.values) {
      if (!pending.completer.isCompleted) {
        pending.completer.completeError(
          const RemoteException('Connection changed.'),
        );
      }
    }
    _pending.clear();
    state = emptyFeishinState;
    queue = null;
    _upNext = null;
    radio = null;
    accent = null;
    confirmQueueChanges = true;
    _songRevision = 0;
    _artworkAttempted = false;
    _artworkWanted = false;
    _artworkRequest = null;
    _lastVolume = 30;
    return closed;
  }

  void _scheduleReconnect(String message) {
    if (_config == null || _disposed) {
      _setDisconnected(message);
      return;
    }
    if (_reconnectTimer?.isActive ?? false) return;
    if (_reconnectAttempt >= _maxReconnectAttempts) {
      _setDisconnected('$message Automatic reconnect stopped.');
      return;
    }

    final delay = reconnectDelay(_reconnectAttempt++);
    connection = RemoteConnection.reconnecting;
    errorMessage = '$message Reconnecting in ${delay.inSeconds}s…';
    notifyListeners();
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      unawaited(_openConnection(reconnecting: true));
    });
  }

  void _setDisconnected(String? message) {
    connection = RemoteConnection.disconnected;
    errorMessage = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _config = null;
    _reconnectTimer?.cancel();
    _resetSession();
    notifyListeners();
    super.dispose();
  }
}
