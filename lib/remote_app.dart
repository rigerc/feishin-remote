import 'dart:async';

import 'package:feishin_remote/app_storage.dart';
import 'package:feishin_remote/app_theme.dart';
import 'package:feishin_remote/feishin_remote.dart';
import 'package:feishin_remote/remote_audio_handler.dart';
import 'package:feishin_remote/remote_browser.dart';
import 'package:feishin_remote/widget_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RemoteApp extends StatefulWidget {
  const RemoteApp({
    required this.client,
    required this.storage,
    required this.audioHandler,
    super.key,
  });

  final FeishinRemoteClient client;
  final AppStorage storage;
  final RemoteAudioHandler audioHandler;

  @override
  State<RemoteApp> createState() => _RemoteAppState();
}

class _RemoteAppState extends State<RemoteApp> {
  bool _useLightTheme = false;
  bool _matchDesktopAccent = false;
  RemoteAccent? _accent;

  @override
  void initState() {
    super.initState();
    widget.client.addListener(_syncAccent);
    unawaited(_loadTheme());
  }

  @override
  void dispose() {
    widget.client.removeListener(_syncAccent);
    super.dispose();
  }

  void _syncAccent() {
    final accent = _matchDesktopAccent ? widget.client.accent : null;
    if (_accent != accent) setState(() => _accent = accent);
  }

  Future<void> _loadTheme() async {
    final useLightTheme = await widget.storage.useLightTheme();
    final matchDesktopAccent = await widget.storage.matchDesktopAccent();
    if (!mounted) return;
    setState(() {
      _useLightTheme = useLightTheme;
      _matchDesktopAccent = matchDesktopAccent;
      _accent = matchDesktopAccent ? widget.client.accent : null;
    });
  }

  Future<void> _toggleAccent() async {
    final enabled = !_matchDesktopAccent;
    setState(() {
      _matchDesktopAccent = enabled;
      _accent = enabled ? widget.client.accent : null;
    });
    await widget.storage.setMatchDesktopAccent(enabled);
  }

  Future<void> _toggleTheme() async {
    final useLightTheme = !_useLightTheme;
    setState(() => _useLightTheme = useLightTheme);
    await widget.storage.setUseLightTheme(useLightTheme);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(accent: _accent?.light),
    darkTheme: AppTheme.dark(accent: _accent?.dark),
    themeMode: _useLightTheme ? ThemeMode.light : ThemeMode.dark,
    title: 'Feishin Remote',
    home: _RemoteHome(
      client: widget.client,
      storage: widget.storage,
      useLightTheme: _useLightTheme,
      onToggleTheme: () => unawaited(_toggleTheme()),
      matchDesktopAccent: _matchDesktopAccent,
      onToggleAccent: () => unawaited(_toggleAccent()),
    ),
  );
}

class _RemoteHome extends StatefulWidget {
  const _RemoteHome({
    required this.client,
    required this.storage,
    required this.useLightTheme,
    required this.onToggleTheme,
    required this.matchDesktopAccent,
    required this.onToggleAccent,
  });

  final FeishinRemoteClient client;
  final AppStorage storage;
  final bool useLightTheme;
  final VoidCallback onToggleTheme;
  final bool matchDesktopAccent;
  final VoidCallback onToggleAccent;

  @override
  State<_RemoteHome> createState() => _RemoteHomeState();
}

