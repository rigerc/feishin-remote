import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef SavedServer = ({String id, String endpoint, String username});

String encodeSavedServer(SavedServer server) => jsonEncode(<String, String>{
  'id': server.id,
  'endpoint': server.endpoint,
  'username': server.username,
});

SavedServer? decodeSavedServer(String encoded) {
  try {
    final Object? value = jsonDecode(encoded);
    if (value is! Map<Object?, Object?>) return null;
    final id = value['id'];
    final endpoint = value['endpoint'];
    final username = value['username'];
    if (id is! String || endpoint is! String || username is! String) {
      return null;
    }
    if (id.isEmpty || endpoint.isEmpty) return null;
    return (id: id, endpoint: endpoint, username: username);
  } on FormatException {
    return null;
  }
}

class AppStorage {
  AppStorage({
    SharedPreferencesAsync? preferences,
    FlutterSecureStorage? secureStorage,
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _secureStorage =
           secureStorage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(storageNamespace: 'feishin_remote'),
           );

  static const _serversKey = 'saved_servers';
  static const _lastServerKey = 'last_server';
  static const _lightThemeKey = 'light_theme';

  final SharedPreferencesAsync _preferences;
  final FlutterSecureStorage _secureStorage;

  Future<List<SavedServer>> loadServers() async {
    final values = await _preferences.getStringList(_serversKey) ?? const [];
    return [for (final value in values) ?decodeSavedServer(value)];
  }

  Future<void> saveServer(SavedServer server, String password) async {
    final servers = await loadServers();
    final index = servers.indexWhere((candidate) => candidate.id == server.id);
    if (index < 0) {
      servers.add(server);
    } else {
      servers[index] = server;
    }
    await _preferences.setStringList(
      _serversKey,
      servers.map(encodeSavedServer).toList(growable: false),
    );
    await _preferences.setString(_lastServerKey, server.id);
    await _secureStorage.write(key: _passwordKey(server.id), value: password);
  }

  Future<void> deleteServer(String id) async {
    final servers = await loadServers()
      ..removeWhere((server) => server.id == id);
    await _preferences.setStringList(
      _serversKey,
      servers.map(encodeSavedServer).toList(growable: false),
    );
    await _secureStorage.delete(key: _passwordKey(id));
    if (await lastServerId() == id) await _preferences.remove(_lastServerKey);
  }

  Future<String> passwordFor(String id) async =>
      await _secureStorage.read(key: _passwordKey(id)) ?? '';

  Future<String?> lastServerId() => _preferences.getString(_lastServerKey);

  Future<void> selectServer(String id) =>
      _preferences.setString(_lastServerKey, id);

  Future<bool> useLightTheme() async =>
      await _preferences.getBool(_lightThemeKey) ?? false;

  Future<void> setUseLightTheme(bool value) =>
      _preferences.setBool(_lightThemeKey, value);

  String _passwordKey(String id) => 'server_password_$id';
}
