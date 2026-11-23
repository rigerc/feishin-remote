import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:feishin_remote/feishin_remote.dart';
import 'package:feishin_remote/remote_audio_handler.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Frame = Map<String, Object?>;

final _track = <String, Object?>{
  'id': 'track',
  'name': 'A track',
  'artistName': 'An artist',
  'duration': 120000,
};

final _queue = [
  {..._track, 'uniqueId': 'first'},
  {..._track, 'uniqueId': 'second'},
  {..._track, 'uniqueId': 'third'},
];

class _Desktop {
  _Desktop(this._server) {
    _server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      _sockets.add(socket);
      _connections.add(socket);
    });
  }

  static Future<_Desktop> start() async =>
      _Desktop(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer _server;
  final _sockets = <WebSocket>[];
  final _connections = StreamController<WebSocket>();
  late final _incoming = StreamIterator(_connections.stream);

  String get url => 'ws://127.0.0.1:${_server.port}';

  Future<_Peer> accept() async {
    await _incoming.moveNext().timeout(const Duration(seconds: 3));
    return _Peer(_incoming.current);
  }

  Future<void> close() async {
    for (final socket in _sockets) {
      await socket.close();
    }
    await _incoming.cancel();
    await _connections.close();
    await _server.close(force: true);
  }
}

class _Peer {
  _Peer(this.socket);

  final WebSocket socket;
  late final _incoming = StreamIterator<Object?>(socket);

  Future<_Frame> command([String? event]) async {
    final hasNext = await _incoming.moveNext().timeout(
      const Duration(seconds: 3),
    );
    expect(hasNext, isTrue);
    final message = jsonDecode(_incoming.current as String) as _Frame;
    if (event != null) expect(message['event'], event);
    return message;
  }

  void push(String event, Object? data) =>
      socket.add(jsonEncode({'event': event, 'data': data}));

  void state([Object? song]) => push('state', {
    'position': 10,
    'status': 'playing',
    'volume': 42,
    'song': song,
  });

  void queue([List<Map<String, Object?>> items = const [], String? current]) =>
      push('queue-state', {'items': items, 'currentUniqueId': current});

  void page(String list, Object? id, List<_Frame> items, {bool more = false}) =>
      push('$list-response', {
        'requestId': id,
        'items': items,
        'hasMore': more,
      });

  void ack(Object? id, {String? error}) =>
      push('operation-ack', {'requestId': id, 'error': ?error});
}

Future<void> _until(
  FeishinRemoteClient client,
  bool Function() predicate,
) async {
  if (predicate()) return;
  final result = Completer<void>();
  void check() {
    if (predicate() && !result.isCompleted) result.complete();
  }

  client.addListener(check);
  try {
    await result.future.timeout(const Duration(seconds: 3));
  } finally {
    client.removeListener(check);
  }
}

