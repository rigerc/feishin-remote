import 'dart:async';

import 'package:feishin_remote/feishin_remote.dart';
import 'package:feishin_remote/remote_browser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('replacement requires consent and skips it when disabled', (
    tester,
  ) async {
    final client = FeishinRemoteClient()
      ..connection = RemoteConnection.connected;
    client.queue = (
      currentId: 'entry',
      items: [
        (
          uniqueId: 'entry',
          item: (
            id: 'track',
            name: 'Track',
            artist: null,
            album: null,
            image: null,
            homepage: null,
            durationMs: null,
            songCount: null,
            releaseYear: null,
          ),
        ),
      ],
    );
    final actions = RemoteActions(client);
    addTearDown(actions.dispose);
    addTearDown(client.dispose);

    var sends = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => unawaited(
                actions.run(
                  context,
                  () async => sends++,
                  replacesQueue: 'Replace queue',
                ),
              ),
              child: const Text('Play selected track'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Play selected track'));
    await tester.pumpAndSettle();
    expect(sends, 0);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(sends, 0);

    await tester.tap(find.text('Play selected track'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replace queue'));
    await tester.pumpAndSettle();
    expect(sends, 1);

    client.confirmQueueChanges = false;
    await tester.tap(find.text('Play selected track'));
    await tester.pumpAndSettle();
    expect(find.text('Replace queue?'), findsNothing);
    expect(sends, 2);
  });
}
