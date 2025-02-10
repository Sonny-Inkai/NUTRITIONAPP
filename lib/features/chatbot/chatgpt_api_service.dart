import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:opennutritracker/core/utils/env.dart';

/// A simple chat message model.
class ChatMessage {
  final String role; // "user", "assistant", or "system"
  final String content;

  ChatMessage({required this.role, required this.content});

  Map<String, String> toJson() {
    return {'role': role, 'content': content};
  }
}

/// Service to call the ChatGPT API using OpenAI's chat completions endpoint.
/// Make sure your .env file is set up correctly (without extra quotes) and that you
/// have run the build_runner command to update env.g.dart.
class ChatGPTAPIService {
  static const String _endpoint = 'https://api.openai.com/v1/chat/completions';
  static const String _model = 'gpt-4o';

  /// Sends the conversation messages to the API and returns the assistant reply.
  static Future<ChatMessage> sendMessage(
    List<ChatMessage> messages, {
    double temperature = 0.7, // Optional: Adjust as needed.
  }) async {
    // Build the request body as per OpenAI's Chat Completions API requirements.
    final Map<String, dynamic> requestBody = {
      'model': _model,
      'messages': messages.map((msg) => msg.toJson()).toList(),
      'temperature': temperature,
    };
    
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${Env.openaiApiKey}',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // The response structure follows OpenAI's documentation.
      final reply = data['choices'][0]['message']['content'] as String;
      return ChatMessage(role: 'assistant', content: reply);
    } else {
      throw Exception('ChatGPT API error: ${response.body}');
    }
  }
} 