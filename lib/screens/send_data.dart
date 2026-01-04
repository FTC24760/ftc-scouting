import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:gsheets/gsheets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SendData extends StatefulWidget {
  final Map<String, String> data;
  final bool isGame;
  final bool justSend;
  final String api;

  const SendData(
      {Key? key,
      required this.data,
      required this.isGame,
      this.justSend = false,
      required this.api})
      : super(key: key);

  @override
  _SendDataState createState() => _SendDataState();
}

class _SendDataState extends State<SendData> {
  String? dataString;
  bool showQR = false;
  bool isCancelled = false;
  List<Map> savedGamesArray = [];

  late GSheets _gsheets;
  late String _spreadsheetId;
  late String _gameWorksheetName;
  late String _pitWorksheetName;

  @override
  void initState() {
    super.initState();
    getLocalGames().then((_) {
      setState(() {}); 
    });
  }

  Future<void> getLocalGames() async {
    final prefs = await SharedPreferences.getInstance();
    var savedGamesString = prefs.getStringList('savedGames') ?? [];
    for (var game in savedGamesString) {
      savedGamesArray.add(jsonDecode(game));
    }
  }

  Future<Map> fetchApi(String key) async {
    var a = await http.get(Uri.parse('${widget.api}?key=$key'));
    if (a.statusCode == 200) {
      return jsonDecode(a.body);
    } else {
      return {"Error": "Invalid API key"};
    }
  }

  Future<void> loadApi() async {
    final prefs = await SharedPreferences.getInstance();
    String apiKey = prefs.getString('apiKey') ?? '';
    Map apiResponse = await fetchApi(apiKey);

    if (apiResponse.containsKey("Error")) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid or no API key entered')),
        );
      }
    } else {
      _gsheets = GSheets(apiResponse["GOOGLE_SHEETS_DATA"]);
      _spreadsheetId = apiResponse["SPREADSHEET_ID"];
      _gameWorksheetName = apiResponse["GAME_WORKSHEET_NAME"];
      _pitWorksheetName = apiResponse["PIT_WORKSHEET_NAME"];
    }
  }

  Future<void> saveDataLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final savedGames = prefs.getStringList('savedGames') ?? [];
    Map sillyData = {}; 
    widget.data.forEach((k, v) => sillyData[k] = v);
    sillyData["isGame"] = widget.isGame ? "y" : "n";
    savedGames.add(jsonEncode(sillyData));
    await prefs.setStringList('savedGames', savedGames);
  }

  Future<void> sendDataToGoogleSheets() async {
    String message = '';

    try {
      final ss = await _gsheets.spreadsheet(_spreadsheetId);
      Worksheet? sheet;
      if (widget.isGame) {
        sheet = ss.worksheetByTitle(_gameWorksheetName);
      } else {
        sheet = ss.worksheetByTitle(_pitWorksheetName);
      }

      if (sheet != null) {
        // Check for locally stored games
        final prefs = await SharedPreferences.getInstance();
        final savedGames = prefs.getStringList('savedGames') ?? [];

        if (savedGames.isEmpty && widget.data.isEmpty) {
          message = "No saved games found.";
        } else {
          // Send locally stored games
          if (widget.isGame || widget.justSend) {
            for (final savedGame in savedGames) {
              Map gameData = jsonDecode(savedGame);
              var curSheet = ss.worksheetByTitle(_pitWorksheetName);
              try {
                if (gameData["isGame"] == "y") {
                  curSheet = ss.worksheetByTitle(_gameWorksheetName);
                }
              } catch (e) {
                message = "Invalid Save Data";
              }
              try {
                gameData.remove("isGame");
              } catch (e) {}
              List<dynamic> values = gameData.values.toList();
              final curRes = await curSheet!.values.appendRow(values);
              if (curRes) {
                message = "Successfully sent saved data!";
              }
            }
            // Clear the saved games after sending them
            await prefs.setStringList('savedGames', []);
          }

          if (widget.data.values.isNotEmpty) {
            // Send current game
            final values = widget.data.values.toList();
            final result = await sheet.values.appendRow(values);
            if (result) {
              message = 'Data sent succesfully, thank you!';
            }
          }
        }
      }
    } catch (e) {
      message = 'Could not send data to sheets!';
      print(e);
    }

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: loadApi(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
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
                                  'Unsaved data will be lost. Ensure you have saved or sent it.',
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
                        if (widget.data.isNotEmpty)
                          _buildSectionTitle("Current Data"),
                        if (widget.data.isNotEmpty)
                          Card(
                            child: Column(
                              children: widget.data.entries.map((entry) {
                                return ListTile(
                                  title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(entry.value),
                                  dense: true,
                                );
                              }).toList(),
                            ),
                          ),
                        
                        if (widget.justSend && savedGamesArray.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _buildSectionTitle("Locally Saved Games"),
                          ...savedGamesArray.map((entry) {
                            int index = savedGamesArray.indexOf(entry) + 1;
                            String type = entry["isGame"] == "y" ? "Match" : "Pit";
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ExpansionTile(
                                title: Text("Saved $type Data #$index"),
                                children: [
                                  for (var gameValue in entry.entries)
                                    if (gameValue.key != "isGame")
                                      ListTile(
                                        title: Text(gameValue.key, style: const TextStyle(fontWeight: FontWeight.w500)),
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
                        
                        // Extra space for FABs
                        const SizedBox(height: 100),
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
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text("Upload"),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Confirm Upload'),
                          content: const Text(
                              'Ensure you have an active internet connection.'),
                          actions: [
                            TextButton(
                              child: const Text('Upload'),
                              onPressed: () {
                                Navigator.of(context).pop();
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (BuildContext context) {
                                    return const AlertDialog(
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircularProgressIndicator(),
                                          SizedBox(height: 16),
                                          Text("Uploading data..."),
                                        ],
                                      ),
                                    );
                                  },
                                );
                                sendDataToGoogleSheets().then((_) {
                                  if (!isCancelled && mounted) {
                                     // Navigator handled in sendDataToGoogleSheets
                                  }
                                });
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
        } else if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else {
          return const Scaffold(
            body: Center(child: Text('Error loading API configuration')),
          );
        }
      },
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