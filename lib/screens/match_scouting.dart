import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:async';
import 'send_data.dart';

class MatchScoutingPage extends StatefulWidget {
  const MatchScoutingPage(
      {super.key, required this.title, required this.year, required this.api});

  final String title;
  final int year;
  final String api;

  @override
  State<MatchScoutingPage> createState() => _MatchScoutingState();
}

class _MatchScoutingState extends State<MatchScoutingPage> {
  // ... [KEEP ALL YOUR EXISTING VARIABLE DECLARATIONS AND LOGIC METHODS HERE]
  // ... [Map data = {}; etc...]
  // ... [readJson(), addBoolValue(), etc...]
  // ... [Only Copy/Paste logic methods, do not change them]

  Map data = {};
  Map<String, String> textValues = {};
  Map<String, String> radioControllers = {};
  Map<String, bool> boolValues = {};
  Map<String, int> counterValues = {};
  Map<String, bool> fieldErrors = {};
  Map<String, List<Map>> counterTimestamps = {};
  Timer? _timer;
  int _start = 150;

  void addRadioController(String name, String initValue) {
    if (!radioControllers.keys.contains(name)) {
      radioControllers[name] = initValue;
    }
  }

  Future<void> readJson() async {
    final String response =
        await rootBundle.loadString("assets/games/${widget.year}.json");
    final decodedData = await json.decode(response);
    setState(() {
      data = decodedData;
    });
  }

  void addBoolValue(String name) {
    if (!boolValues.keys.contains(name)) {
      boolValues[name] = false;
    }
  }

  void addCounter(String name) {
    if (!counterValues.keys.contains(name)) {
      counterValues[name] = 0;
    }
    if (!counterTimestamps.keys.contains(name)) {
      counterTimestamps[name] = [];
    }
  }

  void decrementCounter(String name) {
    if ((counterValues[name] ?? 0) > 0) {
      counterValues[name] = counterValues[name]! - 1;
      if (_timer != null) {
        counterTimestamps[name]!.add({
          "action": "decrement",
          "newValue": counterValues[name],
          "timeStamp": _start
        });
      }
    }
  }

  void incrementCounter(String name) {
    if ((counterValues[name] ?? 10000) < 10000) {
      counterValues[name] = counterValues[name]! + 1;
      if (_timer != null) {
        counterTimestamps[name]!.add({
          "action": "increment",
          "newValue": counterValues[name],
          "timeStamp": _start
        });
      }
    }
  }

  void startTimer() {
    if (_timer != null) {
      _timer!.cancel();
    }
    _timer = Timer.periodic(Duration(seconds: 1), (Timer timer) {
      if (_start == 0) {
        setState(() {
          timer.cancel();
          if (_timer != null) {
            _timer!.cancel();
            _timer = null;
          }
        });
      } else {
        setState(() {
          _start--;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    readJson();
  }

  bool validateRequiredFields() {
    bool allFieldsValid = true;

    for (var section in data.entries) {
      for (var item in section.value) {
        if (item.containsKey("required")) {
          if (item['required']) {
            if ((item['type'] == 'text' || item['type'] == 'number') &&
                (textValues[item['name']] == null ||
                    (textValues[item['name']] != null &&
                        textValues[item['name']]!.trim().isEmpty))) {
              fieldErrors[item['name']] = true;
              allFieldsValid = false;
            } else {
              fieldErrors[item['name']] = false;
            }
          }
        }
      }
    }

    return allFieldsValid;
  }

  Map<String, String> getBunchValues() {
    Map<String, String> bunchValues = {};

    for (var section in data.entries) {
      for (var item in section.value) {
        if (item['type'] == "text" || item['type'] == "number") {
          bunchValues[item['name']] = textValues[item['name']] ?? '';
        } else if (item['type'] == "radio") {
          bunchValues[item['name']] = radioControllers[item['name']] ?? '';
        } else if (item['type'] == "bool") {
          bunchValues[item['name']] =
              (boolValues[item['name']] ?? false) ? "Yes" : "No";
        } else if (item['type'] == "counter") {
          bunchValues[item['name']] =
              (counterValues[item['name']] ?? 0).toString();
        }
      }
    }
    bunchValues["Counter Timestamps"] = jsonEncode(counterTimestamps);
    return bunchValues;
  }

  void saveAndSend() {
    if (!validateRequiredFields()) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Missing Fields"),
          content: const Text("Please fill out all the required fields (marked in red) before sending."),
          actions: [
            TextButton(child: const Text("OK"), onPressed: () => Navigator.of(ctx).pop()),
          ],
        ),
      );
      setState(() {});
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmation'),
          content: const Text('Are you sure you want to send the data?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Prepare to send!'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => SendData(
                          data: getBunchValues(),
                          isGame: true,
                          api: widget.api)),
                );
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
  }

  // --- UI STARTS HERE ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: saveAndSend,
        label: const Text('Save & Send'),
        icon: const Icon(Icons.send),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar.medium(
            title: Text(widget.title),
            actions: [
              // Tiny timer indicator in app bar if scrolling
              if (_timer != null)
                Center(
                    child: Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Text(
                    "${(_start / 60).floor()}:${(_start % 60).toString().padLeft(2, '0')}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        fontSize: 16),
                  ),
                ))
            ],
          ),
          if (data.isEmpty)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == 0) return _buildTimerSection();

