import 'dart:async';

import 'dart:typed_data';
import 'package:feishin_remote/app_theme.dart';
import 'package:feishin_remote/feishin_remote.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class RemoteActions extends ValueNotifier<bool> {
  RemoteActions(this.client) : super(false);

  final FeishinRemoteClient client;
  bool _disposed = false;

  Future<void> run(
    BuildContext context,
    Future<void> Function() action, {
    String? replacesQueue,
    ValueChanged<String>? onError,
  }) async {
    if (_disposed || value || !client.online || !client.expanded) return;
    final session = client.session;
    value = true;
    try {
      if (replacesQueue != null &&
          client.confirmQueueChanges &&
          client.queue!.items.isNotEmpty) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('$replacesQueue?'),
            content: const Text(
              'This will remove the tracks in the current queue.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(replacesQueue),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }
      if (!context.mounted || session != client.session) return;
      await action();
    } on RemoteException catch (error) {
      if (context.mounted && session == client.session) {
        if (onError == null) {
          _message(context, error.message);
        } else {
          onError(error.message);
        }
      }
    } finally {
      if (!_disposed) value = false;
    }
  }

  Future<void> play(
    BuildContext context,
    RemoteCatalog catalog,
    String id,
    RemotePlayType mode,
  ) => run(
    context,
    () => client.playItem(catalog, id, mode),
    replacesQueue: mode.replacesQueue ? 'Replace queue' : null,
  );

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

void _message(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class RemoteLibraryView extends StatefulWidget {
  const RemoteLibraryView({required this.actions, super.key});

  final RemoteActions actions;

  @override
  State<RemoteLibraryView> createState() => _RemoteLibraryViewState();
}

class _RemoteLibraryViewState extends State<RemoteLibraryView> {
  RemoteCatalog _catalog = RemoteCatalog.tracks;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.md,
          AppSpace.sm,
          AppSpace.md,
          0,
        ),
        child: SegmentedButton<RemoteCatalog>(
          segments: const [
            ButtonSegment(value: RemoteCatalog.tracks, label: Text('Tracks')),
            ButtonSegment(value: RemoteCatalog.albums, label: Text('Albums')),
          ],
          selected: {_catalog},
          onSelectionChanged: (selection) =>
              setState(() => _catalog = selection.single),
        ),
      ),
      Expanded(
        child: RemoteCatalogView(
          key: ValueKey(_catalog),
          catalog: _catalog,
          actions: widget.actions,
        ),
      ),
    ],
  );
}

class RemoteCatalogView extends StatelessWidget {
  const RemoteCatalogView({
    required this.catalog,
    required this.actions,
    super.key,
  });

  final RemoteCatalog catalog;
  final RemoteActions actions;

  @override
  Widget build(BuildContext context) => _CatalogList(
    catalog: catalog,
    client: actions.client,
    row: (context, item) {
      final station = catalog == RemoteCatalog.radio;
      return _ItemTile(
        item: item,
        subtitle: _subtitle(item),
        icon: _catalogIcon(catalog),
        onTap: () => station
            ? actions.run(context, () => actions.client.playStation(item))
            : actions.play(context, catalog, item.id, RemotePlayType.now),
        onMenu: station
            ? null
            : () => _showActions(context, actions, catalog, item),
        trailing: station && item.homepage != null
            ? IconButton(
                tooltip: 'Open station website',
                onPressed: () =>
                    unawaited(_openHomepage(context, item.homepage!)),
                icon: const Icon(Icons.open_in_new_rounded),
              )
            : null,
      );
    },
  );
}

Future<void> _openHomepage(BuildContext context, Uri url) async {
  try {
    if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    // Some Android devices have no installed handler for the URL.
  }
  if (context.mounted) _message(context, 'Could not open the station website.');
}

IconData _catalogIcon(RemoteCatalog catalog) => switch (catalog) {
  RemoteCatalog.tracks => Icons.music_note_rounded,
  RemoteCatalog.albums => Icons.album_rounded,
  RemoteCatalog.playlists => Icons.queue_music_rounded,
  RemoteCatalog.radio => Icons.radio_rounded,
};

