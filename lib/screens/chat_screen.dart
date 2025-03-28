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

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TTSService _ttsService = TTSService();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFieldFocus = FocusNode();
  AnimationController? _micAnimationController;
  Animation<double>? _micAnimation;
  bool _isPressingMic = false;
  bool _showTranscription = false;
  String _transcriptionText = "";
  DateTime? _pressStartTime;

  @override
  void initState() {
    super.initState();
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
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textFieldFocus.dispose();
    _micAnimationController?.dispose();
    super.dispose();
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
    
    bool success = await sttService.startListening();
    
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
      
      // Wait for final transcription
      await Future.delayed(Duration(milliseconds: 300));
      
      if (sttService.finalText.isNotEmpty) {
        setState(() {
          _transcriptionText = sttService.finalText;
          _showTranscription = true;
        });
      }
    }
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
                      onPressed: () {
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
                        backgroundColor: Color(0xFF10A37F),
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
          
          Expanded(
            child: TextField(
              focusNode: _textFieldFocus,
              controller: chatService.controller,
              decoration: InputDecoration(
                hintText: "Type or hold mic to speak",
                hintStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              style: TextStyle(color: Colors.white),
              onSubmitted: (_) => chatService.sendMessage(),
            ),
          ),
          
          if (!_isPressingMic && !_showTranscription)
            IconButton(
              icon: Icon(Icons.send, color: Colors.white),
              onPressed: chatService.isTyping 
                ? null 
                : () => chatService.sendMessage(),
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