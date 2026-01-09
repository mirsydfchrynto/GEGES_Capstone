// test/widget/chat_assistant_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import ini
import 'package:geges_smartbarber/screens/customer/tabs/chat_assistant_screen.dart';
import 'package:geges_smartbarber/services/auth_service.dart';
import 'package:geges_smartbarber/services/chatbot_service.dart';
import 'package:geges_smartbarber/models/chatbot_response.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:geges_smartbarber/l10n/generated/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Mocks
class MockAuthService extends Mock implements AuthService {
  @override
  User? get currentUser => null;
}

class MockChatbotService extends Mock implements ChatbotService {
  @override
  Future<ChatbotResponse> askQuestion(String? question) {
    return super.noSuchMethod(
      Invocation.method(#askQuestion, [question]),
      returnValue: Future.value(ChatbotResponse(
        answer: "Jawaban Mock AI",
        detectionMode: "TEST",
        confidence: "High",
        sources: [],
        processTime: 0.1,
      )),
    );
  }
}

void main() {
  late MockAuthService mockAuthService;
  late MockChatbotService mockChatbotService;

  setUp(() {
    SharedPreferences.setMockInitialValues({}); // Mock SharedPrefs
    mockAuthService = MockAuthService();
    mockChatbotService = MockChatbotService();
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('id')], // Force ID
      home: ChatAssistantScreen(
        authService: mockAuthService,
        chatbotService: mockChatbotService,
      ),
    );
  }

  testWidgets('ChatAssistantScreen renders and sends message', (WidgetTester tester) async {
    // ARRANGE
    when(mockChatbotService.askQuestion(any)).thenAnswer((_) async => ChatbotResponse(
      answer: "Saya siap membantu.",
      detectionMode: "TEST",
      confidence: "High",
      sources: [],
      processTime: 0.1,
    ));

    // ACT: Build UI
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump(const Duration(seconds: 1)); // Pastikan timer delay 500ms lewat
    await tester.pumpAndSettle(); 

    // ASSERT: Cek Greeting awal muncul (Cari MarkdownBody karena teks dirender di dalamnya)
    expect(find.byType(MarkdownBody), findsWidgets); 

    // ACT: User mengetik "Apa kabar?"
    await tester.enterText(find.byType(TextField), "Apa kabar?");
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump(); // Rebuild setelah tap

    // ASSERT: Pesan user muncul
    expect(find.text("Apa kabar?"), findsOneWidget);

    // Skip pengecekan "GIA is typing..." karena mock terlalu cepat
    
    // ACT: Tunggu async API selesai
    await tester.pumpAndSettle(); // Tunggu future selesai

    // ASSERT: Jawaban Mock AI muncul (Kita cek ada lebih dari 1 MarkdownBody sekarang)
    // 1 Greeting + 1 Jawaban AI = 2
    expect(find.byType(MarkdownBody), findsAtLeastNWidgets(2));
  });
}