String _subtitle(RemoteItem item) => [
  if (item.artist case final String artist when artist.isNotEmpty) artist,
  if (item.album case final String album when album.isNotEmpty) album,
  if (item.releaseYear case final int year when year > 0) '$year',
  if (item.songCount case final int count) '$count tracks',
  if (item.durationMs case final int ms when ms > 0) _duration(ms),
].join('  •  ');

String _duration(int ms) {
  final duration = Duration(milliseconds: ms);
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${duration.inMinutes}:$seconds';
}

class _CatalogList extends StatefulWidget {
  const _CatalogList({
    required this.catalog,
    required this.client,
    required this.row,
  });

  final RemoteCatalog catalog;
  final FeishinRemoteClient client;
  final Widget Function(BuildContext, RemoteItem) row;

  @override
  State<_CatalogList> createState() => _CatalogListState();
}

class _CatalogListState extends State<_CatalogList> {
  static const _pageSize = 50;
  final _scroll = ScrollController();
  final _items = <RemoteItem>[];
  final _seen = <String>{};
  Timer? _debounce;
  String _search = '';
  String? _error;
  int _offset = 0;
  int _generation = 0;
  bool _hasMore = true;
  bool _loading = true;
  bool _manualLoad = false;

  String get _name =>
      widget.catalog == RemoteCatalog.radio ? 'stations' : widget.catalog.name;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_loadNearEnd);
    unawaited(_load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _loadNearEnd() {
    if (_scroll.position.extentAfter < 320 &&
        _hasMore &&
        !_loading &&
        _error == null &&
        !_manualLoad) {
      unawaited(_load());
    }
  }

  Future<void> _reset(String search, {bool debounce = false}) async {
    _debounce?.cancel();
    _generation++;
    setState(() {
      _search = search.trim();
      _items.clear();
      _seen.clear();
      _offset = 0;
      _error = null;
      _hasMore = true;
      _manualLoad = false;
      _loading = true;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (debounce) {
      _debounce = Timer(const Duration(milliseconds: 300), _load);
    } else {
      await _load();
    }
  }

  Future<void> _load() async {
    final generation = _generation;
    final session = widget.client.session;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.client.browse(
        widget.catalog,
        offset: _offset,
        limit: _pageSize,
        search: _search,
      );
      if (!mounted ||
          generation != _generation ||
          session != widget.client.session) {
        return;
      }
      setState(() {
        final before = _items.length;
        _items.addAll(
          page.items.where((item) => item.id.isNotEmpty && _seen.add(item.id)),
        );
        _offset += page.items.length;
        _hasMore = page.hasMore;
        _manualLoad = _items.length == before;
        _loading = false;
      });
    } on RemoteException catch (error) {
      if (!mounted ||
          generation != _generation ||
          session != widget.client.session) {
        return;
      }
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: TextField(
          onChanged: (value) => unawaited(_reset(value, debounce: true)),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) {
            if (_debounce?.isActive ?? false) {
              _debounce!.cancel();
              unawaited(_load());
            }
          },
          decoration: InputDecoration(
            labelText: 'Search $_name',
            prefixIcon: const Icon(Icons.search_rounded),
          ),
        ),
      ),
      if (_loading) const LinearProgressIndicator(),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () => _reset(_search),
          child: ListView.builder(
            controller: _scroll,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: AppSpace.sm),
            itemCount: _items.length + 1,
            itemBuilder: (context, index) => index < _items.length
                ? widget.row(context, _items[index])
                : _footer(),
          ),
        ),
      ),
    ],
  );

  Widget _footer() {
    if (_loading) return const SizedBox(height: AppSpace.md);
    return Padding(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        children: [
          if (_error case final String error)
            Text(error, textAlign: TextAlign.center)
          else if (_items.isEmpty)
            Text(
              _search.isEmpty ? 'No $_name available' : 'No matching $_name',
            ),
          if (_error != null || _hasMore)
            TextButton(
              onPressed: () => unawaited(_load()),
              child: Text(_error != null ? 'Retry' : 'Load more'),
            ),
        ],
      ),
    );
  }
}

