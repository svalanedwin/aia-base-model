import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import '../services/chat_service.dart';
import '../services/stt_service.dart';
import '../services/tts_service.dart';

class ChatScreen extends StatelessWidget {
  final TTSService _ttsService = TTSService();

  @override
  Widget build(BuildContext context) {
    final chatService = Provider.of<ChatService>(context);
    final sttService = Provider.of<STTService>(context);

    return Scaffold(
      appBar: AppBar(title: Text("AIA Chatbot")),
      body: Column(
        children: [
          // Display messages with animation
          Expanded(
            child: ListView.builder(
              itemCount: chatService.messages.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: AnimatedTextKit(
                    animatedTexts: [
                      TypewriterAnimatedText(
                        chatService.messages[index],
                        speed: const Duration(milliseconds: 50),
                      ),
                    ],
                  ),
                  onTap: () {
                   _ttsService.speak(chatService.messages[index]);
                  } 
                );
              },
            ),
          ),
          // Input row with speech-to-text functionality
          Row(
            children: [
              // Toggle listening
              IconButton(
                icon: Icon(sttService.isListening ? Icons.mic : Icons.mic_none),
                onPressed: sttService.isListening
                    ? sttService.stopListening
                    : sttService.startListening,
              ),
              Expanded(
                // TextField for typing or showing recognized speech
                child: TextField(
                  controller: chatService.controller,
                  decoration: InputDecoration(
                    hintText: sttService.text.isEmpty
                        ? "Type or speak..."
                        : sttService.text, // Display recognized speech
                  ),
                  onChanged: (value) {
                    // If the user types, clear the STT text
                    sttService.text = value;
                    sttService.notifyListeners();
                  },
                ),
              ),
              // Send message button
              IconButton(
                icon: Icon(Icons.send),
                onPressed: chatService.sendMessage,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
