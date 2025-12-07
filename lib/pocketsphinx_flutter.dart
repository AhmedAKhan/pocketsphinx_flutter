import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
import 'package:record/record.dart';

import 'pocketsphinx_flutter_bindings_generated.dart';

const String _libName = 'pocketsphinx_flutter';

/// The dynamic library in which the symbols for [PocketsphinxFlutterBindings] can be found.
final ffi.DynamicLibrary _dylib = () {
  if (Platform.isIOS) {
    return ffi.DynamicLibrary.process();
  }
  if (Platform.isMacOS) {
    return ffi.DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return ffi.DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return ffi.DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

/// The bindings to the native functions in [_dylib].
final PocketsphinxFlutterBindings _bindings = PocketsphinxFlutterBindings(_dylib);

class PocketSphinxWakeWord {
  ffi.Pointer<ps_decoder_t>? _decoder;
  final AudioRecorder _audioRecorder = AudioRecorder();
  Isolate? _recognitionIsolate;
  SendPort? _isolateSendPort;
  StreamSubscription? _audioStreamSubscription;

  // Stream controller to expose hypothesis results to the UI
  final _hypothesisController = StreamController<String>.broadcast();
  Stream<String> get hypothesisStream => _hypothesisController.stream;

  Future<void> initialize({
    required String hmmPath,
    required String dictPath,
    String? kwsPath,
  }) async {
    final hmm = hmmPath.toNativeUtf8();
    final dict = dictPath.toNativeUtf8();
    final kws = kwsPath?.toNativeUtf8() ?? ffi.nullptr.cast();

    try {
      _decoder = _bindings.initialize_recognizer(hmm.cast(), dict.cast(), kws.cast());
      if (_decoder == ffi.nullptr) {
        throw Exception("Failed to initialize PocketSphinx decoder");
      }
    } finally {
      malloc.free(hmm);
      malloc.free(dict);
      if (kwsPath != null) {
        malloc.free(kws);
      }
    }
  }

  Future<void> _ensureIsolateRunning() async {
    if (_recognitionIsolate != null) return;

    final receivePort = ReceivePort();
    _recognitionIsolate = await Isolate.spawn(
      _recognitionIsolateEntryPoint,
      _IsolateInitMessage(receivePort.sendPort, _decoder!.address),
    );

    // Wait for the isolate to send its SendPort
    final completer = Completer<SendPort>();
    receivePort.listen((message) {
      if (message is SendPort) {
        completer.complete(message);
      } else if (message is String) {
        _hypothesisController.add(message);
      }
    });
    _isolateSendPort = await completer.future;
  }

  Future<void> startListening() async {
    if (_decoder == null) {
      throw Exception("Recognizer not initialized. Call initialize() first.");
    }

    if (await _audioRecorder.hasPermission()) {
      // 1. Start the processing isolate
      await _ensureIsolateRunning();

      // 2. Start audio stream
      final stream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      // 3. Forward audio data to the isolate
      _audioStreamSubscription = stream.listen((data) {
        _isolateSendPort?.send(data);
      });
    } else {
      throw Exception("Microphone permission denied");
    }
  }

  Future<void> processExternalAudio(Uint8List data) async {
    if (_decoder == null) {
      throw Exception("Recognizer not initialized. Call initialize() first.");
    }
    await _ensureIsolateRunning();
    _isolateSendPort?.send(data);
  }

  Future<void> stopListening() async {
    await _audioStreamSubscription?.cancel();
    await _audioRecorder.stop();
    _isolateSendPort?.send('STOP'); // Signal isolate to stop processing
    
    // We don't kill the isolate immediately to allow it to process remaining data/cleanup if needed,
    // but for now, we'll just clean up the isolate.
    _recognitionIsolate?.kill();
    _recognitionIsolate = null;
    _isolateSendPort = null;
  }

  void dispose() {
    stopListening();
    if (_decoder != null) {
      _bindings.free_recognizer(_decoder!);
      _decoder = null;
    }
    _hypothesisController.close();
    _audioRecorder.dispose();
  }

  static void _recognitionIsolateEntryPoint(_IsolateInitMessage initMessage) {
    // Re-create bindings in the isolate
    
    final ffi.DynamicLibrary isolateDylib = () {
      if (Platform.isIOS) {
        return ffi.DynamicLibrary.process();
      }
      if (Platform.isMacOS) {
        return ffi.DynamicLibrary.open('pocketsphinx_flutter.framework/pocketsphinx_flutter');
      }
      if (Platform.isAndroid || Platform.isLinux) {
        return ffi.DynamicLibrary.open('libpocketsphinx_flutter.so');
      }
      if (Platform.isWindows) {
        return ffi.DynamicLibrary.open('pocketsphinx_flutter.dll');
      }
      throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
    }();

    final bindings = PocketsphinxFlutterBindings(isolateDylib);
    final decoder = ffi.Pointer<ps_decoder_t>.fromAddress(initMessage.decoderAddress);
    final sendPort = initMessage.sendPort;
    final receivePort = ReceivePort();

    // Notify main isolate about our receive port
    sendPort.send(receivePort.sendPort);

    bindings.start_processing(decoder);
    
    receivePort.listen((message) {
      if (message is Uint8List) {
        // Process audio chunk
        // Allocate native memory for the chunk
        final numSamples = message.length ~/ 2; // 16-bit audio = 2 bytes per sample
        
        // Remove manual header skipping - we will trust the stream gives raw PCM
        // and fix the ByteData view below.
        
        final audioPtr = malloc<ffi.Int16>(numSamples);
        
        // Correctly create ByteData view respecting the list's offset and length
        final byteData = message.buffer.asByteData(message.offsetInBytes, message.lengthInBytes);
        
        String sampleDebug = "";
        String hexDebug = ""; // Debug first few bytes in HEX
        double sumSquare = 0;

        for (int i = 0; i < numSamples; i++) {
          int val = byteData.getInt16(i * 2, Endian.little);
          audioPtr[i] = val;
          sumSquare += val * val;
          if (i < 10) {
              sampleDebug += "$val, ";
              // Show bytes in hex
              int b1 = byteData.getUint8(i*2);
              int b2 = byteData.getUint8(i*2 + 1);
              hexDebug += "${b1.toRadixString(16).padLeft(2, '0')}${b2.toRadixString(16).padLeft(2, '0')} ";
          }
        }
        
        double rms = math.sqrt(sumSquare / numSamples);
        // Print everything for debugging "blank" file
        print("Chunk: $numSamples samples, RMS: ${rms.toStringAsFixed(2)}.\n   Samples: $sampleDebug\n   HEX: $hexDebug");

        bindings.process_audio_chunk(decoder, audioPtr, numSamples);
        
        // Check for hypothesis
        final hyp = bindings.get_hypothesis(decoder);
        if (hyp != ffi.nullptr) {
          final hypString = hyp.cast<Utf8>().toDartString();
          if (hypString.isNotEmpty) {
            sendPort.send(hypString);
            
            // KEY CHANGE: Reset the recognizer to clear the hypothesis and be ready for the next one.
            // This is crucial for Keyword Spotting (KWS) mode to detect the same word multiple times.
            bindings.stop_processing(decoder);
            bindings.start_processing(decoder);
          }
        }

        malloc.free(audioPtr);
      } else if (message == 'STOP') {
        bindings.stop_processing(decoder);
      }
    });
  }
}

class _IsolateInitMessage {
  final SendPort sendPort;
  final int decoderAddress;

  _IsolateInitMessage(this.sendPort, this.decoderAddress);
}