                  // Adjusted index for data entries
                  final sectionTitle = data.keys.toList()[index - 1].toString();
                  final sectionItems = data.values.toList()[index - 1];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: true,
                          title: Text(
                            sectionTitle,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: List.generate(sectionItems.length,
                                    (itemIndex) {
                                  return _buildFormItem(
                                      sectionItems[itemIndex]);
                                }),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: data.length + 1,
              ),
            ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 80))
        ],
      ),
    );
  }

  Widget _buildTimerSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text("Match Timer",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              "${(_start / 60).floor()}:${(_start % 60).toString().padLeft(2, '0')}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 48,
                fontFeatures: [const FontFeature.tabularFigures()],
                color: _start <= 10 ? Colors.red : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ElevatedButton.icon(
                  onPressed: _timer == null
                      ? startTimer
                      : () {
                          setState(() {
                            if (_timer != null) {
                              _timer!.cancel();
                              _timer = null;
                            }
                          });
                        },
                  icon: Icon(_timer == null ? Icons.play_arrow : Icons.pause),
                  label: Text(_timer == null ? "Start" : "Pause"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _timer == null ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      if (_timer != null) {
                        _timer!.cancel();
                        _timer = null;
                      }
                      _start = 150;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text("Reset"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormItem(Map item) {
    String type = item['type'];
    String name = item['name'];
    bool showError = fieldErrors[name] ?? false;

    // Spacing wrapper
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (type != "bool") ...[
            Text(name,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
          ],

          // Render Logic
          if (type == 'text' || type == 'number')
            TextFormField(
              keyboardType:
                  type == 'number' ? TextInputType.number : TextInputType.text,
              inputFormatters: type == 'number'
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : [],
              initialValue: textValues[name],
              decoration: InputDecoration(
                hintText: item['defaultValue'] ?? '',
                errorText: showError ? 'Required' : null,
              ),
              onChanged: (val) {
                setState(() => textValues[name] = val);
                if (item['required'] == true) {
                  setState(() => fieldErrors[name] = val.isEmpty);
                }
              },
            )
          else if (type == 'radio')
            _buildRadioGroup(item)
          else if (type == 'bool')
            _buildSwitch(item)
          else if (type == 'counter')
            _buildCounter(item)
        ],
      ),
    );
  }

  Widget _buildRadioGroup(Map item) {
    String name = item['name'];
    List choices = item['choices'];
    addRadioController(name, choices[0]);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: List.generate(choices.length, (index) {
          return RadioListTile<String>(
            title: Text(choices[index]),
            value: choices[index],
            activeColor: Theme.of(context).primaryColor,
            groupValue: radioControllers[name],
            onChanged: (val) => setState(() => radioControllers[name] = val!),
          );
        }),
      ),
    );
  }

  Widget _buildSwitch(Map item) {
    String name = item['name'];
    addBoolValue(name);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0), // Added vertical padding for better touch targets
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // WRAP TEXT IN EXPANDED TO PREVENT OVERFLOW
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 12), // Add some space between text and switch
          Switch.adaptive(
            value: boolValues[name] ?? false,
            activeColor: Theme.of(context).primaryColor,
            onChanged: (val) => setState(() => boolValues[name] = val),
          )
        ],
      ),
    );
  }

  Widget _buildCounter(Map item) {
    String name = item['name'];
    addCounter(name);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => setState(() => decrementCounter(name)),
            icon: const Icon(Icons.remove_circle_outline, size: 32),
            color: Colors.red,
          ),
          Text(
            (counterValues[name] ?? 0).toString(),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          IconButton(
            onPressed: () => setState(() => incrementCounter(name)),
            icon: const Icon(Icons.add_circle, size: 32),
            color: Colors.green,
          ),
        ],
      ),
    );
  }
}