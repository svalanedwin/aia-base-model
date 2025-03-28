import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' show dotenv;
import 'package:provider/provider.dart';
import 'services/chat_service.dart';
import 'services/stt_service.dart';
import 'screens/chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env"); // Load environment variables

  String apiKey = dotenv.env['GEMINI_API_KEY'] ?? ''; // Fetch API key

  runApp(MyApp(apiKey: apiKey)); // Pass API key to ChatService
}

class MyApp extends StatelessWidget {
  final String apiKey;

  MyApp({required this.apiKey});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatService(apiKey)),
        ChangeNotifierProvider(create: (_) => STTService()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ChatScreen(),
      ),
    );
  }
}