class RemoteThumbnail extends StatelessWidget {
  const RemoteThumbnail({
    required this.image,
    required this.icon,
    this.bytes,
    super.key,
  });

  final Uri? image;
  final IconData icon;
  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    final placeholder = Icon(icon, size: 22);
    final cacheWidth = (48 * MediaQuery.devicePixelRatioOf(context)).ceil();
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.small),
      child: SizedBox.square(
        dimension: 46,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: bytes != null
              ? Image.memory(
                  bytes!,
                  fit: BoxFit.cover,
                  cacheWidth: cacheWidth,
                  errorBuilder: (_, _, _) => placeholder,
                )
              : image != null
              ? Image.network(
                  image.toString(),
                  fit: BoxFit.cover,
                  cacheWidth: cacheWidth,
                  errorBuilder: (_, _, _) => placeholder,
                )
              : placeholder,
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.onMenu,
    this.trailing,
    this.selected = false,
  });

  final RemoteItem item;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onMenu;
  final Widget? trailing;
  final bool selected;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: RemoteThumbnail(image: item.image, icon: icon),
    title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: subtitle.isEmpty
        ? null
        : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
    selected: selected,
    selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
    onTap: onTap,
    onLongPress: onMenu,
    trailing: onMenu == null
        ? trailing
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Actions for ${item.name}',
                onPressed: onMenu,
                icon: const Icon(Icons.more_vert_rounded),
              ),
              ?trailing,
            ],
          ),
  );
}

enum _ItemAction { play, shuffle, radio, playlist, remove }

Future<void> _showActions(
  BuildContext context,
  RemoteActions actions,
  RemoteCatalog catalog,
  RemoteItem item, {
  String? queueId,
}) async {
  final session = actions.client.session;
  final track = catalog == RemoteCatalog.tracks;
  final choice = await showModalBottomSheet<_ItemAction>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            for (final (action, icon, title) in [
              (_ItemAction.play, Icons.play_arrow_rounded, 'Play'),
              (_ItemAction.shuffle, Icons.shuffle_rounded, 'Play shuffled'),
              if (track)
                (_ItemAction.radio, Icons.auto_awesome_rounded, 'Track Radio'),
              if (track)
                (
                  _ItemAction.playlist,
                  Icons.playlist_add_rounded,
                  'Add to playlist',
                ),
              if (queueId != null)
                (
                  _ItemAction.remove,
                  Icons.remove_circle_outline_rounded,
                  'Remove from queue',
                ),
            ])
              ListTile(
                leading: Icon(icon),
                title: Text(title),
                onTap: () => Navigator.pop(sheet, action),
              ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted || actions.client.session != session || choice == null) {
    return;
  }
  switch (choice) {
    case _ItemAction.play:
    case _ItemAction.shuffle:
    case _ItemAction.radio:
      final shuffled = choice == _ItemAction.shuffle;
      final mode = await showModalBottomSheet<RemotePlayType>(
        context: context,
        showDragHandle: true,
        builder: (sheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (mode, icon, title) in [
                (
                  shuffled ? RemotePlayType.shuffle : RemotePlayType.now,
                  Icons.play_arrow_rounded,
                  'Now',
                ),
                (
                  shuffled ? RemotePlayType.nextShuffle : RemotePlayType.next,
                  Icons.playlist_play_rounded,
                  'Next',
                ),
                (
                  shuffled ? RemotePlayType.lastShuffle : RemotePlayType.last,
                  Icons.playlist_add_rounded,
                  'Last',
                ),
              ])
                ListTile(
                  leading: Icon(icon),
                  title: Text(title),
                  onTap: () => Navigator.pop(sheet, mode),
                ),
            ],
          ),
        ),
      );
      if (!context.mounted ||
          actions.client.session != session ||
          mode == null) {
        return;
      }
      if (choice == _ItemAction.radio) {
        await actions.run(
          context,
          () => actions.client.playTrackRadio(item.id, mode),
          replacesQueue: mode.replacesQueue ? 'Replace queue' : null,
        );
      } else {
        await actions.play(context, catalog, item.id, mode);
      }
    case _ItemAction.playlist:
      final playlist = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheet) => _PlaylistPicker(actions: actions, song: item),
      );
      if (playlist != null &&
          context.mounted &&
          actions.client.session == session) {
        _message(context, 'Added to $playlist.');
      }
    case _ItemAction.remove:
      await actions.run(
        context,
        () => actions.client.removeFromQueue(queueId!),
      );
  }
}

