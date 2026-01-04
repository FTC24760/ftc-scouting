import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'send_data.dart';

class PitScoutingPage extends StatefulWidget {
  const PitScoutingPage(
      {Key? key, required this.title, required this.year, required this.api})
      : super(key: key);

  final String title;
  final int year;
  final String api;

  @override
  _PitScoutingState createState() => _PitScoutingState();
}

class _PitScoutingState extends State<PitScoutingPage> {
  Map<String, String> radioValues = {};
  Map<String, dynamic> formFields = {};
  Map<String, bool> fieldErrors = {};
  Map<String, String> textValues = {};

  @override
  void initState() {
    super.initState();
    loadJson();
  }

  Future<void> loadJson() async {
    final String response =
        await rootBundle.loadString("assets/pit/${widget.year}.json");
    final data = await jsonDecode(response);
    setState(() {
      formFields = data;
    });
  }

  bool validateRequiredFields() {
    bool allFieldsValid = true;
    if (formFields['Pit'] == null) return true;

    for (var field in formFields['Pit']) {
      if (field['required'] == true) {
        if (field['type'] == 'radio' &&
            (radioValues[field['name']] == null ||
                radioValues[field['name']]!.isEmpty)) {
          fieldErrors[field['name']] = true;
          allFieldsValid = false;
        } else if ((field['type'] == 'text' || field['type'] == 'number') &&
            (textValues[field['name']] == null ||
                textValues[field['name']]!.trim().isEmpty)) {
          fieldErrors[field['name']] = true;
          allFieldsValid = false;
        } else {
          fieldErrors[field['name']] = false;
        }
      }
    }
    return allFieldsValid;
  }

  void saveAndSend() {
    if (!validateRequiredFields()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please fill out all required fields before saving.')),
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
                          isGame: false,
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

  Map<String, String> getBunchValues() {
    Map<String, String> bunchValues = {};
    if (formFields['Pit'] == null) return bunchValues;

    for (var item in formFields['Pit']) {
      if (item['type'] == "text" || item['type'] == "number") {
        bunchValues[item['name']] = textValues[item['name']] ?? '';
      } else if (item['type'] == "radio") {
        bunchValues[item['name']] = radioValues[item['name']] ?? '';
      }
    }
    return bunchValues;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.medium(
            title: Text(widget.title),
          ),
          if (formFields['Pit'] == null)
            const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()))
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 80),
                child: Card(
                  // This wrapping Card gives it the "Section" look from Match Scouting
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: List.generate(formFields['Pit'].length, (index) {
                        var field = formFields['Pit'][index];
                        return _buildField(field);
                      }),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: saveAndSend,
        label: const Text('Save & Send'),
        icon: const Icon(Icons.send),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildField(Map field) {
    bool showError = fieldErrors[field['name']] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(field['name'],
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          if (field['type'] == 'text' || field['type'] == 'number')
            TextFormField(
              keyboardType: field['type'] == 'number'
                  ? TextInputType.number
                  : TextInputType.text,
              initialValue: textValues[field['name']] ?? '',
              decoration: InputDecoration(
                hintText: field['name'],
                errorText: showError ? 'Required' : null,
              ),
              onChanged: (value) {
                textValues[field['name']] = value;
                if (field['required'] == true) {
                  setState(
                      () => fieldErrors[field['name']] = (value.isEmpty));
                } else {
                  // needed to keep value sync if not required
                  setState(() {}); 
                }
              },
            )
          else if (field['type'] == 'radio')
             Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: (field['choices'] as List).map<Widget>((choice) {
                    return RadioListTile<String>(
                      title: Text(choice),
                      value: choice,
                      activeColor: Theme.of(context).primaryColor,
                      groupValue: radioValues[field['name']],
                      onChanged: (String? value) {
                        if (value != null) {
                          setState(() {
                            radioValues[field['name']] = value;
                            fieldErrors[field['name']] = false;
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
          if (showError && field['type'] == 'radio')
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 12),
              child: Text(
                'Selection required',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}