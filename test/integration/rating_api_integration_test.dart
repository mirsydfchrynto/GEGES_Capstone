import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import '../test_utils.dart'; // Import utility

void main() {
  setUpAll(() {
    enableNetworkCalls();
  });

  test('Real API Integration Test: Check response format', () async {
    final response = await http.post(
      Uri.parse('https://mirsydfchyrnto-review-api.hf.space/predict'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'review': 'Tempatnya nyaman dan ber-AC, mantap!'}),
    );

    expect(response.statusCode, 200, reason: "API should be up and running");
    
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    expect(body.containsKey('prediction'), true, reason: "Response must contain 'prediction'");
    expect(body['prediction'], 'positif');
  });
}
