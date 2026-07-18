import 'dart:async';

import 'package:feishin_remote/app_storage.dart';
import 'package:feishin_remote/app_theme.dart';
import 'package:feishin_remote/feishin_remote.dart';
import 'package:feishin_remote/remote_audio_handler.dart';
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

  @override
  void initState() {
    super.initState();
    unawaited(_loadTheme());
  }

  Future<void> _loadTheme() async {
    final useLightTheme = await widget.storage.useLightTheme();
    if (mounted) setState(() => _useLightTheme = useLightTheme);
  }

  Future<void> _toggleTheme() async {
    final useLightTheme = !_useLightTheme;
    setState(() => _useLightTheme = useLightTheme);
    await widget.storage.setUseLightTheme(useLightTheme);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: _useLightTheme ? ThemeMode.light : ThemeMode.dark,
    title: 'Feishin Remote',
    home: _RemoteHome(
      client: widget.client,
      storage: widget.storage,
      useLightTheme: _useLightTheme,
      onToggleTheme: () => unawaited(_toggleTheme()),
    ),
  );
}

class _RemoteHome extends StatefulWidget {
  const _RemoteHome({
    required this.client,
    required this.storage,
    required this.useLightTheme,
    required this.onToggleTheme,
  });

  final FeishinRemoteClient client;
  final AppStorage storage;
  final bool useLightTheme;
  final VoidCallback onToggleTheme;

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
              const Expanded(child: Text('FEISHIN // REMOTE')),
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
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSize.contentMax),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpace.md),
                child: active
                    ? _NowPlaying(client: widget.client)
                    : _ConnectionForm(
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
              _ErrorBanner(message: message),
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
  const _NowPlaying({required this.client});

  final FeishinRemoteClient client;

  @override
  Widget build(BuildContext context) {
    final state = client.state;
    final song = state.song;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (client.errorMessage case final message?) ...[
          _ErrorBanner(message: message),
          const SizedBox(height: AppSpace.md),
        ],
        _Artwork(song: song),
        const SizedBox(height: AppSpace.lg),
        if (song == null)
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
        _VolumeControl(client: client, value: state.volume),
      ],
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.song});

  final FeishinSong? song;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bytes = song?.artworkBytes;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSize.artworkMax),
        child: AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.large),
            child: ColoredBox(
              color: theme.colorScheme.surfaceContainerHigh,
              child: bytes == null
                  ? Icon(
                      Icons.album_rounded,
                      size: AppSize.artworkMax / 2,
                      color: theme.colorScheme.onSurfaceVariant,
                    )
                  : Image.memory(
                      bytes,
                      cacheWidth: AppSize.artworkCacheWidth,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
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
    leading: const Icon(Icons.volume_up_rounded),
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
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(AppRadius.small),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.sm),
        child: SelectionArea(
          child: Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
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