class _PlaylistPicker extends StatefulWidget {
  const _PlaylistPicker({required this.actions, required this.song});

  final RemoteActions actions;
  final RemoteItem song;

  @override
  State<_PlaylistPicker> createState() => _PlaylistPickerState();
}

class _PlaylistPickerState extends State<_PlaylistPicker> {
  late final int _session;
  String? _error;

  RemoteActions get _actions => widget.actions;

  @override
  void initState() {
    super.initState();
    _session = _actions.client.session;
    _actions.client.addListener(_checkSession);
  }

  @override
  void dispose() {
    _actions.client.removeListener(_checkSession);
    super.dispose();
  }

  void _checkSession() {
    if (mounted &&
        _session != _actions.client.session &&
        (ModalRoute.of(context)?.isCurrent ?? false)) {
      Navigator.pop(context);
    }
  }

  Future<void> _add(RemoteItem playlist) async {
    if (_actions.value || _session != _actions.client.session) return;
    setState(() => _error = null);
    await _actions.run(context, () async {
      await _actions.client.addToPlaylist(widget.song.id, playlist.id);
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
        Navigator.pop(context, playlist.name);
      }
    }, onError: (message) => setState(() => _error = message));
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: FractionallySizedBox(
      heightFactor: 0.75,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
              child: Text(
                'Add to playlist',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (_error case final String error)
              Padding(
                padding: const EdgeInsets.all(AppSpace.md),
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ListenableBuilder(
              listenable: _actions,
              builder: (context, _) => _actions.value
                  ? const LinearProgressIndicator()
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: _CatalogList(
                catalog: RemoteCatalog.playlists,
                client: _actions.client,
                row: (context, playlist) => _ItemTile(
                  item: playlist,
                  subtitle: _subtitle(playlist),
                  icon: Icons.queue_music_rounded,
                  onTap: () => unawaited(_add(playlist)),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class RemoteQueueView extends StatefulWidget {
  const RemoteQueueView({required this.actions, super.key});

  final RemoteActions actions;

  @override
  State<RemoteQueueView> createState() => _RemoteQueueViewState();
}

class _RemoteQueueViewState extends State<RemoteQueueView> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  List<RemoteQueueEntry>? _source;
  List<RemoteQueueEntry>? _dragItems;
  int? _dragIndex;
  List<RemoteQueueEntry> _visible = const [];
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  double get _rowHeight =>
      76 + (MediaQuery.textScalerOf(context).scale(30) - 30).clamp(0, 74);

  void _filter(List<RemoteQueueEntry> items) {
    final search = _search.text.trim().toLowerCase();
    if (identical(items, _source) && search == _query) return;
    _source = items;
    _query = search;
    _visible = search.isEmpty
        ? items
        : [
            for (final entry in items)
              if (entry.item.name.toLowerCase().contains(search) ||
                  (entry.item.artist?.toLowerCase().contains(search) ?? false))
                entry,
          ];
  }

  void _jumpToCurrent() {
    final queue = widget.actions.client.queue;
    if (queue == null) return;
    if (_search.text.isNotEmpty) {
      _search.clear();
      setState(() => _filter(queue.items));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToCurrent();
      });
    } else {
      _scrollToCurrent();
    }
  }

  void _scrollToCurrent() {
    final current = widget.actions.client.queue?.currentId;
    final index = _visible.indexWhere((entry) => entry.uniqueId == current);
    if (index < 0 || !_scroll.hasClients) return;
    final offset = (index * _rowHeight).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    unawaited(
      _scroll.animateTo(
        offset,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      ),
    );
  }

  void _reorder(int from, int to) {
    final original = _dragItems ?? _visible;
    _endDrag();
    final latest =
        widget.actions.client.queue?.items ?? const <RemoteQueueEntry>[];
    if (from == to || from >= original.length || to >= original.length) return;
    final moved = original[from].uniqueId;
    final target = original[to].uniqueId;
    if (!latest.any((entry) => entry.uniqueId == moved) ||
        !latest.any((entry) => entry.uniqueId == target)) {
      _message(context, 'The queue changed. Try moving the track again.');
      return;
    }
    unawaited(
      widget.actions.run(
        context,
        () => widget.actions.client.reorderQueue(
          moved,
          target,
          from < to ? QueueEdge.bottom : QueueEdge.top,
        ),
      ),
    );
  }

  void _endDrag() => setState(() {
    _dragItems = null;
    _dragIndex = null;
  });

  @override
  Widget build(BuildContext context) {
    final queue = widget.actions.client.queue;
    if (queue == null) return const SizedBox.shrink();
    _filter(queue.items);
    final visible = _dragItems ?? _visible;
    final actions = widget.actions;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() => _filter(queue.items)),
            decoration: const InputDecoration(
              labelText: 'Filter queue',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
          child: Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: queue.currentId == null ? null : _jumpToCurrent,
                  icon: const Icon(Icons.my_location_rounded),
                  label: const Text('Jump to current'),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: queue.items.isEmpty
                      ? null
                      : () => unawaited(
                          actions.run(
                            context,
                            actions.client.clearQueue,
                            replacesQueue: 'Clear queue',
                          ),
                        ),
                  icon: const Icon(Icons.clear_all_rounded),
                  label: const Text('Clear queue'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Text(
                    _query.isEmpty ? 'Queue is empty' : 'No matching tracks',
                  ),
                )
              : ReorderableListView.builder(
                  scrollController: _scroll,
                  itemCount: visible.length,
                  itemExtent: _rowHeight,
                  buildDefaultDragHandles: false,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  onReorderStart: (index) => setState(() {
                    _dragItems = visible;
                    _dragIndex = index;
                  }),
                  onReorderEnd: (insertion) {
                    // A no-op drop does not call onReorderItem.
                    final from = _dragIndex;
                    if (from == insertion ||
                        (from != null && from + 1 == insertion)) {
                      _endDrag();
                    }
                  },
                  onReorderItem: _reorder,
                  itemBuilder: (context, index) {
                    final entry = visible[index];
                    final id = entry.uniqueId;
                    return Dismissible(
                      key: ValueKey(id),
                      direction: DismissDirection.endToStart,
                      background: ColoredBox(
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: const Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Padding(
                            padding: EdgeInsets.all(AppSpace.md),
                            child: Icon(Icons.remove_circle_outline_rounded),
                          ),
                        ),
                      ),
                      confirmDismiss: (_) async {
                        await actions.run(
                          context,
                          () => actions.client.removeFromQueue(id),
                        );
                        return false;
                      },
                      child: Center(
                        child: _ItemTile(
                          item: entry.item,
                          subtitle: _subtitle(entry.item),
                          icon: Icons.music_note_rounded,
                          selected: id == queue.currentId,
                          onTap: () => unawaited(
                            actions.run(
                              context,
                              () => actions.client.jumpTo(id),
                            ),
                          ),
                          onMenu: () => _showActions(
                            context,
                            actions,
                            RemoteCatalog.tracks,
                            entry.item,
                            queueId: id,
                          ),
                          trailing: Tooltip(
                            message: 'Drag to reorder',
                            child: ReorderableDragStartListener(
                              index: index,
                              child: const SizedBox.square(
                                dimension: AppSize.touch,
                                child: Icon(Icons.drag_handle_rounded),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
