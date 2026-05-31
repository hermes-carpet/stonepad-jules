import 'package:flutter_test/flutter_test.dart';
import 'package:stonepad/state/connectivity_state.dart';

void main() {
  group('ConnectivityState Tests', () {
    test('Initializes to true', () {
      final state = ConnectivityState();
      expect(state.isConnected, isTrue);
    });
  });
}
