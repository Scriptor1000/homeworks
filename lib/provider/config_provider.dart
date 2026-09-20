import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const defaultConfig = <String, dynamic>{
  // UI config
  'maxWidthThreshold': 600.0,
  'maxWidthOnTablet': 800.0,
  'maxDayCardWidth': 400.0,
  'minAccountActionTileWidth': 200.0,
  'thresholdShowAccountActionTileHorizontly': 300.0,
  // App config
  'dayCardCount': 5,
  'untisTimetableLoadDays': 30,
  'untisDemoMode': false,
  // Privacy config
  'crashlyticsConsent': false,
  'analyticsConsent': false,
  'performanceConsent': false,
  'consentDialogShown': false,
  'privacyPolicyUrl': 'https://asg-homeworks.pages.dev/privacy-policy.html',
};

/// A provider for accessing configured values from either Firebase Remote Config or local SharedPreferences.
class ConfigProvider extends ChangeNotifier {
  final FirebaseRemoteConfig _remoteConfig;
  final SharedPreferencesWithCache _sharedPreferences;

  bool _remoteConfigInitialized = false;

  ConfigProvider({
    required this._remoteConfig,
    required this._sharedPreferences,
  });

  // UI config
  double get maxWidthThreshold => _getValue<double>('maxWidthThreshold');
  double get maxDayCardWidth => _getValue<double>('maxDayCardWidth');
  double get maxWidthOnTablet => _getValue<double>('maxWidthOnTablet');
  double get minAccountActionTileWidth =>
      _getValue<double>('minAccountActionTileWidth');
  double get thresholdShowAccountActionTileHorizontly =>
      _getValue<double>('thresholdShowAccountActionTileHorizontly');

  // App config
  int get dayCardCount => _getValue<int>('dayCardCount');
  set dayCardCount(int value) => _setValue<int>('dayCardCount', value);
  int get untisTimetableLoadDays => _getValue<int>('untisTimetableLoadDays');
  bool get untisDemoMode => _getValue<bool>('untisDemoMode');
  set untisDemoMode(bool value) => _setValue<bool>('untisDemoMode', value);

  // Privacy config
  String get privacyPolicyUrl => _getValue<String>('privacyPolicyUrl');

  bool get consentDialogShown =>
      _getValue<bool>('consentDialogShown', localOnly: true);
  set consentDialogShown(bool value) =>
      _setValue<bool>('consentDialogShown', value);
  bool get crashlyticsConsent =>
      _getValue<bool>('crashlyticsConsent', localOnly: true);
  set crashlyticsConsent(bool value) =>
      _setValue<bool>('crashlyticsConsent', value);
  bool get analyticsConsent =>
      _getValue<bool>('analyticsConsent', localOnly: true);
  set analyticsConsent(bool value) =>
      _setValue<bool>('analyticsConsent', value);
  bool get performanceConsent =>
      _getValue<bool>('performanceConsent', localOnly: true);
  set performanceConsent(bool value) =>
      _setValue<bool>('performanceConsent', value);

  void _setValue<T>(String key, T value) {
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

  T _getValue<T>(String key, {bool localOnly = false}) {
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
    if (!_remoteConfigInitialized || localOnly) {
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
