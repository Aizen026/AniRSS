import 'package:flutter_test/flutter_test.dart';
import 'package:anime_torrent_filter/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AnimeTorrentApp());

    expect(find.text('Filtered Anime Feed'), findsOneWidget);
    expect(find.text('Fetch Feed'), findsOneWidget);
  });
}
