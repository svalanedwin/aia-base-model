import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' show dotenv;
import 'package:provider/provider.dart';
import 'services/chat_service.dart';
import 'services/stt_service.dart';
import 'screens/chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName:".env"); // Load environment variables
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatService()),
        ChangeNotifierProvider(create: (_) => STTService()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ChatScreen(),
      ),
    );
  }
}
