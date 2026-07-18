import 'package:audio_service/audio_service.dart';
import 'package:feishin_remote/app_storage.dart';
import 'package:feishin_remote/feishin_remote.dart';
import 'package:feishin_remote/remote_app.dart';
import 'package:feishin_remote/remote_audio_handler.dart';
import 'package:flutter/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final client = FeishinRemoteClient();
  final storage = AppStorage();
  final audioHandler = await AudioService.init<RemoteAudioHandler>(
    builder: () => RemoteAudioHandler(client),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.feishin.feishin_remote.playback',
      androidNotificationChannelName: 'Feishin playback controls',
      androidNotificationChannelDescription:
          'Controls playback on the connected Feishin instance.',
      androidNotificationIcon: 'drawable/ic_stat_feishin',
    ),
  );

  runApp(
    RemoteApp(client: client, storage: storage, audioHandler: audioHandler),
  );
}