class _RemoteHomeState extends State<_RemoteHome> {
  final _endpoint = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  List<SavedServer> _servers = const [];
  String? _selectedServerId;
  String? _storageMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_loadServers(autoConnect: true));
  }

  @override
  void dispose() {
    _endpoint.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _loadServers({bool autoConnect = false}) async {
    try {
      final servers = await widget.storage.loadServers();
      final lastServerId = await widget.storage.lastServerId();
      final selected = servers
          .where((server) => server.id == lastServerId)
          .firstOrNull;
      if (!mounted) return;
      setState(() {
        _servers = servers;
        _selectedServerId = selected?.id;
        _storageMessage = null;
      });
      if (selected != null) {
        await _selectServer(selected.id, connect: autoConnect);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _storageMessage = 'Saved servers could not be loaded.');
      }
    }
  }

  Future<void> _selectServer(String? id, {bool connect = false}) async {
    if (id == null) return;
    final server = _servers
        .where((candidate) => candidate.id == id)
        .firstOrNull;
    if (server == null) return;

    try {
      final password = await widget.storage.passwordFor(id);
      if (!mounted) return;
      _endpoint.text = server.endpoint;
      _username.text = server.username;
      _password.text = password;
      setState(() {
        _selectedServerId = id;
        _storageMessage = null;
      });
      await widget.storage.selectServer(id);
      if (connect) _connect();
    } catch (_) {
      if (mounted) {
        setState(
          () => _storageMessage = 'The saved password could not be read.',
        );
      }
    }
  }

  Future<void> _saveServer() async {
    try {
      normalizeRemoteUri(_endpoint.text);
      final selected = _servers
          .where((server) => server.id == _selectedServerId)
          .firstOrNull;
      final matching = _servers
          .where(
            (server) =>
                server.endpoint == _endpoint.text.trim() &&
                server.username == _username.text.trim(),
          )
          .firstOrNull;
      final id =
          selected?.id ??
          matching?.id ??
          DateTime.now().microsecondsSinceEpoch.toString();
      final server = (
        id: id,
        endpoint: _endpoint.text.trim(),
        username: _username.text.trim(),
      );
      await widget.storage.saveServer(server, _password.text);
      if (!mounted) return;
      await _loadServers();
      if (mounted) _showMessage('Server saved securely.');
    } on FormatException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('Server could not be saved.');
    }
  }

  Future<void> _deleteServer() async {
    final id = _selectedServerId;
    if (id == null) return;
    try {
      await widget.storage.deleteServer(id);
      if (!mounted) return;
      _endpoint.clear();
      _username.clear();
      _password.clear();
      setState(() => _selectedServerId = null);
      await _loadServers();
      if (mounted) _showMessage('Saved server deleted.');
    } catch (_) {
      if (mounted) _showMessage('Saved server could not be deleted.');
    }
  }

  void _connect() {
    unawaited(
      widget.client.connect(
        endpoint: _endpoint.text,
        username: _username.text,
        password: _password.text,
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.client,
    builder: (context, _) {
      final active = widget.client.connection != RemoteConnection.disconnected;
      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Image.asset(
                'assets/logo.png',
                width: AppSize.touch,
                height: AppSize.touch,
                cacheWidth: AppSize.artworkCacheWidth,
              ),
              const SizedBox(width: AppSpace.xs),
              const Expanded(
                child: Text(
                  'FEISHIN // REMOTE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              key: WidgetKeys.themeToggle,
              onPressed: widget.onToggleTheme,
              tooltip: widget.useLightTheme
                  ? 'Use dark theme'
                  : 'Use light theme',
              icon: Icon(
                widget.useLightTheme
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
              ),
            ),
            _ConnectionStatus(connection: widget.client.connection),
            if (active)
              IconButton(
                key: WidgetKeys.disconnect,
                onPressed: () => unawaited(widget.client.disconnect()),
                tooltip: 'Disconnect',
                icon: const Icon(Icons.link_off_rounded),
              ),
            const SizedBox(width: AppSpace.xs),
          ],
        ),
        body: SafeArea(
          child: active
              ? _ConnectedRemote(
                  key: ValueKey(widget.client.session),
                  client: widget.client,
                  matchDesktopAccent: widget.matchDesktopAccent,
                  onToggleAccent: widget.onToggleAccent,
                )
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppSize.contentMax,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpace.md),
                      child: _ConnectionForm(
                        client: widget.client,
                        servers: _servers,
                        selectedServerId: _selectedServerId,
                        endpoint: _endpoint,
                        username: _username,
                        password: _password,
                        storageMessage: _storageMessage,
                        onSelectServer: _selectServer,
                        onSaveServer: () => unawaited(_saveServer()),
                        onDeleteServer: _selectedServerId == null
                            ? null
                            : () => unawaited(_deleteServer()),
                        onConnect: _connect,
                      ),
                    ),
                  ),
                ),
        ),
      );
    },
  );
}

enum _Destination { playing, library, playlists, radio, queue }

class _ConnectedRemote extends StatefulWidget {
  const _ConnectedRemote({
    required this.client,
    required this.matchDesktopAccent,
    required this.onToggleAccent,
    super.key,
  });

  final FeishinRemoteClient client;
  final bool matchDesktopAccent;
  final VoidCallback onToggleAccent;

