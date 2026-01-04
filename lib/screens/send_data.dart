import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SendData extends StatefulWidget {
  final Map<String, String> data;
  final bool isGame;
  final bool justSend;
  final String api;

  const SendData({
    Key? key,
    required this.data,
    required this.isGame,
    this.justSend = false,
    required this.api,
  }) : super(key: key);

  @override
  _SendDataState createState() => _SendDataState();
}

class _SendDataState extends State<SendData> {
  String? dataString;
  bool showQR = false;
  List<Map> savedGamesArray = [];
  bool isUploading = false;

  @override
  void initState() {
    super.initState();
    getLocalGames();
  }

  Future<void> getLocalGames() async {
    final prefs = await SharedPreferences.getInstance();
    var savedGamesString = prefs.getStringList('savedGames') ?? [];
    setState(() {
      savedGamesArray =
          savedGamesString.map((e) => jsonDecode(e) as Map).toList();
    });
  }

  Future<void> saveDataLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final savedGames = prefs.getStringList('savedGames') ?? [];
    
    // Create a copy of data to avoid modifying the widget's map directly
    Map sillyData = Map.from(widget.data);
    sillyData["isGame"] = widget.isGame ? "y" : "n";
    
    savedGames.add(jsonEncode(sillyData));
    await prefs.setStringList('savedGames', savedGames);
  }

  Future<void> uploadData() async {
    final prefs = await SharedPreferences.getInstance();
    String apiKey = prefs.getString('apiKey') ?? '';

    if (apiKey.isEmpty) {
      if (mounted) _showAlert("Configuration Error", "No API Key found. Please go to Settings in the app and enter your key.");
      return;
    }

    setState(() => isUploading = true);

    // 1. Prepare the queue of data to send
    List<Map> payloadQueue = [];

    // Add locally saved games
    for (var game in savedGamesArray) {
      payloadQueue.add(game);
    }

    // Add current session data (if not empty)
    if (widget.data.isNotEmpty) {
      Map currentData = Map.from(widget.data);
      currentData['isGame'] = widget.isGame ? "y" : "n";
      payloadQueue.add(currentData);
    }

    if (payloadQueue.isEmpty) {
      setState(() => isUploading = false);
      _showAlert("Info", "No data to send.");
      return;
    }

    bool allSuccess = true;
    int successCount = 0;

    // 2. Send each item to the server
    for (var item in payloadQueue) {
      try {
        // Construct URL: http://your-server.com/api/senddata?key=YOUR_KEY
        var uri = Uri.parse("${widget.api}?key=$apiKey");

        var response = await http.post(
          uri,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(item),
        );

        if (response.statusCode == 200) {
          successCount++;
        } else {
          print("Server Error (${response.statusCode}): ${response.body}");
          allSuccess = false;
        }
      } catch (e) {
        print("Network Error: $e");
        allSuccess = false;
      }
    }

    setState(() => isUploading = false);

    // 3. Handle Result
    if (allSuccess) {
      // Clear local storage only if EVERYTHING sent successfully
      await prefs.setStringList('savedGames', []);
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Success"),
            content: Text("Uploaded $successCount matches successfully!"),
            actions: [
              TextButton(
                child: const Text("Done"),
                onPressed: () {
                  Navigator.of(ctx).pop(); // Close Alert
                  Navigator.of(context).pop(); // Return to Home
                },
              )
            ],
          ),
        );
      }
    } else {
      _showAlert(
        "Upload Incomplete",
        "Uploaded $successCount items, but some failed. \n\nCheck your internet connection or API Key. Your data is still saved locally.",
      );
    }
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text("OK"),
            onPressed: () => Navigator.of(ctx).pop(),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.medium(
            title: const Text("Data Summary"),
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Discard & Home',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Return to home?'),
                        content: const Text(
                            'Unsaved data will be lost. Ensure you have saved or uploaded it.',
                            style: TextStyle(color: Colors.red)),
                        actions: [
                          TextButton(
                            child: const Text('Leave'),
                            onPressed: () {
                              Navigator.of(context)
                                  .popUntil((route) => route.isFirst);
                            },
                          ),
                          TextButton(
                            child: const Text('Stay'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.data.isNotEmpty) ...[
                    _buildSectionTitle("Current Match Data"),
                    Card(
                      child: Column(
                        children: widget.data.entries.map((entry) {
                          return ListTile(
                            title: Text(entry.key,
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(entry.value),
                            dense: true,
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  if (widget.justSend && savedGamesArray.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildSectionTitle("Locally Saved Games"),
                    ...savedGamesArray.map((entry) {
                      int index = savedGamesArray.indexOf(entry) + 1;
                      String type =
                          entry["isGame"] == "y" ? "Match" : "Pit";
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ExpansionTile(
                          title: Text("Saved $type Data #$index"),
                          children: [
                            for (var gameValue in entry.entries)
                              if (gameValue.key != "isGame")
                                ListTile(
                                  title: Text(gameValue.key,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500)),
                                  subtitle: Text(gameValue.value.toString()),
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                )
                          ],
                        ),
                      );
                    }).toList(),
                  ],

                  if (showQR && dataString != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Card(
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: QrImageView(
                              data: dataString!,
                              version: QrVersions.auto,
                              size: 200.0,
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 100), // Space for FABs
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (!showQR && !widget.justSend)
            FloatingActionButton(
              heroTag: "qr",
              backgroundColor: Colors.grey.shade800,
              foregroundColor: Colors.white,
              child: const Icon(Icons.qr_code),
              onPressed: () {
                setState(() {
                  Map tempData = Map.from(widget.data);
                  tempData['isGame'] = widget.isGame ? "y" : "n";
                  dataString = jsonEncode(tempData);
                  showQR = true;
                });
              },
            ),
          const SizedBox(width: 12),
          if (!widget.justSend)
            FloatingActionButton(
              heroTag: "archive",
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              child: const Icon(Icons.save_alt),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Save data locally?'),
                      content: const Text(
                          "Data will be saved to this device only. You must upload it later."),
                      actions: [
                        TextButton(
                          child: const Text('Save'),
                          onPressed: () {
                            saveDataLocally();
                            Navigator.of(context)
                                .popUntil((route) => route.isFirst);
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Data saved locally.')));
                          },
                        ),
                        TextButton(
                          child: const Text('Cancel'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: "send",
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            icon: isUploading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.cloud_upload),
            label: Text(isUploading ? "Sending..." : "Upload"),
            onPressed: isUploading
                ? null
                : () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Confirm Upload'),
                          content: const Text(
                              'This sends data to your Secure Server. Ensure you have an internet connection.'),
                          actions: [
                            TextButton(
                              child: const Text('Upload'),
                              onPressed: () {
                                Navigator.of(context).pop();
                                uploadData(); // Calls the new secure function
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
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade600),
      ),
    );
  }
}