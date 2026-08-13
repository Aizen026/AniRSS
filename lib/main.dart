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

class AnimeGroup {
  final String title;
  final List<TorrentItem> torrents;
  AnimeGroup({required this.title, required this.torrents});
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

  List<AnimeGroup> animeGroups = [];
  bool isLoading = false;

  String _getCleanTitle(String title) {
    var clean = title.replaceAll(RegExp(r'^\[.*?\]\s*|^\(.*?\)\s*'), '');
    clean = clean.replaceAll(RegExp(r'\.\w{3,4}$'), '');
    clean = clean.replaceAll(RegExp(r'\[.*?\]|\(.*?\)'), '');
    return clean.trim();
  }

  Future<void> fetchAndFilterFeed() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse(_feedController.text));
      if (response.statusCode == 200) {
        var bodyStr = response.body.trim();
        if (!bodyStr.startsWith('<?xml') && !bodyStr.startsWith('<rss')) {
          throw Exception('Invalid RSS feed format (might be HTML or blocked)');
        }
        final rawXml = xml.XmlDocument.parse(bodyStr);
        final items = rawXml.findAllElements('item');

        Map<String, List<TorrentItem>> grouped = {};

        for (var node in items) {
          final title = node.findElements('title').single.innerText;
          final link = node.findElements('link').single.innerText;

          final cleanTitle = _getCleanTitle(title);
          if (!grouped.containsKey(cleanTitle)) {
            grouped[cleanTitle] = [];
          }
          grouped[cleanTitle]!.add(TorrentItem(title: title, magnet: link));
        }

        List<AnimeGroup> parsedGroups = grouped.entries
            .map((e) => AnimeGroup(title: e.key, torrents: e.value))
            .toList();

        setState(() => animeGroups = parsedGroups);
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
            ElevatedButton.icon(
              onPressed: isLoading ? null : fetchAndFilterFeed,
              icon: const Icon(Icons.refresh),
              label: const Text('Fetch Feed'),
            ),
            const Divider(height: 24),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: animeGroups.length,
                      itemBuilder: (context, index) {
                        final group = animeGroups[index];
                        return Card(
                          child: ListTile(
                            title: Text(group.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            subtitle: Text('${group.torrents.length} torrent(s) available'),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AnimeDetailsScreen(group: group),
                                ),
                              );
                            },
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

class AnimeDetailsScreen extends StatefulWidget {
  final AnimeGroup group;
  const AnimeDetailsScreen({super.key, required this.group});

  @override
  State<AnimeDetailsScreen> createState() => _AnimeDetailsScreenState();
}

class _AnimeDetailsScreenState extends State<AnimeDetailsScreen> {
  List<String> blacklist = ['dual audio', 'dub', '360p', '720p', 'multi'];

  Future<void> openTorrentApp(BuildContext context, String magnetUrl) async {
    final Uri uri = Uri.parse(magnetUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No torrent client found on device.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter the torrents based on the blacklist
    List<TorrentItem> filteredTorrents = widget.group.torrents.where((item) {
      return !blacklist.any((word) =>
          item.title.toLowerCase().contains(word.toLowerCase()));
    }).toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.group.title)),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filters (Blacklist):', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              children: blacklist.map((word) {
                return Chip(
                  label: Text(word),
                  onDeleted: () => setState(() => blacklist.remove(word)),
                );
              }).toList(),
            ),
            const Divider(height: 24),
            Expanded(
              child: filteredTorrents.isEmpty
                  ? const Center(child: Text('All torrents filtered out.'))
                  : ListView.builder(
                      itemCount: filteredTorrents.length,
                      itemBuilder: (context, index) {
                        final item = filteredTorrents[index];
                        return Card(
                          child: ListTile(
                            title: Text(item.title, style: const TextStyle(fontSize: 14)),
                            trailing: IconButton(
                              icon: const Icon(Icons.download, color: Colors.green),
                              onPressed: () => openTorrentApp(context, item.magnet),
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
