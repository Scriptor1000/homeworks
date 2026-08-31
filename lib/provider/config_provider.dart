import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// A provider for accessing Firebase Remote Config values.
class ConfigProvider extends ChangeNotifier {
  final FirebaseRemoteConfig _remoteConfig;

  int get maxWidthThreshold => _remoteConfig.getInt('maxWidthThreshold');
  double get maxDayCardWidth => _remoteConfig.getDouble('maxDayCardWidth');
  int get dayCardCount => _remoteConfig.getInt('dayCardCount');

  ConfigProvider({required FirebaseRemoteConfig remoteConfig})
    : _remoteConfig = remoteConfig;

  Future<void> initialize() async {
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(hours: 6),
      ),
    );

    _remoteConfig.setDefaults(<String, dynamic>{
      'maxWidthThreshold': 600,
      'maxDayCardWidth': 400.0,
      'dayCardCount': 3,
    });

    await _remoteConfig.fetchAndActivate();
    notifyListeners();

    _remoteConfig.onConfigUpdated.listen((event) {
      notifyListeners();
    });
  }
}
