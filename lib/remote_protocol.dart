part of 'feishin_remote.dart';

enum RemoteCatalog { tracks, albums, playlists, radio }

enum RemotePlayType {
  now,
  next,
  last,
  shuffle,
  nextShuffle,
  lastShuffle;

  bool get replacesQueue => this == now || this == shuffle;
}

enum QueueEdge { top, bottom }

typedef RemoteItem = ({
  String id,
  String name,
  String? artist,
  String? album,
  Uri? image,
  Uri? homepage,
  int? durationMs,
  int? songCount,
  int? releaseYear,
});
typedef RemotePage = ({List<RemoteItem> items, bool hasMore});
typedef RemoteQueueEntry = ({String uniqueId, RemoteItem item});
typedef RemoteQueue = ({String? currentId, List<RemoteQueueEntry> items});
typedef RemoteRadio = ({String name, Uri? image});
typedef RemoteAccent = ({String light, String dark});

class RemoteException implements Exception {
  const RemoteException(this.message);
  final String message;
  @override
  String toString() => message;
}

Uri? remoteImageUri(Object? value) {
  final uri = value is String ? Uri.tryParse(value) : null;
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}

RemoteItem _remoteItem(Map<String, Object?> data) => (
  id: _text(data['id'], ''),
  name: _text(data['name'], 'Untitled'),
  artist: (data['artistName'] ?? data['albumArtistName']) as String?,
  album: data['album'] as String?,
  image: remoteImageUri(data['imageUrl']),
  homepage: remoteImageUri(data['homepageUrl']),
  durationMs: (data['duration'] as num?)?.toInt(),
  songCount: (data['songCount'] as num?)?.toInt(),
  releaseYear: (data['releaseYear'] as num?)?.toInt(),
);

RemotePage _remotePage(Map<String, Object?> data) => (
  items: List.unmodifiable(
    (data['items'] as List<Object?>).map(_objectMap).map(_remoteItem),
  ),
  hasMore: data['hasMore'] as bool,
);

RemoteQueue _remoteQueue(Map<String, Object?> data) {
  final seen = <String>{};
  return (
    currentId: data['currentUniqueId'] as String?,
    items: List.unmodifiable([
      for (final value in data['items'] as List<Object?>)
        if (_objectMap(value) case final item)
          if (item['uniqueId'] case final String id when seen.add(id))
            (uniqueId: id, item: _remoteItem(item)),
    ]),
  );
}
