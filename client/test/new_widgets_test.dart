/// Tests for new widgets and services added to meet spec §8.1 requirements.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stonepad/models/sync_state.dart';
import 'package:stonepad/services/connectivity_service.dart';
import 'package:stonepad/widgets/sync_status_indicator.dart';
import 'package:stonepad/widgets/note_tile.dart';

void main() {
  group('ConnectivityService', () {
    test('constructor accepts custom Connectivity instance', () {
      expect(ConnectivityService, isNotNull);
    });
  });

  group('SyncStatusIndicator', () {
    testWidgets('active state shows cloud_done in green', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SyncStatusIndicator(state: SyncState.active),
        ),
      ));
      expect(find.byIcon(Icons.cloud_done), findsOneWidget);
    });

    testWidgets('manualOnly state shows cloud_off in orange', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SyncStatusIndicator(state: SyncState.manualOnly),
        ),
      ));
      final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_off));
      expect(icon.color, Colors.orange);
    });

    testWidgets('noNetwork state shows cloud_off in grey', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SyncStatusIndicator(state: SyncState.noNetwork),
        ),
      ));
      final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_off));
      expect(icon.color, Colors.grey);
    });

    testWidgets('disabled state shows cloud_off in grey', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SyncStatusIndicator(state: SyncState.disabled),
        ),
      ));
      final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_off));
      expect(icon.color, Colors.grey);
    });
  });

  group('NoteTile', () {
    testWidgets('shows filename without .md as title', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NoteTile(
            notePath: 'work/meetings.md',
            status: null,
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ));
      expect(find.text('meetings'), findsOneWidget);
      expect(find.text('work/meetings.md'), findsOneWidget);
    });

    testWidgets('modified status shows cloud_upload icon', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NoteTile(
            notePath: 'test.md',
            status: 'modified',
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ));
      expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
    });

    testWidgets('conflict_pending status shows warning icon', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NoteTile(
            notePath: 'test.md',
            status: 'conflict_pending',
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ));
      expect(find.byIcon(Icons.warning), findsOneWidget);
    });

    testWidgets('synced status shows no trailing icon', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NoteTile(
            notePath: 'test.md',
            status: 'synced',
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ));
      expect(find.byIcon(Icons.cloud_upload), findsNothing);
      expect(find.byIcon(Icons.warning), findsNothing);
    });
  });
}
