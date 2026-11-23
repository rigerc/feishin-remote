import 'package:audio_service/audio_service.dart';
import 'package:feishin_remote/feishin_remote.dart';

class RemoteAudioHandler extends BaseAudioHandler with SeekHandler {
  RemoteAudioHandler(this._client) {
    _client.addListener(_sync);
    _sync();
  }

  final FeishinRemoteClient _client;
  MediaItem? _currentItem;
  (String, double)? _lastPlayback;

  void _sync() {
    final state = _client.state;
    final song = state.song;
    final radio = _client.radio;
    final item = !_client.online
        ? null
        : radio != null
        ? MediaItem(
            id: 'radio:${radio.name}',
            title: radio.name,
            artist: 'Internet radio',
            artUri: radio.image,
          )
        : song == null
        ? null
        : MediaItem(
            id: song.id,
            title: song.name,
            artist: song.artistName,
            album: song.album,
            artUri: song.image,
            duration: Duration(milliseconds: song.durationMs),
          );
    final previous = _currentItem;
    final itemChanged =
        item?.id != previous?.id ||
        item?.title != previous?.title ||
        item?.artist != previous?.artist ||
        item?.album != previous?.album ||
        item?.artUri != previous?.artUri ||
        item?.duration != previous?.duration;
    if (itemChanged) {
      _currentItem = item;
      mediaItem.add(item);
    }
    final position = radio == null ? state.position : 0.0;
    final playback = (state.status, position);
    if (!itemChanged && _lastPlayback == playback) return;
    _lastPlayback = playback;

    if (item == null) {
      playbackState.add(PlaybackState());
      return;
    }

    final playing = state.status == 'playing';
    playbackState.add(
      PlaybackState(
        controls: [
          if (radio == null) MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          if (radio == null) MediaControl.skipToNext,
        ],
        systemActions: radio == null ? const {MediaAction.seek} : const {},
        androidCompactActionIndices: radio == null
            ? const [0, 1, 2]
            : const [0],
        processingState: AudioProcessingState.ready,
        playing: playing,
        updatePosition: Duration(
          milliseconds: (position * Duration.millisecondsPerSecond).round(),
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
  Future<void> skipToNext() async {
    if (_client.radio == null) _client.send('next');
  }

  @override
  Future<void> skipToPrevious() async {
    if (_client.radio == null) _client.send('previous');
  }

  @override
  Future<void> seek(Duration position) async {
    if (_client.radio == null) {
      _client.send('position', {
        'position': position.inMilliseconds / Duration.millisecondsPerSecond,
      });
    }
  }

  void dispose() => _client.removeListener(_sync);
}
