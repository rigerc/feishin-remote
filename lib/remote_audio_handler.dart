import 'package:audio_service/audio_service.dart';
import 'package:feishin_remote/feishin_remote.dart';

class RemoteAudioHandler extends BaseAudioHandler with SeekHandler {
  RemoteAudioHandler(this._client) {
    _client.addListener(_sync);
    _sync();
  }

  final FeishinRemoteClient _client;

  void _sync() {
    final state = _client.state;
    final song = state.song;
    if (song == null) {
      mediaItem.add(null);
      playbackState.add(
        playbackState.value.copyWith(
          controls: const [],
          processingState: AudioProcessingState.idle,
          playing: false,
        ),
      );
      return;
    }

    mediaItem.add(
      MediaItem(
        id: song.id,
        title: song.name,
        artist: song.artistName,
        album: song.album,
        duration: Duration(milliseconds: song.durationMs),
      ),
    );
    final playing = state.status == 'playing';
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: AudioProcessingState.ready,
        playing: playing,
        updatePosition: Duration(
          milliseconds: (state.position * Duration.millisecondsPerSecond)
              .round(),
        ),
        updateTime: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> play() async => _client.send('play');

  @override
  Future<void> pause() async => _client.send('pause');

  @override
  Future<void> skipToNext() async => _client.send('next');

  @override
  Future<void> skipToPrevious() async => _client.send('previous');

  @override
  Future<void> seek(Duration position) async =>
      _client.send('position', <String, Object?>{
        'position': position.inMilliseconds / Duration.millisecondsPerSecond,
      });

  void dispose() => _client.removeListener(_sync);
}
