import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

class ConnectivityState extends ChangeNotifier {
  final InternetConnection _internetConnection = InternetConnection();
  bool _isConnected = true;

  bool get isConnected => _isConnected;

  ConnectivityState() {
    _internetConnection.onStatusChange.listen((InternetStatus status) {
      final connected = status == InternetStatus.connected;
      if (connected != _isConnected) {
        _isConnected = connected;
        notifyListeners();
      }
    });
  }

  /// Check current connectivity status.
  Future<bool> checkNow() async {
    _isConnected = await _internetConnection.hasInternetAccess;
    notifyListeners();
    return _isConnected;
  }
}
