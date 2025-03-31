import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:lottie/lottie.dart';
import '../services/chat_service.dart';
import '../services/stt_service.dart';
import '../services/tts_service.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  final TTSService _ttsService = TTSService();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFieldFocus = FocusNode();
  AnimationController? _micAnimationController;
  Animation<double>? _micAnimation;
  bool _isPressingMic = false;
  bool _showTranscription = false;
  String _transcriptionText = "";
  DateTime? _pressStartTime;
  bool _isSending = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _micAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );
    
    _micAnimation = Tween(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _micAnimationController!,
        curve: Curves.easeInOut,
      ),
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatService = Provider.of<ChatService>(context, listen: false);
      chatService.addListener(_scrollToBottom);
      _initializeListening();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _textFieldFocus.dispose();
    _micAnimationController?.dispose();
    final sttService = Provider.of<STTService>(context, listen: false);
    sttService.stopListening();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final sttService = Provider.of<STTService>(context, listen: false);
    if (state == AppLifecycleState.resumed) {
      _initializeListening();
    } else if (state == AppLifecycleState.paused) {
      sttService.stopListening();
    }
  }

  Future<void> _initializeListening() async {
    final sttService = Provider.of<STTService>(context, listen: false);
    await sttService.initialize();
    await sttService.startListening();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _onMicPressed(STTService sttService, ChatService chatService) async {
    _pressStartTime = DateTime.now();
    setState(() {
      _isPressingMic = true;
      _showTranscription = false;
    });
    _micAnimationController?.repeat(reverse: true);
    
    // Clear previous text
    sttService.clearText();
    chatService.controller.clear();
    
    bool success = await sttService.startListening(forceListen: true);
    
    if (!mounted) return;
    
    if (!success) {
      _ttsService.speak("Couldn't start recording. Please check microphone permissions.");
      _micAnimationController?.stop();
      setState(() => _isPressingMic = false);
    }
  }

  void _onMicReleased(STTService sttService, ChatService chatService) async {
    setState(() => _isPressingMic = false);
    _micAnimationController?.stop();
    
    if (sttService.isListening) {
      await sttService.stopListening();
      
      if (sttService.finalText.isNotEmpty && !sttService.isWaitingForWakeWord) {
        setState(() {
          _transcriptionText = sttService.finalText;
          _showTranscription = true;
        });
      }
      
      // Restart listening for wake word
      _initializeListening();
    }
  }

 // In your _buildWakeWordUI method, replace with this improved version:
Widget _buildWakeWordUI(STTService sttService, ChatService chatService) {
  return AnimatedSwitcher(
    duration: Duration(milliseconds: 300),
    child: sttService.isWaitingForWakeWord
        ? _buildWakeWordPrompt()
        : sttService.isActiveListening
            ? _buildActiveListeningUI(sttService, chatService)
            : SizedBox(key: ValueKey('empty')),
  );
}

Widget _buildWakeWordPrompt() {
  return Container(
    key: ValueKey('wake-word'),
    padding: EdgeInsets.all(12),
    margin: EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: Colors.blue.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.blue.withOpacity(0.3)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.mic, color: Colors.blue, size: 20),
        SizedBox(width: 8),
        Text(
          "Say 'Hey' to activate voice",
          style: TextStyle(color: Colors.blue),
        ),
      ],
    ),
  );
}
Widget _buildActiveListeningUI(STTService sttService, ChatService chatService) {
  return ListenableBuilder(
    listenable: sttService,
    builder: (context, _) {
      String displayText = _processTextAfterWakeWord(sttService.currentText);
      
      return AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.all(12),
        margin: EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _buildListeningIndicator(sttService),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sttService.isProcessing ? "Processing..." : "Listening...",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      AnimatedSwitcher(
                        duration: Duration(milliseconds: 150),
                        child: displayText.isNotEmpty
                            ? Text(
                                key: ValueKey(displayText),
                                displayText,
                                style: TextStyle(color: Colors.white70),
                              )
                            : Text(
                                "Speak now",
                                style: TextStyle(color: Colors.white70),
                              ),
                      ),
                    ],
                  ),
                ),
                ..._buildActionButtons(sttService, chatService, displayText),
              ],
            ),
            if (sttService.isProcessing) _buildProcessingIndicator(),
          ],
        ),
      );
    },
  );
}
String _processTextAfterWakeWord(String rawText) {
  if (rawText.isEmpty) return "";
  
  // Case-insensitive search for first 'hey'
  final lowerText = rawText.toLowerCase();
  final heyIndex = lowerText.indexOf('hey');
  
  if (heyIndex == -1) return ""; // No hey found
  
  // Get text after hey and clean it up
  String processedText = rawText.substring(heyIndex + 3).trim();
  
  // Additional cleanup:
  // 1. Remove any leading/trailing punctuation
  processedText = processedText.replaceAll(RegExp(r'^[^\w]+|[^\w]+$'), '');
  // 2. Remove any remaining 'hey' occurrences
  processedText = processedText.replaceAll(RegExp(r'\bhey\b', caseSensitive: false), '');
  // 3. Normalize whitespace
  processedText = processedText.replaceAll(RegExp(r'\s+'), ' ').trim();
  
  return processedText;
}

