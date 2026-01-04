import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ftc_scouting/screens/send_data.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class ScanResultsPage extends StatefulWidget {
  final String title;
  final int year;
  final String api;

  const ScanResultsPage(
      {Key? key, required this.title, required this.year, required this.api})
      : super(key: key);

  @override
  _ScanResultsPageState createState() => _ScanResultsPageState();
}

class _ScanResultsPageState extends State<ScanResultsPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  Barcode? result;
  Map<String, String> resultDataMap = {};
  bool isGame = false;
  QRViewController? controller;

  void sendData(values, isGame) {
    // redirect to `send_data.dart` and pass the data
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              SendData(data: values, isGame: isGame, api: widget.api)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check for unsupported platforms
    bool isDesktop = (kIsWeb ||
        Theme.of(context).platform == TargetPlatform.linux ||
        Theme.of(context).platform == TargetPlatform.macOS ||
        Theme.of(context).platform == TargetPlatform.windows);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Floating effect
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white, 
            shadows: [Shadow(color: Colors.black, blurRadius: 10)]
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (result != null) {
            sendData(resultDataMap, isGame);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("No QR code found!")));
          }
        },
        label: const Text("Process Scan"),
        icon: const Icon(Icons.arrow_forward),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 5,
            child: isDesktop
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.videocam_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Camera is only available on Android/iOS.',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      QRView(
                        key: qrKey,
                        onQRViewCreated: _onQRViewCreated,
                        overlay: QrScannerOverlayShape(
                          borderColor: Theme.of(context).primaryColor,
                          borderRadius: 10,
                          borderLength: 30,
                          borderWidth: 10,
                          cutOutSize: 300,
                        ),
                      ),
                      if (result != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 100),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            "Code Detected!",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        )
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      result = scanData;
      if (result != null) {
        String? resultData = result!.code;
        try {
          Map<String, dynamic> decodedJson = jsonDecode(resultData!);
          resultDataMap =
              decodedJson.map((key, value) => MapEntry(key, value.toString()));
          isGame = resultDataMap['isGame'] == "y" ? true : false;
          resultDataMap.remove("isGame");
          setState(() {}); // Trigger rebuild to show "Code Detected" indicator
        } catch (e) {
          print('Error decoding JSON: $e');
        }
      }
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}