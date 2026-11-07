import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';

class AskScreen extends StatefulWidget {
  const AskScreen({super.key});

  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  _ChatMessage({required this.text, required this.isUser, required this.time});
}

class _AskScreenState extends State<AskScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      text: 'How much did I spend on dining and coffee this month?',
      isUser: true,
      time: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    _ChatMessage(
      text:
          'You spent ₹1,062.50 across 2 dining transactions in October:\n• Swiggy: ₹642.50 (Oct 03)\n• Starbucks Bangalore: ₹420.00 (Oct 04)',
      isUser: false,
      time: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
  ];

  Future<void> _sendMessage([String? textToSend]) async {
    final text = textToSend ?? _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true, time: DateTime.now()));
      _controller.clear();
    });

    final finance = context.read<FinanceProvider>();
    final answer = await finance.askQuery(text);

    if (mounted) {
      setState(() {
        _messages.add(_ChatMessage(
          text: answer,
          isUser: false,
          time: DateTime.now(),
        ));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Ask Your Money'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: finance.hasGeminiApiKey
                    ? Colors.purple.withOpacity(0.18)
                    : AppTheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: finance.hasGeminiApiKey
                      ? Colors.purple.withOpacity(0.35)
                      : AppTheme.primary.withOpacity(0.35),
                ),
              ),
              child: Text(
                finance.hasGeminiApiKey ? 'Gemini AI' : 'Offline Rules',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: finance.hasGeminiApiKey ? Colors.purpleAccent : AppTheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Prompt suggestions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme.surfaceSubtle,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _SuggestionChip(
                    label: 'Did I receive salary?',
                    onTap: () => _sendMessage('Did I receive salary?'),
                  ),
                  const SizedBox(width: 8),
                  _SuggestionChip(
                    label: 'How much in SIPs?',
                    onTap: () => _sendMessage('How much did I invest in SIPs?'),
                  ),
                  const SizedBox(width: 8),
                  _SuggestionChip(
                    label: 'Electricity bill status?',
                    onTap: () => _sendMessage('What was my electricity bill?'),
                  ),
                  const SizedBox(width: 8),
                  _SuggestionChip(
                    label: 'List all UPI payments',
                    onTap: () => _sendMessage('List all UPI payments'),
                  ),
                ],
              ),
            ),
          ),

          // Chat messages list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.8,
                    ),
                    decoration: BoxDecoration(
                      color: msg.isUser ? AppTheme.primary : AppTheme.surface,
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight: msg.isUser ? const Radius.circular(2) : const Radius.circular(16),
                        bottomLeft: msg.isUser ? const Radius.circular(16) : const Radius.circular(2),
                      ),
                      border: msg.isUser ? null : Border.all(color: AppTheme.border),
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: msg.isUser ? Colors.black : AppTheme.textPrimary,
                        fontWeight: msg.isUser ? FontWeight.w600 : FontWeight.normal,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Input bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Ask about your transactions...',
                        hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textFaint),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        filled: true,
                        fillColor: AppTheme.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.primary),
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.arrow_upward, size: 20),
                    onPressed: () => _sendMessage(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
      backgroundColor: AppTheme.surface,
      side: const BorderSide(color: AppTheme.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onPressed: onTap,
    );
  }
}
