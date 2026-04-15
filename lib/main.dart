import 'package:flutter/material.dart';
import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() => runApp(const MaterialApp(home: FaceScreen(), debugShowCheckedModeBanner: false));

class FaceScreen extends StatefulWidget {
  const FaceScreen({super.key});
  @override
  State<FaceScreen> createState() => _FaceScreenState();
}

class _FaceScreenState extends State<FaceScreen> with TickerProviderStateMixin {
  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  late final GenerativeModel _model;
  
  final String apiKey = 'AIzaSyAAy0yGTgFxcB0Tutgifp56HbculHRnJWE'; 
  final String modelName = 'gemini-3-flash-preview'; 

  String _text = "Ek baar tap karein\nPhir lagatar baat karein";
  bool _isThinking = false;
  bool _isTalking = false;
  bool _isListening = false;

  late AnimationController _eyeController;
  late Animation<double> _eyeAnimation;
  Timer? _mouthTimer;
  double mouthHeight = 15.0;
  Color glowColor = Colors.cyanAccent;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _model = GenerativeModel(model: modelName, apiKey: apiKey);

    _eyeController = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat(reverse: true);
    _eyeAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(CurvedAnimation(parent: _eyeController, curve: Curves.easeInOut));

    _initVoiceEngine();
  }

  void _initVoiceEngine() async {
    await _tts.setLanguage("hi-IN");
    await _tts.setSpeechRate(0.5);
    
    _tts.setStartHandler(() {
      setState(() { _isTalking = true; _isListening = false; });
      _startMouthAnimation();
    });

    _tts.setCompletionHandler(() {
      _stopMouthAnimation();
      setState(() { _isTalking = false; glowColor = Colors.cyanAccent; });
      // ADVANCE: Bolne ke turant baad mic automatic on!
      Future.delayed(const Duration(milliseconds: 500), () => _startAutoListening());
    });
  }

  // --- AUTO LISTEN LOGIC ---
  void _startAutoListening() async {
    if (_isTalking || _isThinking) return;

    bool available = await _speech.initialize(
      onStatus: (s) {
        print("Status: $s");
        if (s == 'done' && !_isThinking && !_isTalking) {
           _startAutoListening(); // Reset mic if it stops without result
        }
      },
    );

    if (available) {
      setState(() { 
        _isListening = true; 
        glowColor = Colors.blueAccent;
        _text = "Main sun raha hoon..."; 
      });

      _speech.listen(
        onResult: (val) {
          setState(() => _text = val.recognizedWords);
          if (val.finalResult && val.recognizedWords.isNotEmpty) {
            _handleSequence(val.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 2), // 2 sec silence matlab aapne bol liya
      );
    }
  }

  void _handleSequence(String input) async {
    await _speech.stop();
    _askGemini(input);
  }

  Future<void> _askGemini(String prompt) async {
    setState(() { 
      _isThinking = true; 
      _isListening = false;
      _text = "Soch raha hoon..."; 
      glowColor = Colors.orangeAccent; 
    });

    try {
      final response = await _model.generateContent([
        Content.text("User: $prompt. Jawab natural Hindi mein 1 line mein do.")
      ]);

      String reply = response.text?.replaceAll('*', '') ?? "Maaf kijiye.";
      
      setState(() { 
        _text = reply; 
        _isThinking = false; 
        glowColor = Colors.greenAccent; 
      });

      await _tts.speak(reply);

    } catch (e) {
      setState(() { _isThinking = false; _text = "Error! Connection check karein."; });
      _startAutoListening();
    }
  }

  void _startMouthAnimation() {
    _mouthTimer?.cancel();
    _mouthTimer = Timer.periodic(const Duration(milliseconds: 150), (t) {
      setState(() => mouthHeight = (mouthHeight == 15.0) ? 60.0 : 15.0);
    });
  }

  void _stopMouthAnimation() {
    _mouthTimer?.cancel();
    setState(() { mouthHeight = 15.0; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          _tts.stop();
          _startAutoListening(); // Pehli baar jagane ke liye tap karein
        },
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [eyeWidget(), const SizedBox(width: 60), eyeWidget()]),
              const SizedBox(height: 100), mouth(), const SizedBox(height: 60),
              Padding(padding: const EdgeInsets.all(20), child: Text(_text, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
              if (!_isListening && !_isThinking && !_isTalking)
                const Text("START CONVERSATION", style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget eyeWidget() => ScaleTransition(scale: _eyeAnimation, child: Container(width: 100, height: 120, decoration: BoxDecoration(color: glowColor, borderRadius: BorderRadius.circular(50), boxShadow: [BoxShadow(color: glowColor.withOpacity(0.6), blurRadius: 30)])));
  Widget mouth() => AnimatedContainer(duration: const Duration(milliseconds: 150), width: 200, height: mouthHeight, decoration: BoxDecoration(color: glowColor, borderRadius: BorderRadius.circular(20)));
}