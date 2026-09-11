import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const defaultConfig = <String, dynamic>{
  'maxWidthThreshold': 600,
  'maxWidthOnTablet': 800,
  'maxDayCardWidth': 400.0,
  'dayCardCount': 5,
  'untisTimetableLoadDays': 30,
};

/// A provider for accessing configured values from either Firebase Remote Config or local SharedPreferences.
class ConfigProvider extends ChangeNotifier {
  final FirebaseRemoteConfig _remoteConfig;
  final SharedPreferencesWithCache _sharedPreferences;

  bool _remoteConfigInitialized = false;

  ConfigProvider({
    required FirebaseRemoteConfig remoteConfig,
    required SharedPreferencesWithCache sharedPreferences,
  }) : _remoteConfig = remoteConfig,
       _sharedPreferences = sharedPreferences;

  int get maxWidthThreshold => getValue<int>('maxWidthThreshold');
  double get maxDayCardWidth => getValue<double>('maxDayCardWidth');
  double get maxWidthOnTablet => getValue<double>('maxWidthOnTablet');
  int get dayCardCount => getValue<int>('dayCardCount');
  int get untisTimetableLoadDays => getValue<int>('untisTimetableLoadDays');

  set dayCardCount(int value) => setValue<int>('dayCardCount', value);

  void setValue<T>(String key, T value) {
    void Function(String key, T value) setInSharedPreferences = switch (T) {
      const (int) => (key, value) => _sharedPreferences.setInt(
        key,
        value as int,
      ),
      const (double) => (key, value) => _sharedPreferences.setDouble(
        key,
        value as double,
      ),
      const (bool) => (key, value) => _sharedPreferences.setBool(
        key,
        value as bool,
      ),
      const (String) => (key, value) => _sharedPreferences.setString(
        key,
        value as String,
      ),
      _ => throw Exception('Unsupported type $T'),
    };
    setInSharedPreferences(key, value);
    notifyListeners();
  }

  T getValue<T>(String key) {
    T Function(String key) getFromRemote = switch (T) {
      const (int) => (key) => _remoteConfig.getInt(key) as T,
      const (double) => (key) => _remoteConfig.getDouble(key) as T,
      const (bool) => (key) => _remoteConfig.getBool(key) as T,
      const (String) => (key) => _remoteConfig.getString(key) as T,
      _ => throw Exception('Unsupported type $T'),
    };

    T Function(String key) getFromSharedPreferences = switch (T) {
      const (int) => (key) => _sharedPreferences.getInt(key) as T,
      const (double) => (key) => _sharedPreferences.getDouble(key) as T,
      const (bool) => (key) => _sharedPreferences.getBool(key) as T,
      const (String) => (key) => _sharedPreferences.getString(key) as T,
      _ => throw Exception('Unsupported type $T'),
    };

    if (_sharedPreferences.containsKey(key)) {
      return getFromSharedPreferences(key);
    }
    if (!_remoteConfigInitialized) {
      return defaultConfig[key] as T;
    }
    return getFromRemote(key);
  }

  Future<void> initialize() async {
    _remoteConfig.setDefaults(defaultConfig);

    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(hours: 6),
      ),
    );
    await _remoteConfig.fetchAndActivate();

    _remoteConfigInitialized = true;
    notifyListeners();

    _remoteConfig.onConfigUpdated.listen((event) {
      notifyListeners();
    });
  }
}
