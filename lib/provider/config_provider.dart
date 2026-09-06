import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _defaults = <String, dynamic>{
  'maxWidthThreshold': 600,
  'maxWidthOnTablet': 800,
  'maxDayCardWidth': 400.0,
  'dayCardCount': 5,
};

/// A provider for accessing Firebase Remote Config values.
class ConfigProvider extends ChangeNotifier {
  final FirebaseRemoteConfig _remoteConfig;
  final Future<SharedPreferencesWithCache> Function(
    SharedPreferencesWithCacheOptions options,
  )
  _sharedPreferencesFactory;
  SharedPreferencesWithCache? _sharedPreferences;

  int get maxWidthThreshold => getValue<int>('maxWidthThreshold');
  double get maxDayCardWidth => getValue<double>('maxDayCardWidth');
  double get maxWidthOnTablet => getValue<double>('maxWidthOnTablet');
  int get dayCardCount => getValue<int>('dayCardCount');

  set dayCardCount(int value) {
    _sharedPreferences?.setInt('dayCardCount', value);
    notifyListeners();
  }

  ConfigProvider({
    required FirebaseRemoteConfig remoteConfig,
    required Future<SharedPreferencesWithCache> Function(
      SharedPreferencesWithCacheOptions options,
    )
    sharedPreferences,
  }) : _remoteConfig = remoteConfig,
       _sharedPreferencesFactory = sharedPreferences {
    _remoteConfig.setDefaults(_defaults);
  }

  T getValue<T>(String key) {
    T Function(String key) getFromRemote = switch (T) {
      const (int) => (key) => _remoteConfig.getInt(key) as T,
      const (double) => (key) => _remoteConfig.getDouble(key) as T,
      const (bool) => (key) => _remoteConfig.getBool(key) as T,
      const (String) => (key) => _remoteConfig.getString(key) as T,
      _ => throw Exception('Unsupported type $T'),
    };

    if (_sharedPreferences != null && _sharedPreferences!.containsKey(key)) {
      return _sharedPreferences!.get(key) as T;
    }
    return getFromRemote(key);
  }

  Future<void> initialize() async {
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(hours: 6),
      ),
    );
    await _remoteConfig.fetchAndActivate();

    SharedPreferencesWithCacheOptions sharedPreferencesOptions =
        SharedPreferencesWithCacheOptions(allowList: _defaults.keys.toSet());
    _sharedPreferences = await _sharedPreferencesFactory(
      sharedPreferencesOptions,
    );
    notifyListeners();

    _remoteConfig.onConfigUpdated.listen((event) {
      notifyListeners();
    });
  }
}
