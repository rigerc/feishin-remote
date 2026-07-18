import 'package:flutter/widgets.dart';

abstract final class WidgetKeys {
  static const savedServer = ValueKey('savedServer');
  static const endpoint = ValueKey('endpoint');
  static const username = ValueKey('username');
  static const password = ValueKey('password');
  static const saveServer = ValueKey('saveServer');
  static const deleteServer = ValueKey('deleteServer');
  static const connect = ValueKey('connect');
  static const disconnect = ValueKey('disconnect');
  static const themeToggle = ValueKey('themeToggle');
  static const previous = ValueKey('previous');
  static const playPause = ValueKey('playPause');
  static const next = ValueKey('next');
  static const shuffle = ValueKey('shuffle');
  static const repeat = ValueKey('repeat');
  static const favorite = ValueKey('favorite');
  static const position = ValueKey('position');
  static const volume = ValueKey('volume');

  static ValueKey<String> savedServerFor(String? id) =>
      ValueKey('savedServer_${id ?? 'none'}');

  static ValueKey<String> trackInfoFor(String id) => ValueKey('trackInfo_$id');

  static ValueKey<String> trackDetailsFor(String id) =>
      ValueKey('trackDetails_$id');

  static ValueKey<String> rating(int value) => ValueKey('rating$value');
}