void main() {
  late _Desktop desktop;
  late FeishinRemoteClient client;

  setUp(() async {
    desktop = await _Desktop.start();
    client = FeishinRemoteClient(
      requestTimeout: const Duration(milliseconds: 400),
      updateTimeout: const Duration(milliseconds: 400),
    );
  });

  tearDown(() async {
    client.dispose();
    await desktop.close();
  });

  Future<_Peer> connect({bool legacy = false}) async {
    final connected = client.connect(endpoint: desktop.url);
    final peer = await desktop.accept();
    await connected;
    peer.state(_track);
    if (!legacy) peer.queue(_queue, 'first');
    await _until(client, () => client.online && (legacy || client.expanded));
    return peer;
  }

  test(
    'sends credentials before commands and accepts an empty queue',
    () async {
      final connected = client.connect(
        endpoint: desktop.url,
        username: 'remote',
        password: 'fixture',
      );
      final peer = await desktop.accept();
      await connected;
      expect(client.connection, RemoteConnection.connecting);
      expect(await peer.command(), {
        'event': 'authenticate',
        'header': 'Basic ${base64Encode(utf8.encode('remote:fixture'))}',
      });
      expect(client.expanded, isFalse);
      peer.state();
      peer.queue();
      peer.push('confirm-queue-changes-setting', false);
      peer.push('accent-color', {'light': '#112233', 'dark': '#334455'});
      await _until(client, () => client.accent != null);
      expect(client.online, isTrue);
      expect(client.expanded, isTrue);
      expect(client.queue?.items, isEmpty);
      expect(client.confirmQueueChanges, isFalse);
      expect(client.accent?.dark, '#334455');
    },
  );

  test('handles invalid credentials and preserves legacy transport', () async {
    final failed = client.connect(endpoint: desktop.url, password: 'wrong');
    final denied = await desktop.accept();
    await failed;
    await denied.command('authenticate');
    await denied.socket.close(4004, 'Invalid credentials');
    await _until(
      client,
      () => client.connection == RemoteConnection.disconnected,
    );
    expect(client.errorMessage, contains('username and password'));
    final legacy = await connect(legacy: true);
    expect(client.expanded, isFalse);
    client.send('pause');
    expect(await legacy.command(), {'event': 'pause'});
    legacy.push('playback', 'paused');
    await _until(client, () => client.state.status == 'paused');
  });

  test(
    'matches out-of-order catalog responses by request ID and event',
    () async {
      final peer = await connect();
      final older = client.browse(
        RemoteCatalog.tracks,
        offset: 0,
        limit: 50,
        search: 'older',
      );
      final newer = client.browse(
        RemoteCatalog.tracks,
        offset: 50,
        limit: 50,
        search: 'newer',
      );
      final first = await peer.command('tracks-request');
      final second = await peer.command('tracks-request');
      expect(second, containsPair('startIndex', 50));
      expect(second, containsPair('limit', 50));
      expect(second, containsPair('searchTerm', 'newer'));
      expect(second['requestId'], isNot(first['requestId']));
      peer.page('albums', second['requestId'], []);
      peer.page('tracks', second['requestId'], [
        {..._track, 'id': 'new'},
      ], more: true);
      peer.page('tracks', first['requestId'], [_track]);
      expect((await newer).items.single.id, 'new');
      expect((await newer).hasMore, isTrue);
      expect((await older).items.single.id, 'track');
    },
  );

  test(
    'correlates acknowledgments and settles writes on host change',
    () async {
      final peer = await connect();
      final play = client.playItem(
        RemoteCatalog.albums,
        'album',
        RemotePlayType.nextShuffle,
      );
      final playCommand = await peer.command('play-album');
      expect(playCommand, containsPair('playType', 'nextShuffle'));
      peer.ack(playCommand['requestId']);
      await play;
      final rejected = expectLater(
        client.addToPlaylist('track', 'playlist'),
        throwsA(
          isA<RemoteException>().having(
            (error) => error.message,
            'message',
            'Read only',
          ),
        ),
      );
      final add = await peer.command('add-to-playlist');
      expect(add, containsPair('songId', 'track'));
      expect(add, containsPair('playlistId', 'playlist'));
      peer.ack(add['requestId'], error: 'Read only');
      await rejected;
      final pending = expectLater(
        client.clearQueue(),
        throwsA(
          isA<RemoteException>().having(
            (error) => error.message,
            'message',
            'Connection changed.',
          ),
        ),
      );
      await peer.command('clear-queue');
      final nextHost = await _Desktop.start();
      addTearDown(nextHost.close);
      final switched = client.connect(endpoint: nextHost.url);
      final next = await nextHost.accept();
      await switched;
      await pending;
      expect(client.queue, isNull);
      expect(client.state.song, isNull);
      next.state();
      next.queue();
      await _until(client, () => client.expanded);
      expect(client.queue?.items, isEmpty);
    },
  );

  test('times out missing responses without replaying a command', () async {
    final peer = await connect();
    final result = expectLater(
      client.playTrackRadio('track', RemotePlayType.last),
      throwsA(
        isA<RemoteException>().having(
          (error) => error.message,
          'message',
          contains('in time'),
        ),
      ),
    );
    final command = await peer.command('play-track-radio');
    expect(command, containsPair('playType', 'last'));
    peer.push('error', 'Request timed out');
    await result;
    peer.ack(command['requestId']);
    final browse = client.browse(
      RemoteCatalog.radio,
      offset: 0,
      limit: 50,
      search: '',
    );
    final radio = await peer.command('radio-request');
    expect(radio.containsKey('searchTerm'), isFalse);
    peer.page('radio', radio['requestId'], []);
    expect((await browse).items, isEmpty);
  });

  test(
    'waits for desktop queue updates and uses duplicate entry IDs',
    () async {
      final peer = await connect();
      expect(client.upNext?.id, 'track');
      final jump = client.jumpTo('second');
      expect(await peer.command(), {
        'event': 'queue-jump',
        'uniqueId': 'second',
      });
      peer.queue(_queue, 'second');
      await jump;

      final reordered = client.reorderQueue('third', 'first', QueueEdge.top);
      expect(await peer.command(), {
        'event': 'reorder-queue',
        'uniqueId': 'third',
        'targetUniqueId': 'first',
        'edge': 'top',
      });
      peer.queue([_queue[2], _queue[0], _queue[1]], 'second');
      await reordered;

      final removed = client.removeFromQueue('first');
      expect(await peer.command(), {
        'event': 'remove-from-queue',
        'uniqueId': 'first',
      });
      peer.queue([_queue[2], _queue[1]], 'second');
      await removed;
      expect(client.queue?.items.map((entry) => entry.uniqueId), [
        'third',
        'second',
      ]);
      expect(client.upNext, isNull);
    },
  );

  test(
    'shows live radio in the media session and restores track controls',
    () async {
      final handler = RemoteAudioHandler(client);
      addTearDown(handler.dispose);
      final peer = await connect();
      expect(handler.mediaItem.value?.title, 'A track');
      expect(
        handler.playbackState.value.systemActions,
        contains(MediaAction.seek),
      );
      final browse = client.browse(
        RemoteCatalog.radio,
        offset: 0,
        limit: 50,
        search: '',
      );
      final command = await peer.command('radio-request');
      peer.page('radio', command['requestId'], [
        {
          'id': 'fm',
          'name': 'Local FM',
          'homepageUrl': 'https://example.test/',
        },
      ]);
      final station = (await browse).items.single;
      expect(station.homepage?.host, 'example.test');
      final play = client.playStation(station);
      expect(await peer.command(), {'event': 'play-radio', 'id': 'fm'});
      peer.push('radio-status', {'isActive': true, 'stationName': 'Local FM'});
      await play;
      expect(handler.mediaItem.value?.title, 'Local FM');
      expect(handler.playbackState.value.systemActions, isEmpty);
      expect(handler.playbackState.value.controls, [MediaControl.pause]);
      peer.push('radio-status', {'isActive': false});
      await _until(client, () => client.radio == null);
      expect(handler.mediaItem.value?.title, 'A track');
      expect(
        handler.playbackState.value.systemActions,
        contains(MediaAction.seek),
      );
    },
  );

  test(
    'restores volume and discards artwork replies for a previous song',
    () async {
      final peer = await connect();
      client.toggleMute();
      expect(await peer.command(), {'event': 'volume', 'volume': 0});
      peer.push('volume', 0);
      await _until(client, () => client.state.volume == 0);
      client.toggleMute();
      expect(await peer.command(), {'event': 'volume', 'volume': 42});

      peer.push('song', {
        ..._track,
        'imageUrl': 'https://example.test/one.png',
      });
      await _until(client, () => client.state.song?.image != null);
      client.requestArtwork();
      await peer.command('proxy');
      peer.push('song', {
        ..._track,
        'id': 'new',
        'imageUrl': 'https://example.test/two.png',
      });
      await _until(client, () => client.state.song?.id == 'new');
      client.requestArtwork();
      peer.push('proxy', 'AQ==');
      await peer.command('proxy');
      expect(client.state.song?.artworkBytes, isNull);
      peer.push('proxy', 'Ag==');
      await _until(client, () => client.state.song?.artworkBytes != null);
      expect(client.state.song?.artworkBytes, [2]);
    },
  );
}