  @override
  State<_ConnectedRemote> createState() => _ConnectedRemoteState();
}

class _ConnectedRemoteState extends State<_ConnectedRemote> {
  late final _actions = RemoteActions(widget.client);
  final _visited = {_Destination.playing};
  _Destination _selected = _Destination.playing;

  void _select(_Destination destination) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selected = destination;
      _visited.add(destination);
    });
  }

  @override
  void dispose() {
    _actions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    final expanded = client.expanded && client.online;
    final selected = expanded ? _selected : _Destination.playing;
    return Column(
      children: [
        if ((expanded, client.errorMessage) case (true, final String message))
          Padding(
            padding: const EdgeInsets.all(AppSpace.sm),
            child: _ErrorBanner(
              message: message,
              onDismiss: client.dismissError,
            ),
          ),
        ListenableBuilder(
          listenable: _actions,
          builder: (context, _) => _actions.value
              ? const LinearProgressIndicator()
              : const SizedBox.shrink(),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSize.contentMax),
              child: IndexedStack(
                index: selected.index,
                sizing: StackFit.expand,
                children: [
                  for (final destination in _Destination.values)
                    TickerMode(
                      enabled: destination == selected,
                      child:
                          _visited.contains(destination) &&
                              (expanded || destination == _Destination.playing)
                          ? switch (destination) {
                              _Destination.playing => SingleChildScrollView(
                                padding: const EdgeInsets.all(AppSpace.md),
                                child: _NowPlaying(
                                  client: client,
                                  onShowQueue: () =>
                                      _select(_Destination.queue),
                                  matchDesktopAccent: widget.matchDesktopAccent,
                                  onToggleAccent: widget.onToggleAccent,
                                ),
                              ),
                              _Destination.library => RemoteLibraryView(
                                actions: _actions,
                              ),
                              _Destination.playlists => RemoteCatalogView(
                                catalog: RemoteCatalog.playlists,
                                actions: _actions,
                              ),
                              _Destination.radio => RemoteCatalogView(
                                catalog: RemoteCatalog.radio,
                                actions: _actions,
                              ),
                              _Destination.queue => RemoteQueueView(
                                actions: _actions,
                              ),
                            }
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (expanded &&
            MediaQuery.viewInsetsOf(context).bottom == 0 &&
            selected != _Destination.playing &&
            (client.state.song != null || client.radio != null))
          _MiniPlayer(
            client: client,
            onTap: () => _select(_Destination.playing),
          ),
        if (expanded)
          NavigationBar(
            selectedIndex: selected.index,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (index) =>
                _select(_Destination.values[index]),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.play_circle_outline_rounded),
                label: 'Playing',
              ),
              NavigationDestination(
                icon: Icon(Icons.library_music_outlined),
                label: 'Library',
              ),
              NavigationDestination(
                icon: Icon(Icons.playlist_play_rounded),
                label: 'Playlists',
              ),
              NavigationDestination(
                icon: Icon(Icons.radio_rounded),
                label: 'Radio',
              ),
              NavigationDestination(
                icon: Icon(Icons.queue_music_rounded),
                label: 'Queue',
              ),
            ],
          ),
      ],
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({required this.client, required this.onTap});

  final FeishinRemoteClient client;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final song = client.state.song;
    final radio = client.radio;
    final playing = client.state.status == 'playing';
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: ListTile(
        onTap: onTap,
        leading: RemoteThumbnail(
          image: radio == null ? song?.image : radio.image,
          bytes: radio == null ? song?.artworkBytes : null,
          icon: radio == null ? Icons.album_rounded : Icons.radio_rounded,
        ),
        title: Text(
          radio?.name ?? song?.name ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          radio != null ? 'Radio' : song?.artistName ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (radio == null)
              IconButton(
                tooltip: 'Previous track',
                onPressed: () => client.send('previous'),
                icon: const Icon(Icons.skip_previous_rounded),
              ),
            IconButton(
              tooltip: playing ? 'Pause' : 'Play',
              onPressed: () => client.send(playing ? 'pause' : 'play'),
              icon: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
            ),
            if (radio == null)
              IconButton(
                tooltip: 'Next track',
                onPressed: () => client.send('next'),
                icon: const Icon(Icons.skip_next_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({required this.connection});

  final RemoteConnection connection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (connection) {
      RemoteConnection.connected => ('LIVE', theme.colorScheme.primary),
      RemoteConnection.connecting => ('LINKING', theme.colorScheme.tertiary),
      RemoteConnection.reconnecting => ('RETRY', theme.colorScheme.tertiary),
      RemoteConnection.disconnected => ('OFFLINE', theme.colorScheme.outline),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: AppSize.connectionIcon, color: color),
          const SizedBox(width: AppSpace.xs),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _ConnectionForm extends StatelessWidget {
  const _ConnectionForm({
    required this.client,
    required this.servers,
    required this.selectedServerId,
    required this.endpoint,
    required this.username,
    required this.password,
    required this.storageMessage,
    required this.onSelectServer,
    required this.onSaveServer,
    required this.onDeleteServer,
    required this.onConnect,
  });

  final FeishinRemoteClient client;
  final List<SavedServer> servers;
  final String? selectedServerId;
  final TextEditingController endpoint;
  final TextEditingController username;
  final TextEditingController password;
  final String? storageMessage;
  final ValueChanged<String?> onSelectServer;
  final VoidCallback onSaveServer;
  final VoidCallback? onDeleteServer;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connecting = client.connection == RemoteConnection.connecting;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Image.asset(
                'assets/logo.png',
                width: AppSize.logo,
                height: AppSize.logo,
                cacheWidth: AppSize.artworkCacheWidth,
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Text('Link to Feishin', style: theme.textTheme.headlineMedium),
            const SizedBox(height: AppSpace.xs),
            Text(
              'Enable Remote under Feishin Settings → Window, then enter the computer address and port.',
              style: theme.textTheme.bodyLarge,
            ),
            if (servers.isNotEmpty) ...[
              const SizedBox(height: AppSpace.lg),
              DropdownButtonFormField<String>(
                key: WidgetKeys.savedServerFor(selectedServerId),
                initialValue: selectedServerId,
                decoration: const InputDecoration(
                  labelText: 'Saved server',
                  prefixIcon: Icon(Icons.bookmarks_outlined),
                ),
                items: [
                  for (final server in servers)
                    DropdownMenuItem(
                      value: server.id,
                      child: Text(
                        server.username.isEmpty
                            ? server.endpoint
                            : '${server.username} · ${server.endpoint}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: connecting ? null : onSelectServer,
              ),
            ],
            const SizedBox(height: AppSpace.lg),
            TextField(
              key: WidgetKeys.endpoint,
              controller: endpoint,
              enabled: !connecting,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Remote URL',
                hintText: 'http://192.168.1.20:4333',
                prefixIcon: Icon(Icons.lan_rounded),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            TextField(
              key: WidgetKeys.username,
              controller: username,
              enabled: !connecting,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Username (optional)',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            TextField(
              key: WidgetKeys.password,
              controller: password,
              enabled: !connecting,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: connecting ? null : (_) => onConnect(),
              decoration: const InputDecoration(
                labelText: 'Password (optional)',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: WidgetKeys.saveServer,
                    onPressed: connecting ? null : onSaveServer,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save server'),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                IconButton(
                  key: WidgetKeys.deleteServer,
                  onPressed: connecting ? null : onDeleteServer,
                  tooltip: 'Delete saved server',
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              'Passwords are encrypted by Android. Plain HTTP still exposes credentials in transit; use a trusted network or HTTPS/WSS.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (storageMessage case final message?) ...[
              const SizedBox(height: AppSpace.md),
              _ErrorBanner(
                message: message,
                onDismiss: client.online ? client.dismissError : null,
              ),
            ],
            if (client.errorMessage case final message?) ...[
              const SizedBox(height: AppSpace.md),
              _ErrorBanner(message: message),
            ],
            const SizedBox(height: AppSpace.lg),
            FilledButton.icon(
              key: WidgetKeys.connect,
              onPressed: connecting ? null : onConnect,
              icon: connecting
                  ? const SizedBox.square(
                      dimension: AppSpace.md,
                      child: CircularProgressIndicator(
                        strokeWidth: AppSpace.xxs,
                      ),
                    )
                  : const Icon(Icons.link_rounded),
              label: Text(connecting ? 'Connecting…' : 'Connect'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NowPlaying extends StatelessWidget {
  const _NowPlaying({
    required this.client,
    required this.onShowQueue,
    required this.matchDesktopAccent,
    required this.onToggleAccent,
  });

  final FeishinRemoteClient client;
  final VoidCallback onShowQueue;
  final bool matchDesktopAccent;
  final VoidCallback onToggleAccent;

  @override
  Widget build(BuildContext context) {
    final state = client.state;
    final song = state.song;
    final radio = client.radio;
    final playing = state.status == 'playing';
    final next = client.upNext;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if ((!client.expanded, client.errorMessage) case (
          true,
          final String message,
        )) ...[
          _ErrorBanner(message: message),
          const SizedBox(height: AppSpace.md),
        ],
        _Artwork(
          title: radio?.name ?? song?.name,
          image: radio == null ? song?.image : radio.image,
          bytes: radio == null ? song?.artworkBytes : null,
          radio: radio != null,
          onError: radio == null ? client.requestArtwork : null,
          onFullscreen: (context, artwork) => showDialog<void>(
            context: context,
            builder: (dialog) => Dialog.fullscreen(
              child: Scaffold(
                appBar: AppBar(
                  title: Text(radio?.name ?? song?.name ?? 'Artwork'),
                  leading: CloseButton(onPressed: () => Navigator.pop(dialog)),
                ),
                body: Center(child: InteractiveViewer(child: artwork)),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        if (radio != null) ...[
          Text(
            radio.name,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            'Internet radio',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.sm),
          Center(
            child: IconButton.filled(
              tooltip: playing ? 'Pause' : 'Play',
              onPressed: () => client.send(playing ? 'pause' : 'play'),
              icon: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
            ),
          ),
        ] else if (song == null)
          const _IdleState()
        else ...[
          _TrackInfo(
            key: WidgetKeys.trackInfoFor(song.id),
            client: client,
            song: song,
          ),
          const SizedBox(height: AppSpace.md),
          _RatingControl(client: client, song: song),
          const SizedBox(height: AppSpace.lg),
          _TransportControls(client: client, state: state),
          const SizedBox(height: AppSpace.sm),
          _ModeControls(client: client, state: state),
          const SizedBox(height: AppSpace.lg),
          _ProgressControl(client: client, state: state),
        ],
        const SizedBox(height: AppSpace.lg),
        if (client.online) _VolumeControl(client: client, value: state.volume),
        if (next != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: onShowQueue,
            leading: RemoteThumbnail(
              image: next.image,
              icon: Icons.music_note_rounded,
            ),
            title: Text(
              next.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: const Text('Up next in queue'),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        if (client.expanded)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Match desktop accent'),
            value: matchDesktopAccent,
            onChanged: (_) => onToggleAccent(),
          ),
      ],
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({
    required this.title,
    required this.image,
    required this.bytes,
    required this.radio,
    required this.onError,
    required this.onFullscreen,
  });

  final String? title;
  final Uri? image;
  final Uint8List? bytes;
  final bool radio;
  final VoidCallback? onError;
  final void Function(BuildContext, Widget) onFullscreen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = Icon(
      radio ? Icons.radio_rounded : Icons.album_rounded,
      size: AppSize.artworkMax / 2,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final artwork = bytes != null
        ? Image.memory(
            bytes!,
            cacheWidth: AppSize.artworkCacheWidth,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => placeholder,
          )
        : image != null
        ? Image.network(
            image.toString(),
            cacheWidth: AppSize.artworkCacheWidth,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) onError?.call();
              });
              return placeholder;
            },
          )
        : placeholder;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSize.artworkMax),
        child: AspectRatio(
          aspectRatio: 1,
          child: Material(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadius.large),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: bytes == null && image == null
                  ? null
                  : () => onFullscreen(context, artwork),
              child: Semantics(
                label: title == null ? null : 'Artwork for $title',
                child: artwork,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IdleState extends StatelessWidget {
  const _IdleState();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        children: [
          const Icon(Icons.music_off_rounded, size: AppSize.transportIcon),
          const SizedBox(height: AppSpace.sm),
          Text(
            'Nothing playing',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpace.xs),
          const Text('Start playback in Feishin to control it here.'),
        ],
      ),
    ),
  );
}

class _TrackInfo extends StatefulWidget {
  const _TrackInfo({required this.client, required this.song, super.key});

  final FeishinRemoteClient client;
  final FeishinSong song;

  @override
  State<_TrackInfo> createState() => _TrackInfoState();
}

class _TrackInfoState extends State<_TrackInfo> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final song = widget.song;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineMedium,
                  ),
                  if (song.artistName.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.xs),
                    Text(song.artistName, style: theme.textTheme.titleMedium),
                  ],
                  if (song.album.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.xxs),
                    Text(
                      song.album,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              key: WidgetKeys.trackDetailsFor(song.id),
              onPressed: () => setState(() => _showDetails = !_showDetails),
              tooltip: _showDetails
                  ? 'Hide track details'
                  : 'Show track details',
              icon: Icon(
                _showDetails
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
              ),
            ),
            IconButton(
              key: WidgetKeys.favorite,
              onPressed: () => _command(
                client: widget.client,
                event: 'favorite',
                data: <String, Object?>{
                  'id': song.id,
                  'favorite': !song.favorite,
                },
              ),
              tooltip: song.favorite ? 'Remove favorite' : 'Add favorite',
              icon: Icon(
                song.favorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
              ),
              color: song.favorite ? theme.colorScheme.primary : null,
            ),
          ],
        ),
        if (_showDetails) ...[
          const SizedBox(height: AppSpace.md),
          _TrackMetadata(details: song.details),
        ],
      ],
    );
  }
}

class _TrackMetadata extends StatelessWidget {
  const _TrackMetadata({required this.details});

  final FeishinTrackDetails details;

  @override
  Widget build(BuildContext context) {
    final values = <({String label, String value})>[
      if (details.releaseYear > 0)
        (label: 'Year', value: details.releaseYear.toString()),
      if (details.genres.isNotEmpty) (label: 'Genre', value: details.genres),
      if (details.container.isNotEmpty)
        (label: 'Format', value: details.container.toUpperCase()),
      if (details.bitRate > 0)
        (label: 'Bitrate', value: '${details.bitRate} kbps'),
      if (details.sampleRate > 0)
        (label: 'Sample rate', value: '${details.sampleRate / 1000} kHz'),
      if (details.bitDepth > 0)
        (label: 'Bit depth', value: '${details.bitDepth}-bit'),
      if (details.trackNumber > 0)
        (label: 'Track', value: details.trackNumber.toString()),
      if (details.discNumber > 0)
        (label: 'Disc', value: details.discNumber.toString()),
      (label: 'Plays', value: details.playCount.toString()),
    ];

    return Wrap(
      spacing: AppSpace.sm,
      runSpacing: AppSpace.sm,
      children: [
        for (final value in values)
          _DetailTile(label: value.label, value: value.value),
      ],
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: AppSize.detailMinWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpace.xxs),
              Text(value, style: theme.textTheme.titleSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _RatingControl extends StatelessWidget {
  const _RatingControl({required this.client, required this.song});

  final FeishinRemoteClient client;
  final FeishinSong song;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var rating = 0; rating <= 5; rating++)
        IconButton(
          key: WidgetKeys.rating(rating),
          onPressed: () => _command(
            client: client,
            event: 'rating',
            data: <String, Object?>{'id': song.id, 'rating': rating},
          ),
          tooltip: rating == 0 ? 'Clear rating' : 'Rate $rating stars',
          icon: Icon(
            rating == 0
                ? Icons.close_rounded
                : rating <= song.rating
                ? Icons.star_rounded
                : Icons.star_border_rounded,
          ),
        ),
    ],
  );
}

class _TransportControls extends StatelessWidget {
  const _TransportControls({required this.client, required this.state});

  final FeishinRemoteClient client;
  final FeishinState state;

  @override
  Widget build(BuildContext context) {
    final playing = state.status == 'playing';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton.filledTonal(
          key: WidgetKeys.previous,
          onPressed: () => _command(client: client, event: 'previous'),
          tooltip: 'Previous track',
          icon: const Icon(Icons.skip_previous_rounded),
        ),
        IconButton.filled(
          key: WidgetKeys.playPause,
          iconSize: AppSize.transportIcon,
          onPressed: () =>
              _command(client: client, event: playing ? 'pause' : 'play'),
          tooltip: playing ? 'Pause' : 'Play',
          icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
        ),
        IconButton.filledTonal(
          key: WidgetKeys.next,
          onPressed: () => _command(client: client, event: 'next'),
          tooltip: 'Next track',
          icon: const Icon(Icons.skip_next_rounded),
        ),
      ],
    );
  }
}

class _ModeControls extends StatelessWidget {
  const _ModeControls({required this.client, required this.state});

  final FeishinRemoteClient client;
  final FeishinState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          key: WidgetKeys.shuffle,
          onPressed: () => _command(client: client, event: 'shuffle'),
          tooltip: state.shuffle ? 'Shuffle on' : 'Shuffle off',
          color: state.shuffle ? colors.primary : null,
          icon: const Icon(Icons.shuffle_rounded),
        ),
        const SizedBox(width: AppSpace.lg),
        IconButton(
          key: WidgetKeys.repeat,
          onPressed: () => _command(client: client, event: 'repeat'),
          tooltip: 'Repeat ${state.repeat}',
          color: state.repeat == 'none' ? null : colors.primary,
          icon: Icon(
            state.repeat == 'one'
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
          ),
        ),
      ],
    );
  }
}

class _ProgressControl extends StatelessWidget {
  const _ProgressControl({required this.client, required this.state});

  final FeishinRemoteClient client;
  final FeishinState state;

  @override
  Widget build(BuildContext context) {
    final duration =
        (state.song?.durationMs ?? 0) / Duration.millisecondsPerSecond;
    if (duration <= 0) return const SizedBox.shrink();

    return _LabeledSlider(
      sliderKey: WidgetKeys.position,
      value: state.position,
      max: duration,
      leading: Text(_formatDuration(state.position)),
      trailing: Text(_formatDuration(duration)),
      onChangeEnd: (value) => _command(
        client: client,
        event: 'position',
        data: <String, Object?>{'position': value},
      ),
    );
  }
}

class _VolumeControl extends StatelessWidget {
  const _VolumeControl({required this.client, required this.value});

  final FeishinRemoteClient client;
  final double value;

  @override
  Widget build(BuildContext context) => _LabeledSlider(
    sliderKey: WidgetKeys.volume,
    value: value,
    max: 100,
    leading: IconButton(
      tooltip: value > 0 ? 'Mute' : 'Unmute',
      onPressed: client.toggleMute,
      icon: Icon(
        value > 0 ? Icons.volume_up_rounded : Icons.volume_off_rounded,
      ),
    ),
    trailing: Text(value.round().toString()),
    onChangeEnd: (volume) => _command(
      client: client,
      event: 'volume',
      data: <String, Object?>{'volume': volume},
    ),
  );
}

class _LabeledSlider extends StatefulWidget {
  const _LabeledSlider({
    required this.sliderKey,
    required this.value,
    required this.max,
    required this.leading,
    required this.trailing,
    required this.onChangeEnd,
  });

  final Key sliderKey;
  final double value;
  final double max;
  final Widget leading;
  final Widget trailing;
  final ValueChanged<double> onChangeEnd;

  @override
  State<_LabeledSlider> createState() => _LabeledSliderState();
}

class _LabeledSliderState extends State<_LabeledSlider> {
  late double _value = widget.value;
  bool _dragging = false;

  @override
  void didUpdateWidget(covariant _LabeledSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging) _value = widget.value;
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: AppSize.touch,
        child: Center(child: widget.leading),
      ),
      Expanded(
        child: Slider(
          key: widget.sliderKey,
          value: _value.clamp(0, widget.max).toDouble(),
          max: widget.max,
          onChangeStart: (_) => _dragging = true,
          onChanged: (value) => setState(() => _value = value),
          onChangeEnd: (value) {
            _dragging = false;
            widget.onChangeEnd(value);
          },
        ),
      ),
      SizedBox(
        width: AppSize.touch,
        child: Center(child: widget.trailing),
      ),
    ],
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, this.onDismiss});

  final String message;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(AppRadius.small),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.sm),
        child: Row(
          children: [
            Expanded(
              child: SelectionArea(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                tooltip: 'Dismiss message',
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

void _command({
  required FeishinRemoteClient client,
  required String event,
  Map<String, Object?> data = const {},
}) {
  unawaited(HapticFeedback.selectionClick());
  client.send(event, data);
}

String _formatDuration(double seconds) {
  final duration = Duration(seconds: seconds.round());
  final minutes = duration.inMinutes;
  final remainingSeconds = duration.inSeconds.remainder(
    Duration.secondsPerMinute,
  );
  return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
}
