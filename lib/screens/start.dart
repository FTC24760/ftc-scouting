import 'package:flutter/material.dart';
import 'package:ftc_scouting/screens/pit_scouting.dart';
import 'package:ftc_scouting/screens/match_scouting.dart';
import 'package:ftc_scouting/screens/scan.dart';
import 'package:ftc_scouting/screens/send_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StartPage extends StatefulWidget {
  const StartPage(
      {super.key, required this.title, required this.year, required this.api});

  final String title;
  final int year;
  final String api;

  @override
  State<StartPage> createState() => _StartState();
}

class _StartState extends State<StartPage> {
  // Navigation functions remain the same...
  void matchScouting() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MatchScoutingPage(
            title: "Match Scouting", year: widget.year, api: widget.api),
      ),
    );
  }

  void pitScouting() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PitScoutingPage(
            title: "Pit Scouting", year: widget.year, api: widget.api),
      ),
    );
  }

  void scanResults() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScanResultsPage(
            title: "Scan Results", year: widget.year, api: widget.api),
      ),
    );
  }

  void sendData() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SendData(data: {}, isGame: true, justSend: true, api: widget.api),
      ),
    );
  }

  // Settings helpers remain the same...
  Future<void> deleteAllGames() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('savedGames');
  }

  Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('apiKey', apiKey);
  }

  Future<void> promptForApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    String apiKey = prefs.getString('apiKey') ?? '';
    bool obscureText = true;

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Enter API Key'),
              content: TextField(
                controller: TextEditingController(text: apiKey),
                obscureText: obscureText,
                onChanged: (value) => apiKey = value,
                decoration: InputDecoration(
                  hintText: "API Key",
                  suffixIcon: IconButton(
                    icon: Icon(
                        obscureText ? Icons.visibility_off : Icons.visibility),
                    onPressed: () {
                      setState(() => obscureText = !obscureText);
                    },
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Save'),
                  onPressed: () {
                    saveApiKey(apiKey);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('API Key saved.')));
                  },
                ),
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(widget.title),
            actions: [
              IconButton(
                onPressed: promptForApiKey,
                icon: const Icon(Icons.settings),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildMenuCard(
                  title: "Match Scouting",
                  icon: Icons.sports_esports,
                  color: Colors.blueAccent,
                  onTap: matchScouting,
                ),
                _buildMenuCard(
                  title: "Pit Scouting",
                  icon: Icons.assignment,
                  color: Colors.orangeAccent,
                  onTap: pitScouting,
                ),
                _buildMenuCard(
                  title: "Scan Results",
                  icon: Icons.qr_code_scanner,
                  color: Colors.purpleAccent,
                  onTap: scanResults,
                ),
                StreamBuilder<List<String>>(
                  stream: Stream.periodic(const Duration(seconds: 1)).asyncMap(
                      (_) => SharedPreferences.getInstance().then(
                          (prefs) => prefs.getStringList('savedGames') ?? [])),
                  builder: (context, snapshot) {
                    int count = snapshot.data?.length ?? 0;
                    return _buildMenuCard(
                      title: "Upload Data",
                      subtitle: "$count saved",
                      icon: Icons.cloud_upload,
                      color: count > 0 ? Colors.green : Colors.grey,
                      onTap: count > 0 ? sendData : null,
                    );
                  },
                ),
              ],
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Delete all local games?'),
                          content: const Text(
                              'This action cannot be undone and deletes all pending uploads.',
                              style: TextStyle(color: Colors.red)),
                          actions: [
                            TextButton(
                              child: const Text('Delete'),
                              onPressed: () {
                                deleteAllGames();
                                Navigator.of(context).pop();
                              },
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.red),
                            ),
                            TextButton(
                              child: const Text('Cancel'),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  label: const Text("Clear Local Data",
                      style: TextStyle(color: Colors.red)),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required String title,
    String? subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 2, // Slight shadow
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}