// Add these helper methods to your _ChatScreenState class:
Future<void> _stopListeningWithFeedback(STTService sttService) async {
  try {
    await sttService.stopListening();
    // Show brief feedback without restarting
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Listening stopped"),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error stopping: ${e.toString()}")),
    );
  }
}

Future<void> _sendAndStopListening(STTService sttService, ChatService chatService) async {
  setState(() {
    sttService.setProcessing(true);
  });
  
  try {
    // Stop listening first
    await sttService.stopListening();
    
    // Only send if we have text
    if (sttService.currentText.isNotEmpty) {
      chatService.controller.text = sttService.currentText;
      await chatService.sendMessage();
    }
    
    await Future.delayed(Duration(milliseconds: 300)); // Smooth transition
  } catch (e) {
    print('Error sending message: $e');
  } finally {
    if (mounted) {
      setState(() {
        sttService.setProcessing(false);
      });
    }
  }
}
Widget _buildListeningIndicator(STTService sttService) {
  return sttService.isProcessing
      ? SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
          ),
        )
      : Lottie.asset(
          'assets/wave_animation.json',
          width: 60,
          height: 30,
          fit: BoxFit.contain,
        );
}
List<Widget> _buildActionButtons(STTService sttService, ChatService chatService, String displayText) {
  if (sttService.isProcessing) return [];
  
  return [
    IconButton(
      icon: Icon(Icons.close, color: Colors.grey),
      onPressed: () async {
        await _stopListeningWithFeedback(sttService);
      },
    ),
    if (displayText.isNotEmpty)
      IconButton(
        icon: Icon(Icons.send, color: Colors.blue),
        onPressed: () async {
          await _sendProcessedTextToAI(sttService, chatService);
        },
      ),
  ];
}
Future<void> _sendProcessedTextToAI(STTService sttService, ChatService chatService) async {
  if (_isSending) return;
  _isSending = true;

  try {
    String processedText = _processTextAfterWakeWord(sttService.currentText);
    
    if (processedText.isNotEmpty) {
      // Clear text immediately
      sttService.clearText();
      
      // Send to AI
      chatService.controller.text = processedText;
      await chatService.sendMessage();
      
      // Stop listening and reset to wake word mode
      await sttService.stopListening();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Message sent!"),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Failed to send: ${e.toString()}")),
    );
  } finally {
    _isSending = false;
  }
}
Widget _buildProcessingIndicator() {
  return Padding(
    padding: const EdgeInsets.only(top: 8.0),
    child: LinearProgressIndicator(
      backgroundColor: Colors.green.withOpacity(0.2),
      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
    ),
  );
}

  Widget _buildTranscriptionUI(ChatService chatService) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 300),
      child: _showTranscription
        ? Container(
            key: ValueKey('transcription'),
            padding: EdgeInsets.all(16),
            margin: EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Color(0xFF40414F),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(text: _transcriptionText),
                        onChanged: (value) => _transcriptionText = value,
                        maxLines: 3,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: "Edit your message...",
                          hintStyle: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white70),
                      onPressed: () {
                        setState(() {
                          _showTranscription = false;
                          _transcriptionText = "";
                        });
                      },
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: chatService.isTyping
                        ? null
                        : () {
                            if (_transcriptionText.isNotEmpty) {
                              chatService.controller.text = _transcriptionText;
                              chatService.sendMessage();
                              setState(() {
                                _showTranscription = false;
                                _transcriptionText = "";
                              });
                            }
                          },
                      child: Text("Send"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: chatService.isTyping 
                          ? Colors.grey 
                          : Color(0xFF10A37F),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        : SizedBox(key: ValueKey('empty')),
    );
  }

  Widget _buildInputField(ChatService chatService, STTService sttService) {
  return Container(
    color: Color(0xFF40414F),
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(
      children: [
        GestureDetector(
          onTapDown: (_) => _onMicPressed(sttService, chatService),
          onTapUp: (_) => _onMicReleased(sttService, chatService),
          onTapCancel: () => _onMicReleased(sttService, chatService),
          child: AnimatedBuilder(
            animation: _micAnimationController!,
            builder: (context, child) {
              return Transform.scale(
                scale: _isPressingMic ? _micAnimation!.value : 1.0,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isPressingMic ? Colors.red.withOpacity(0.2) : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPressingMic ? Icons.mic : Icons.mic_none,
                    color: _isPressingMic ? Colors.red : Colors.white,
                  ),
                ),
              );
            },
          ),
        ),

        // Input Field
        Expanded(
          child: TextField(
            focusNode: _textFieldFocus,
            controller: chatService.controller,
            decoration: InputDecoration(
              hintText: "Type your message...",
              hintStyle: TextStyle(color: Colors.white70),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
            style: TextStyle(color: Colors.white),
            onSubmitted: (_) {
              if (!chatService.isTyping && chatService.controller.text.isNotEmpty) {
                chatService.sendMessage();
              }
            },
          ),
        ),

        // Send Button
        if (!_isPressingMic)
          IconButton(
            icon: Icon(Icons.send, color: chatService.isTyping ? Colors.grey : Colors.white),
            onPressed: chatService.isTyping
                ? null
                : () {
                    if (chatService.controller.text.isNotEmpty) {
                      chatService.sendMessage();
                    }
                  },
          ),
      ],
    ),
  );
}


  Widget _buildRecordingIndicator(STTService sttService) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 300),
      child: _isPressingMic
        ? Container(
            key: ValueKey('recording'),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Color(0xFF40414F),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 120,
                      height: 60,
                      child: Lottie.asset(
                        'assets/wave_animation.json',
                        fit: BoxFit.contain,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Listening...",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Release to confirm",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.cancel, color: Colors.grey),
                      onPressed: () {
                        Provider.of<STTService>(context, listen: false).stopListening();
                        setState(() => _isPressingMic = false);
                        _initializeListening();
                      },
                    ),
                  ],
                ),
              ],
            ),
          )
        : SizedBox(key: ValueKey('no-recording')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatService = Provider.of<ChatService>(context);
    final sttService = Provider.of<STTService>(context);

    return Scaffold(
      backgroundColor: Color(0xFF343541),
      appBar: AppBar(
        title: Text("AIA Chatbot", 
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white
          )
        ),
        backgroundColor: Color(0xFF40414F),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.menu, color: Colors.white),
          onPressed: () {},
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              chatService.clearMessages();
              setState(() {
                _showTranscription = false;
                _transcriptionText = "";
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildWakeWordUI(sttService,chatService),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.only(top: 10),
                itemCount: chatService.messages.length,
                itemBuilder: (context, index) {
                  final isUserMessage = chatService.messages[index].role == "user";
                  return Container(
                    color: isUserMessage ? Color(0xFF40414F) : Color(0xFF343541),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: isUserMessage ? Color(0xFF10A37F) : Color(0xFFECECF1),
                            borderRadius: BorderRadius.circular(4)),
                          child: Center(
                            child: Icon(
                              isUserMessage ? Icons.person : Icons.smart_toy,
                              color: isUserMessage ? Colors.white : Color(0xFF343541),
                              size: 18,
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isUserMessage ? "You" : "AIA Assistant",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14
                                ),
                              ),
                              SizedBox(height: 4),
                              if (isUserMessage)
                                Text(
                                  chatService.messages[index].content,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15
                                  ),
                                )
                              else
                                AnimatedTextKit(
                                  animatedTexts: [
                                    TyperAnimatedText(
                                      chatService.messages[index].content,
                                      textStyle: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        height: 1.5
                                      ),
                                      speed: Duration(milliseconds: 10),
                                    ),
                                  ],
                                  isRepeatingAnimation: false,
                                  totalRepeatCount: 1,
                                ),
                              SizedBox(height: 8),
                              if (!isUserMessage)
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.volume_up, 
                                        size: 18,
                                        color: Colors.white70),
                                      onPressed: () {
                                        _ttsService.speak(chatService.messages[index].content);
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.copy, 
                                        size: 18,
                                        color: Colors.white70),
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(
                                          text: chatService.messages[index].content));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text("Copied to clipboard")));
                                      },
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            if (chatService.isTyping)
              Container(
                color: Color(0xFF40414F),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Color(0xFFECECF1),
                        borderRadius: BorderRadius.circular(4)),
                      child: Center(
                        child: Icon(
                          Icons.smart_toy,
                          color: Color(0xFF343541),
                          size: 18,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "AIA Assistant",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14
                            ),
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Lottie.asset(
                                "assets/typing.json",
                                width: 40,
                                height: 20,
                                fit: BoxFit.fitWidth,
                              ),
                              SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: chatService.stopResponse,
                                child: Text("Stop"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  textStyle: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            _buildTranscriptionUI(chatService),
            _buildRecordingIndicator(sttService),
            _buildInputField(chatService, sttService),
          ],
        ),
      ),
    );
  }
}