import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:xml/xml.dart' as xml;

void main() => runApp(const AnimeTorrentApp());

class TorrentItem {
  final String title;
  final String magnet;
  TorrentItem({required this.title, required this.magnet});
}

class AnimeTorrentApp extends StatelessWidget {
  const AnimeTorrentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anime Torrent Filter',
      theme: ThemeData.dark(useMaterial3: true),
      home: const FeedScreen(),
    );
  }
}

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final TextEditingController _feedController = TextEditingController(
    text: 'https://nyaa.si/?page=rss',
  );

  List<String> blacklist = ['dual audio', 'dub', '360p', '720p', 'multi'];
  List<TorrentItem> filteredItems = [];
  bool isLoading = false;

  Future<void> fetchAndFilterFeed() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse(_feedController.text));
      if (response.statusCode == 200) {
        final rawXml = xml.XmlDocument.parse(response.body);
        final items = rawXml.findAllElements('item');
        List<TorrentItem> parsed = [];

        for (var node in items) {
          final title = node.findElements('title').single.innerText;
          final link = node.findElements('link').single.innerText;

          bool isBlacklisted = blacklist.any((word) =>
              title.toLowerCase().contains(word.toLowerCase()));

          if (!isBlacklisted) {
            parsed.add(TorrentItem(title: title, magnet: link));
          }
        }
        setState(() => filteredItems = parsed);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading feed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> openTorrentApp(String magnetUrl) async {
    final Uri uri = Uri.parse(magnetUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No torrent client found on device.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Filtered Anime Feed')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: _feedController,
              decoration: const InputDecoration(
                labelText: 'Feed URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8.0,
              children: blacklist.map((word) {
                return Chip(
                  label: Text(word),
                  onDeleted: () => setState(() => blacklist.remove(word)),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: isLoading ? null : fetchAndFilterFeed,
              icon: const Icon(Icons.refresh),
              label: const Text('Fetch & Filter Feed'),
            ),
            const Divider(height: 24),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return Card(
                          child: ListTile(
                            title: Text(item.title, style: const TextStyle(fontSize: 14)),
                            trailing: IconButton(
                              icon: const Icon(Icons.download, color: Colors.green),
                              onPressed: () => openTorrentApp(item.magnet),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
