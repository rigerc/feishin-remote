import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:feishin_remote/app_storage.dart';
import 'package:feishin_remote/feishin_remote.dart';
import 'package:feishin_remote/remote_app.dart';
import 'package:feishin_remote/remote_audio_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const mode = String.fromEnvironment('MEDIA_MODE');
const output = String.fromEnvironment('MEDIA_OUTPUT');
const fontDir = String.fromEnvironment('MEDIA_FONTS');
const captureKey = Key('media-capture');
const frameTime = Duration(microseconds: 33333);

/// Fictional library shown in screenshots and video.
const _albums = [
  ('Slow Tide', 'Harbor Lights', 2023, 11),
  ('Paper Lanterns', 'Night Orchard', 2021, 9),
  ('Quiet Hours', 'The Long Weekend', 2024, 12),
  ('Field Recordings', 'Marlow & Finch', 2019, 8),
  ('Low Sun', 'Harbor Lights', 2020, 10),
  ('After the Rain', 'Night Orchard', 2022, 7),
];
const _tracks = [
  ('Blue Hour', 'Harbor Lights', 'Slow Tide', 224000),
  ('Lantern Walk', 'Night Orchard', 'Paper Lanterns', 187000),
  ('Open Window', 'The Long Weekend', 'Quiet Hours', 251000),
  ('Salt and Cedar', 'Marlow & Finch', 'Field Recordings', 203000),
  ('Evening Train', 'Harbor Lights', 'Low Sun', 238000),
  ('Small Hours', 'Night Orchard', 'After the Rain', 196000),
  ('Porch Light', 'The Long Weekend', 'Quiet Hours', 215000),
  ('Gravel Road', 'Marlow & Finch', 'Field Recordings', 232000),
];

Map<String, Object?> _song(int index, {String? uniqueId}) {
  final track = _tracks[index % _tracks.length];
  return {
    'id': 'song-$index',
    'uniqueId': ?uniqueId,
    'name': track.$1,
    'artistName': track.$2,
    'album': track.$3,
    'duration': track.$4,
  };
}

/// Stands in for a Feishin 1.16 desktop on a local socket.
class FakeDesktop {
  FakeDesktop(this._server, this._artwork) {
    _server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      _sockets.add(socket);
      socket.listen((message) => _handle(socket, message as String));
      void push(String event, Object? data) =>
          socket.add(jsonEncode({'event': event, 'data': data}));
      push('state', {
        'position': 83,
        'repeat': 'none',
        'shuffle': false,
        'status': 'playing',
        'volume': 64,
        'song': {
          ..._song(0),
          'imageUrl': 'http://127.0.0.1:1/artwork',
          'userFavorite': true,
          'userRating': 4,
          'releaseYear': 2023,
          'genres': [
            {'name': 'Ambient'},
            {'name': 'Indie'},
          ],
          'bitRate': 1021,
          'sampleRate': 44100,
          'bitDepth': 16,
          'container': 'FLAC',
          'trackNumber': 3,
          'discNumber': 1,
          'playCount': 18,
        },
      });
      push('queue-state', {
        'items': [for (var i = 0; i < 14; i++) _song(i, uniqueId: 'queue-$i')],
        'currentUniqueId': 'queue-0',
      });
    });
  }

  static Future<FakeDesktop> start(Uint8List artwork) async => FakeDesktop(
    await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    artwork,
  );

  final HttpServer _server;
  final Uint8List _artwork;
  final _sockets = <WebSocket>[];

  String get url => 'ws://127.0.0.1:${_server.port}';

  void _handle(WebSocket socket, String message) {
    final command = jsonDecode(message) as Map<String, Object?>;
    final event = command['event'] as String;
    void reply(String name, Object? data) =>
        socket.add(jsonEncode({'event': name, 'data': data}));
    if (event == 'proxy') {
      reply('proxy', base64Encode(_artwork));
    } else if (event.endsWith('-request')) {
      final catalog = event.substring(0, event.length - '-request'.length);
      final items = switch (catalog) {
        'tracks' => [for (var i = 0; i < _tracks.length; i++) _song(i)],
        'albums' => [
          for (final (index, album) in _albums.indexed)
            {
              'id': 'album-$index',
              'name': album.$1,
              'artistName': album.$2,
              'releaseYear': album.$3,
              'songCount': album.$4,
            },
        ],
        'playlists' => [
          for (final (index, name) in [
            'Rainy Day',
            'Road Trip',
            'Sunday Morning',
            'Focus',
          ].indexed)
            {
              'id': 'playlist-$index',
              'name': name,
              'songCount': 12 + index * 7,
            },
        ],
        'radio' => [
          for (final (index, name) in [
            'Harbor FM',
            'Late Night Jazz',
            'Morning Folk',
          ].indexed)
            {
              'id': 'radio-$index',
              'name': name,
              'homepageUrl': 'https://example.org/$index',
            },
        ],
        _ => const <Object?>[],
      };
      reply('$catalog-response', {
        'requestId': command['requestId'],
        'items': items,
        'hasMore': false,
      });
    }
  }

  Future<void> close() async {
    for (final socket in _sockets) {
      await socket.close();
    }
    await _server.close(force: true);
  }
}

