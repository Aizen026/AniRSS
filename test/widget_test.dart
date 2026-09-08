import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anime_torrent_filter/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AnimeTorrentApp());

    expect(find.text('Filtered Anime Feed'), findsOneWidget);
    expect(find.text('Fetch & Filter Feed'), findsOneWidget);
  });

  testWidgets('Rejects invalid URL schemes', (WidgetTester tester) async {
    await tester.pumpWidget(const AnimeTorrentApp());

    // Enter a non-http(s) URL
    await tester.enterText(find.byType(TextField), 'file:///etc/passwd');
    await tester.pump();

    // Tap the fetch button
    await tester.tap(find.text('Fetch & Filter Feed'));
    await tester.pumpAndSettle();

    // Verify the error message is displayed
    expect(
        find.textContaining(
            'Error loading feed: Exception: Invalid URL scheme'),
        findsOneWidget);
  });
}
