# AIA Base Model

## AIA Conversational Assistant App

### Overview
A cross-platform mobile application that enables real-time conversational AI interactions using speech-to-text (STT) and text-to-speech (TTS) technologies. The app integrates with Google's STT API and Gemini AI for natural language processing.

### Features
- 🎙️ **Voice-to-text input** with wake word ("Hey") detection
- 🔊 **Text-to-speech** responses
- 🤖 **AI-powered conversational interface**
- 📱 **Cross-platform support** (iOS & Android)
- 🔄 **Real-time interaction** with minimal latency
- 🎨 **Clean, intuitive UI**

---

## Technical Stack

- **Framework:** Flutter (Dart)
- **Speech-to-Text:** `speech_to_text` package
- **Text-to-Speech:** `flutter_tts` package
- **AI Backend:** Google Gemini API
- **State Management:** Provider

---

## Setup Instructions

### Prerequisites
- Flutter SDK (latest stable version)
- Dart SDK
- Android Studio/Xcode (for emulator/simulator)
- Google Gemini API key

### Installation

#### Clone the repository:
```bash
git clone https://github.com/yourusername/ai-conversational-app.git
cd ai-conversational-app
```

#### Create a `.env` file in the root directory with your API key:
```
GEMINI_API_KEY=your_api_key_here
```

#### Install dependencies:
```bash
flutter pub get
```

#### Run the app:
```bash
flutter run
```

---

## Configuration

### Android
Ensure microphone permissions are enabled.

### iOS
Add the following entry to `Info.plist` to allow microphone access:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for voice commands</string>
```

---

## Usage
1. Launch the app.
2. Say **"Hey"** to activate voice input.
3. Speak your message after the prompt.
4. The AI processes and responds via text and speech.
5. Use the close button to return to wake word mode.

---

## Architecture
```
lib/
├── main.dart          # App entry point
├── screens/
│   └── chat_screen.dart # Main chat interface
└── services/
    ├── chat_service.dart # AI interaction logic
    ├── stt_service.dart  # Speech-to-text handling
    └── tts_service.dart  # Text-to-speech handling
```

---

## Performance Optimization
- Efficient state management with Provider.
- Debouncing implemented for voice input processing.
- Optimized network calls to Gemini API.
- Proper lifecycle management for speech services.

---

## Testing
The app has been tested on:
- ✅ Android emulator and physical devices (API 29+)
- ✅ iOS simulator and physical devices (iOS 14+)

---

## Known Issues
- 🔹 Wake word detection may have slight latency on older devices.
- 🔹 Background audio may interfere with speech recognition.

---

## Future Enhancements
- 🌍 Support for multiple languages.
- 📝 Conversation history.
- 🎙️ Custom wake word configuration.
- 🚀 Offline mode with on-device processing.

---

## Demo Video
https://drive.google.com/drive/folders/1ikX92boZbP4fNfGAKFouVHfsAjJo0Ibj?usp=drive_link

## Screenshots
https://drive.google.com/drive/folders/1vaLP1qOV-iP8e91IVQ2JHB8QznIr8a65?usp=drive_link

## Android APK link
https://drive.google.com/drive/folders/1fWGmINE2MnBFsvEZMgwD2NtYIVK9aEqp?usp=drive_link


---
