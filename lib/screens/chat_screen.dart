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
  bool _isPressingMic = false;
  bool _showTranscription = false;
  String _transcriptionText = "";
  bool _isSending = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  
  _micAnimationController = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 1000),
  );
  
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initializeListening();
  });
  }
 Future<void> _initializeListening() async {
  final sttService = Provider.of<STTService>(context, listen: false);
  try {
    // First try normal initialization
    if (!await sttService.initialize()) {
      throw Exception("Failed to initialize speech service");
    }
    
    // Start listening with retry logic
    await _startListeningWithRetry(sttService);
  } catch (e) {
    debugPrint('Initialization error: $e');
    // Automatic retry after delay
    await Future.delayed(Duration(seconds: 2));
    _initializeListening();
  }
}
Future<void> _startListeningWithRetry(STTService sttService, {int retryCount = 0}) async {
  try {
    if (!await sttService.startListening()) {
      throw Exception("Failed to start listening");
    }
  } catch (e) {
    if (retryCount < 3) {
      debugPrint('Retrying listening start (attempt ${retryCount + 1})');
      await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));
      await _startListeningWithRetry(sttService, retryCount: retryCount + 1);
    } else {
      throw Exception("Max retries reached for listening start");
    }
  }
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
  debugPrint('App state changed: $state');
  
  switch (state) {
    case AppLifecycleState.resumed:
      if (!sttService.isListening) {
        _initializeListening();
      }
      break;
    case AppLifecycleState.paused:
      sttService.stopListening();
      break;
    default:
      break;
  }
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



 // In your _buildWakeWordUI method, replace with this improved version:
Widget _buildWakeWordUI(STTService sttService, ChatService chatService) {
  return ListenableBuilder(
    listenable: sttService,
    builder: (context, _) {
      return AnimatedSwitcher(
        duration: Duration(milliseconds: 300),
        child: sttService.isWaitingForWakeWord
            ? _buildWakeWordPrompt()
            : sttService.isActiveListening
                ? _buildActiveListeningUI(sttService, chatService)
                : SizedBox.shrink(),
      );
    },
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
// In ChatScreen
Widget _buildActiveListeningUI(STTService sttService, ChatService chatService) {
  return AnimatedContainer(
    duration: Duration(milliseconds: 200),
    padding: EdgeInsets.all(12),
    margin: EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: Colors.green.withOpacity(0.2),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.green),
    ),
    child: Column(
      children: [
        Row(
          children: [
            sttService.isProcessing
                ? CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.green),
                  )
                : Lottie.asset(
                    'assets/wave_animation.json',
                    width: 60,
                    height: 30,
                    fit: BoxFit.contain,
                  ),
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
                  Text(
                    sttService.currentText.isNotEmpty
                        ? sttService.currentText
                        : "Speak now...",
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: Colors.red),
              onPressed: () async {
                try {
                  await sttService.stopListening();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Returned to wake word mode"),
                      duration: Duration(seconds: 1),
                    ),
                  );
                } catch (e) {
                  debugPrint('Error closing listening: $e');
                  await _initializeListening(); // Full reinitialization if error occurs
                }
              },
            ),
            if (sttService.currentText.isNotEmpty && !sttService.isProcessing)
              IconButton(
                icon: Icon(Icons.send, color: Colors.blue),
                onPressed: () => _sendProcessedTextToAI(sttService, chatService),
              ),
          ],
        ),
        if (sttService.isProcessing)
          LinearProgressIndicator(
            backgroundColor: Colors.green.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation(Colors.green),
          ),
      ],
    ),
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
    // Show bright feedback without restarting
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Listening stopped",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.orange[700], // Bright orange
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: EdgeInsets.all(10),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Error stopping: ${e.toString()}",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red[600], // Bright red
        behavior: SnackBarBehavior.floating,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: EdgeInsets.all(10),
        duration: Duration(seconds: 2),
      ),
    );
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
  if (_isSending || sttService.currentText.isEmpty) return;
  
  _isSending = true;
  try {
    final textToSend = sttService.currentText;
    chatService.controller.text = textToSend;
    await chatService.sendMessage();
    
    // Clear current text but keep listening
    sttService.clearCurrentText();
  } catch (e) {
    debugPrint('Error sending message: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Failed to send message"),
        duration: Duration(seconds: 2),
      ),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: chatService.isTyping 
                          ? Colors.grey 
                          : Color(0xFF10A37F),
                      ),
                      child: Text("Send"),
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
    padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
    child: Row(
      children: [
        
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
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  textStyle: TextStyle(fontSize: 12),
                                ),
                                child: Text("Stop"),
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