Future<Uint8List> makeArtwork() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const size = 600.0;
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, size, size),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        const Offset(size, size),
        const [Color(0xff16324f), Color(0xff2f6f73), Color(0xffe9b44c)],
        const [0, 0.55, 1],
      ),
  );
  canvas.drawCircle(
    const Offset(400, 190),
    92,
    Paint()..color = const Color(0xfffff3d0),
  );
  canvas.drawPath(
    Path()
      ..moveTo(0, 430)
      ..quadraticBezierTo(150, 360, 300, 430)
      ..quadraticBezierTo(450, 500, size, 420)
      ..lineTo(size, size)
      ..lineTo(0, size)
      ..close(),
    Paint()..color = const Color(0xff0f2236),
  );
  final image = await recorder.endRecording().toImage(600, 600);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

Future<void> loadFont(List<String> families, List<String> names) async {
  for (final family in families) {
    final loader = FontLoader(family);
    for (final name in names) {
      loader.addFont(
        File('$fontDir/$name').readAsBytes().then(ByteData.sublistView),
      );
    }
    await loader.load();
  }
}

Future<void> saveFrame(WidgetTester tester, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(captureKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$output/$path').writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
  expect(File('$output/$path').lengthSync(), greaterThan(0));
}

void main() {
  setUpAll(() async {
    await loadFont(
      ['Roboto', 'sans-serif', 'sans-serif-condensed'],
      ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf'],
    );
    await loadFont(['MaterialIcons'], ['MaterialIcons-Regular.otf']);
  });

  testWidgets('capture the demo journey', (tester) async {
    // The fake desktop is a real local socket, so lift the test HTTP block.
    HttpOverrides.global = null;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final artwork = (await tester.runAsync(makeArtwork))!;
    final desktop = (await tester.runAsync(() => FakeDesktop.start(artwork)))!;
    final client = FeishinRemoteClient();
    final handler = RemoteAudioHandler(client);

    // The fake desktop speaks over a real socket, so let the event loop run.
    Future<void> network([int milliseconds = 200]) async {
      await tester.runAsync(
        () => Future<void>.delayed(Duration(milliseconds: milliseconds)),
      );
      await tester.pump();
    }

    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: RemoteApp(
          client: client,
          storage: AppStorage(),
          audioHandler: handler,
        ),
      ),
    );
    await tester.runAsync(() => client.connect(endpoint: desktop.url));
    // The song's image URL is unreachable, so the app falls back to the proxy.
    for (var attempt = 0; attempt < 20; attempt++) {
      await network(250);
      await tester.pumpAndSettle();
      if (client.state.song?.artworkBytes != null) break;
    }
    await network(300);
    await tester.pumpAndSettle();
    expect(client.online && client.expanded, isTrue);
    expect(client.state.song?.artworkBytes, isNotNull);

    final record = mode != 'screenshots';
    var frame = 0;
    Future<void> recordFrames(int count) async {
      for (var index = 0; index < count; index++) {
        await tester.pump(frameTime);
        final number = (frame++).toString().padLeft(4, '0');
        await saveFrame(tester, 'frames/$number.png');
      }
    }

    Future<void> openTab(String label, {String? expecting}) async {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pump();
      if (record) await recordFrames(6);
      await network();
      if (record) await recordFrames(12);
      await tester.pumpAndSettle();
      if (expecting != null) expect(find.text(expecting), findsWidgets);
    }

    if (mode != 'video') await saveFrame(tester, 'playing.png');
    if (record) await recordFrames(30);

    await openTab('Library', expecting: 'Blue Hour');
    if (mode != 'video') await saveFrame(tester, 'library.png');
    if (record) {
      await recordFrames(12);
      await tester.tap(find.text('Albums'));
      await tester.pump();
      await network();
      await tester.pumpAndSettle();
      expect(find.text('Slow Tide'), findsWidgets);
      await recordFrames(24);
    }

    await openTab('Queue', expecting: 'Open Window');
    if (mode != 'video') await saveFrame(tester, 'queue.png');
    if (record) await recordFrames(24);

    await openTab('Playing');
    if (record) await recordFrames(18);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      client.dispose();
      await desktop.close();
    });
    handler.dispose();
  });
}
