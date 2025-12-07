import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pocketsphinx_flutter/pocketsphinx_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final PocketSphinxWakeWord _pocketSphinx = PocketSphinxWakeWord();
  String _hypothesis = "";
  bool _isListening = false;
  String _status = "Not Initialized";
  Timer? _clearTimer;

  @override
  void initState() {
    super.initState();
    _initPocketSphinx();
  }

  Future<void> _initPocketSphinx() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      
      // Define local paths
      final hmmDir = Directory("${appDir.path}/assets/hmm");
      final dictPath = "${appDir.path}/assets/cmudict.dict";
      final kwsPath = "${appDir.path}/assets/keywords.list";

      // 1. Copy assets to local storage
      await _copyAssets(appDir);

      // 2. Initialize PocketSphinx if assets exist
      if (await hmmDir.exists() && await File(dictPath).exists()) {
        await _pocketSphinx.initialize(
          hmmPath: hmmDir.path,
          dictPath: dictPath,
          kwsPath: await File(kwsPath).exists() ? kwsPath : null,
        );
        
        setState(() {
          _status = "Initialized. Ready.";
        });
      } else {
        setState(() {
          _status = "Error: Assets missing. Please ensure assets are copied correctly.";
        });
        print("Error: Assets missing. Checked paths:\n$hmmDir\n$dictPath\n$kwsPath");
      }

      _pocketSphinx.hypothesisStream.listen((text) {
        setState(() {
          _hypothesis = text;
        });
        
        // Log all processed text
        print("Hypothesis: $text");

        if (text.toLowerCase().contains("hey shredder") || text.toLowerCase().contains("computer")) {
            print(">>> DETECTED KEYWORD: $text <<<");
        }

        // Auto-clear hypothesis after 3 seconds to show new detections
        _clearTimer?.cancel();
        _clearTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) {
                setState(() {
                    _hypothesis = "";
                });
            }
        });
      });
      
    } catch (e) {
      // Use print instead of setting status for cleaner UI if desired,
      // but keeping status updated is good for the user to see success.
      print("Error initializing PocketSphinx: $e");
      setState(() {
        _status = "Initialization Error (Check Logs)";
      });
    }
  }

  Future<void> _copyAssets(Directory appDir) async {
      final assetsDir = Directory("${appDir.path}/assets");
      if (!await assetsDir.exists()) {
          await assetsDir.create(recursive: true);
      }

      // Helper to copy a single file
      Future<void> copyFile(String assetPath, String localPath) async {
          try {
              // Always overwrite for development
              final data = await rootBundle.load(assetPath);
              final List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
              await File(localPath).writeAsBytes(bytes);
              print("Copied asset: $assetPath -> $localPath");
          } catch (e) {
              print("Skipping missing asset: $assetPath ($e)"); 
          }
      }

      // Copy Dictionary and Keyphrase
      await copyFile('assets/cmudict.dict', "${appDir.path}/assets/cmudict.dict");
      await copyFile('assets/keywords.list', "${appDir.path}/assets/keywords.list");

      // Copy HMM directory files
      final hmmLocalDir = Directory("${appDir.path}/assets/hmm");
      if (!await hmmLocalDir.exists()) {
          await hmmLocalDir.create(recursive: true);
      }
      
      final hmmFiles = [
          'mdef',
          'feat.params',
          'mixture_weights',
          'means',
          'variances',
          'transition_matrices',
          'noisedict'
      ];

      for (final file in hmmFiles) {
          await copyFile('assets/hmm/$file', "${hmmLocalDir.path}/$file");
      }
  }

  @override
  void dispose() {
    _pocketSphinx.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    print("Toggle listening pressed. Current state: $_isListening");
    try {
      if (_isListening) {
        print("Stopping listening...");
        await _pocketSphinx.stopListening();
        setState(() {
          _isListening = false;
          _status = "Stopped";
        });
      } else {
        print("Starting listening...");
        // This will fail if initialize() wasn't called successfully
        await _pocketSphinx.startListening();
        print("Listening started successfully.");
        setState(() {
          _isListening = true;
          _status = "Listening...";
        });
      }
    } catch (e) {
       print("Error toggling listening: $e");
       // Optionally don't show full error in UI
       setState(() {
        _status = "Error (Check Logs)";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('PocketSphinx Wrapper'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Status: $_status', textAlign: TextAlign.center),
                const SizedBox(height: 20),
                Text(
                  _hypothesis.isEmpty ? "..." : _hypothesis,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _toggleListening,
                  child: Text(_isListening ? 'Stop Listening' : 'Start Listening'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _processTestFiles,
                  child: const Text('Process Test WAVs'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _processTestFiles() async {
    // final files = ['assets/shreddy_test.wav', 'assets/blank_test.wav'];
    final files = ['assets/blank_test.wav'];
    
    for (final file in files) {
        print("\n--- Processing $file ---");
        try {
            // Ensure assets are loaded
            final data = await rootBundle.load(file);
            final bytes = data.buffer.asUint8List();
            
            // Skip header (44 bytes is standard for WAV)
            int headerSize = 44;
            if (bytes.length <= headerSize) {
                print("WAV file too short: $file");
                continue;
            }
            
            final audioData = bytes.sublist(headerSize);
            print("Sending ${audioData.length} bytes to processor...");
            
            // Use the new method to process external audio
            await _pocketSphinx.processExternalAudio(audioData);
            
            // Wait to separate output logs
            await Future.delayed(const Duration(seconds: 1));
            
        } catch (e) {
            print("Error processing $file: $e");
            setState(() {
                _status = "Error processing $file: $e";
            });
        }
    }
    print("--- Finished Processing All Files ---");
  }
}
