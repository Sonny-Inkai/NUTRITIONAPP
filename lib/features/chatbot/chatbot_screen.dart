import 'package:flutter/material.dart';
import 'package:opennutritracker/features/chatbot/chatgpt_api_service.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({Key? key}) : super(key: key);

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _conversation = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Set chat context with an initial system message:
    _conversation.add(ChatMessage(
        role: 'system',
        content:
            'You are a helpful nutritionist assistant. Provide accurate, practical and personalized nutrition advice with healthy tips.'));
  }

  void _scrollToBottom() {
    // Give time for the list view to update
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendMessage() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;
    setState(() {
      _conversation.add(ChatMessage(role: 'user', content: input));
      _isLoading = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      // Call the ChatGPT API with the full conversation context
      final reply = await ChatGPTAPIService.sendMessage(_conversation);
      setState(() {
        _conversation.add(reply);
      });
    } catch (e) {
      setState(() {
        _conversation.add(ChatMessage(
            role: 'assistant', content: 'Error: ${e.toString()}'));
      });
    }

    setState(() {
      _isLoading = false;
    });
    _scrollToBottom();
  }

  Widget _buildMessageBubble(ChatMessage message) {
    // Hide the system message in the UI
    if (message.role == 'system') return const SizedBox.shrink();
    final isUser = message.role == 'user';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isUser ? Colors.blueAccent.shade100 : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.content,
          style: const TextStyle(color: Colors.black87),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutritionist Assistant'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Chat history list
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _conversation.length,
                itemBuilder: (context, index) {
                  return _buildMessageBubble(_conversation[index]);
                },
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            // Input field row
            Container(
              margin:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(24)),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Type your nutrition question...',
                        border: InputBorder.none,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _isLoading ? null : _handleSendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 