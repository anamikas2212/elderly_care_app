/*
// pubspec.yaml dependencies needed:
// http: ^1.1.0
// cloud_firestore: ^4.13.0
// firebase_core: ^2.24.0
// firebase_auth: ^4.15.0  (for user authentication)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'memory_service.dart';
import 'chat_message.dart';

class BuddyChatScreen extends StatefulWidget {
  final String userId; // Pass the current user's ID
  
  const BuddyChatScreen({
    super.key,
    required this.userId,
  });

  @override
  State<BuddyChatScreen> createState() => _BuddyChatScreenState();
}

class _BuddyChatScreenState extends State<BuddyChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  // Groq API setup
  final List<Map<String, dynamic>> _chatHistory = [];
  String _currentMood = 'neutral';

  // Replace with your actual Groq API key
  static const String _apiKey = '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';
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';

  // Memory service
  late MemoryService _memoryService;
  String _userMemoryContext = '';
  List<String> _personalizedQuestions = [];
  bool _isLoadingMemories = true;

  @override
  void initState() {
    super.initState();
    _memoryService = MemoryService(groqApiKey: _apiKey);
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    // Load user's memories
    await _loadUserMemories();

    // Initialize chat with system prompt including memories
    _chatHistory.add({
      'role': 'system',
      'content': '''You are "Buddy", a warm, empathetic emotional companion AI.

$_userMemoryContext

Your role is to:
1. Provide emotional support and companionship
2. Reference past conversations naturally when relevant
3. Ask thoughtful follow-up questions about things the user previously mentioned
4. Help users process their feelings
5. Offer gentle encouragement and positivity
6. Use simple, warm language with appropriate emojis

Always start your response with a sentiment tag:
[SENTIMENT:positive/negative/neutral/anxious/sad/happy/angry]

Keep responses conversational, supportive, and around 2-4 sentences unless more detail is needed.'''
    });

    setState(() {
      _isLoadingMemories = false;
    });

    // Welcome message with personalization
    _addWelcomeMessage();
  }

  Future<void> _loadUserMemories() async {
    try {
      // Load memory context
      final context = await _memoryService.loadUserMemoryContext(widget.userId);
      setState(() {
        _userMemoryContext = context;
      });

      // Get personalized questions
      final questions = await _memoryService.getPersonalizedQuestions(widget.userId);
      setState(() {
        _personalizedQuestions = questions;
      });
    } catch (e) {
      print('Error loading memories: $e');
      setState(() {
        _userMemoryContext = 'This is a new user. No previous memories.';
      });
    }
  }

  void _addWelcomeMessage() {
    String welcomeText = 'Hello! I\'m your friendly buddy. ';
    
    if (_userMemoryContext.contains('new user')) {
      welcomeText += 'How are you feeling today? 😊';
    } else {
      welcomeText += 'It\'s great to see you again! How have you been? 💙';
    }

    _messages.add(
      ChatMessage(
        text: welcomeText,
        isUser: false,
        timestamp: DateTime.now(),
        sentiment: 'positive',
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userMessage = _messageController.text.trim();
    final userChatMessage = ChatMessage(
      text: userMessage,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userChatMessage);
      _isTyping = true;
    });
    _messageController.clear();
    _scrollToBottom();

    // Add user message to chat history
    _chatHistory.add({
      'role': 'user',
      'content': userMessage,
    });

    try {
      // Call Groq API
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': _chatHistory,
          'temperature': 0.9,
          'max_tokens': 1024,
          'top_p': 0.95,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final responseText = data['choices'][0]['message']['content'] ??
            'I\'m here for you. Tell me more about how you\'re feeling.';

        // Add assistant response to history
        _chatHistory.add({
          'role': 'assistant',
          'content': responseText,
        });

        // Extract sentiment
        final sentiment = _extractSentiment(responseText);
        final cleanedText = _cleanResponseText(responseText);

        final aiChatMessage = ChatMessage(
          text: cleanedText,
          isUser: false,
          timestamp: DateTime.now(),
          sentiment: sentiment,
        );

        setState(() {
          _messages.add(aiChatMessage);
          _currentMood = sentiment;
          _isTyping = false;
        });
        _scrollToBottom();

        // Extract and save memories asynchronously (don't await)
        _memoryService.extractAndSaveMemories(
          userId: widget.userId,
          userMessage: userMessage,
          aiResponse: cleanedText,
        );

        // Update emotional profile
        _memoryService.updateEmotionalProfile(
          userId: widget.userId,
          sentiment: sentiment,
          topics: _extractTopics(userMessage),
        );
      } else {
        throw Exception('Failed to get response: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            text: 'I\'m having trouble connecting right now, but I\'m still here with you. Could you try again? 💙',
            isUser: false,
            timestamp: DateTime.now(),
            sentiment: 'neutral',
          ),
        );
        _isTyping = false;
      });
      _scrollToBottom();
      print('Error: $e');
    }
  }

  List<String> _extractTopics(String message) {
    // Simple topic extraction (you can make this more sophisticated)
    final keywords = ['work', 'family', 'health', 'stress', 'happy', 'sad', 'anxious'];
    return keywords.where((k) => message.toLowerCase().contains(k)).toList();
  }

  String _extractSentiment(String text) {
    final sentimentPattern = RegExp(r'\[SENTIMENT:(.*?)\]');
    final match = sentimentPattern.firstMatch(text);
    if (match != null) {
      return match.group(1)?.toLowerCase() ?? 'neutral';
    }
    return 'neutral';
  }

  String _cleanResponseText(String text) {
    return text.replaceAll(RegExp(r'\[SENTIMENT:.*?\]'), '').trim();
  }

  Color _getSentimentColor(String sentiment) {
    switch (sentiment.toLowerCase()) {
      case 'positive':
      case 'happy':
        return Colors.green.shade100;
      case 'negative':
      case 'sad':
        return Colors.blue.shade100;
      case 'anxious':
        return Colors.orange.shade100;
      case 'angry':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  IconData _getSentimentIcon(String sentiment) {
    switch (sentiment.toLowerCase()) {
      case 'positive':
      case 'happy':
        return Icons.sentiment_very_satisfied;
      case 'negative':
      case 'sad':
        return Icons.sentiment_dissatisfied;
      case 'anxious':
        return Icons.sentiment_neutral;
      case 'angry':
        return Icons.sentiment_very_dissatisfied;
      default:
        return Icons.sentiment_satisfied;
    }
  }

  void _scrollToBottom() {
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

  // Show memory capsule dialog
  void _showMemoryCapsule() async {
    final stats = await _memoryService.getMemoryStats(widget.userId);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.auto_awesome, color: Colors.pink),
            SizedBox(width: 8),
            Text('Your Memory Capsule'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total Memories: ${stats['totalMemories']}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Categories:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              ...((stats['categories'] as Map<String, int>).entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Text('• ${e.key}: ${e.value}'),
                ),
              )),
              const SizedBox(height: 12),
              const Text(
                'Types:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              ...((stats['types'] as Map<String, int>).entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Text('• ${e.key}: ${e.value}'),
                ),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Save conversation when closing
  Future<void> _saveConversation() async {
    if (_messages.length > 1) {
      await _memoryService.saveConversation(
        userId: widget.userId,
        messages: _messages,
        dominantSentiment: _currentMood,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingMemories) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(color: Colors.pink),
              SizedBox(height: 16),
              Text('Loading your memories...'),
            ],
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        await _saveConversation();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.pink.shade400,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, size: 32, color: Colors.white),
            onPressed: () async {
              await _saveConversation();
              Navigator.pop(context);
            },
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.psychology, color: Colors.pink, size: 28),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'My Buddy',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Your emotional companion',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            // Memory capsule button
            IconButton(
              icon: const Icon(Icons.auto_awesome, color: Colors.white),
              onPressed: _showMemoryCapsule,
              tooltip: 'Memory Capsule',
            ),
            // Mood indicator
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Icon(
                _getSentimentIcon(_currentMood),
                color: Colors.white,
                size: 28,
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Chat Messages
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.pink.shade50, Colors.white],
                  ),
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length && _isTyping) {
                      return _buildTypingIndicator();
                    }
                    return _buildMessageBubble(_messages[index]);
                  },
                ),
              ),
            ),

            // Personalized Quick Responses (based on memories)
            if (_messages.length <= 2 && _personalizedQuestions.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'You might want to talk about:',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _personalizedQuestions
                          .map((q) => _buildQuickReply(q))
                          .toList(),
                    ),
                  ],
                ),
              ),

            // Message Input
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(26),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: SafeArea(
                child: Row(
                  children: [
                    // Voice Input Button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.pink.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Voice input coming soon!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.mic, color: Colors.pink),
                        iconSize: 28,
                        tooltip: 'Voice Input',
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Text Input
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            hintText: 'Share your feelings...',
                            hintStyle: TextStyle(fontSize: 18),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          style: const TextStyle(fontSize: 18),
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Send Button
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.pink.shade400, Colors.pink.shade600],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.pink.withAlpha(102),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: _isTyping ? null : _sendMessage,
                        icon: const Icon(Icons.send, color: Colors.white),
                        iconSize: 28,
                        tooltip: 'Send',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: message.sentiment != null
                    ? _getSentimentColor(message.sentiment!)
                    : Colors.pink.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                message.sentiment != null
                    ? _getSentimentIcon(message.sentiment!)
                    : Icons.psychology,
                color: Colors.pink,
                size: 24,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                gradient: message.isUser
                    ? LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                      )
                    : null,
                color: message.isUser
                    ? null
                    : (message.sentiment != null
                        ? _getSentimentColor(message.sentiment!)
                        : Colors.grey.shade100),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(message.isUser ? 20 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(26),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 18,
                      color: message.isUser ? Colors.white : Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: message.isUser
                              ? Colors.white.withAlpha(179)
                              : Colors.black54,
                        ),
                      ),
                      if (!message.isUser && message.sentiment != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(26),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            message.sentiment!,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.blue, size: 24),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.pink.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.psychology, color: Colors.pink, size: 24),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                _buildDot(0),
                const SizedBox(width: 5),
                _buildDot(1),
                const SizedBox(width: 5),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.grey.shade400.withOpacity(
              0.3 + (0.7 * ((value + index * 0.33) % 1.0)),
            ),
            shape: BoxShape.circle,
          ),
        );
      },
      onEnd: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  Widget _buildQuickReply(String text) {
    return InkWell(
      onTap: () {
        _messageController.text = text;
        _sendMessage();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.pink.shade200, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.pink.withAlpha(26),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            color: Colors.pink.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour > 12 ? timestamp.hour - 12 : timestamp.hour;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = timestamp.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
*/

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'memory_service.dart';
import 'chat_message.dart';

class BuddyChatScreen extends StatefulWidget {
  final String userId; // Pass the current user's ID
  
  const BuddyChatScreen({
    super.key,
    required this.userId,
  });

  @override
  State<BuddyChatScreen> createState() => _BuddyChatScreenState();
}

class _BuddyChatScreenState extends State<BuddyChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  // Groq API setup
  final List<Map<String, dynamic>> _chatHistory = [];
  String _currentMood = 'neutral';

  // Replace with your actual Groq API key
  static const String _apiKey = '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';
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';

  // Memory service
  late MemoryService _memoryService;
  String _userMemoryContext = '';
  List<String> _personalizedQuestions = [];
  bool _isLoadingMemories = true;

  @override
  void initState() {
    super.initState();
    _memoryService = MemoryService(groqApiKey: _apiKey);
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    // Load user's memories
    await _loadUserMemories();

    // Initialize chat with system prompt including memories
    _chatHistory.add({
      'role': 'system',
      'content': '''You are "Buddy", a warm, empathetic emotional companion AI with a perfect memory.

$_userMemoryContext

Your role is to:
1. Provide emotional support and companionship
2. ACTIVELY reference past conversations and specific details you remember
3. Use the person's name and other details when you know them
4. Ask thoughtful follow-up questions about things previously mentioned
5. Help users process their feelings
6. Offer gentle encouragement and positivity
7. Show that you genuinely remember and care about their life

IMPORTANT MEMORY USAGE:
- When the user mentions something you've discussed before, ACKNOWLEDGE it
- Reference specific names, events, and details from previous conversations
- If you know someone's name or other personal details, use them naturally
- Connect current conversations to past memories when relevant

Always start your response with a sentiment tag:
[SENTIMENT:positive/negative/neutral/anxious/sad/happy/angry]

Keep responses conversational, supportive, and around 2-4 sentences unless more detail is needed.
BE SPECIFIC when referencing memories - use actual names and details, not generic statements.'''
    });

    setState(() {
      _isLoadingMemories = false;
    });

    // Welcome message with personalization
    _addWelcomeMessage();
  }

  Future<void> _loadUserMemories() async {
    try {
      // Load memory context
      final context = await _memoryService.loadUserMemoryContext(widget.userId);
      setState(() {
        _userMemoryContext = context;
      });

      // Get personalized questions
      final questions = await _memoryService.getPersonalizedQuestions(widget.userId);
      setState(() {
        _personalizedQuestions = questions;
      });
    } catch (e) {
      print('Error loading memories: $e');
      setState(() {
        _userMemoryContext = 'This is a new user. No previous memories.';
      });
    }
  }

  void _addWelcomeMessage() {
    String welcomeText = 'Hello! I\'m your friendly buddy. ';
    
    if (_userMemoryContext.contains('new user')) {
      welcomeText += 'How are you feeling today? 😊';
    } else {
      welcomeText += 'It\'s great to see you again! How have you been? 💙';
    }

    _messages.add(
      ChatMessage(
        text: welcomeText,
        isUser: false,
        timestamp: DateTime.now(),
        sentiment: 'positive',
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userMessage = _messageController.text.trim();
    final userChatMessage = ChatMessage(
      text: userMessage,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userChatMessage);
      _isTyping = true;
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      // IMPORTANT: Get relevant memories for this specific message
      final dynamicContext = await _memoryService.buildDynamicContext(
        userId: widget.userId,
        currentMessage: userMessage,
      );

      // Create a temporary message list with dynamic context
      final messagesWithContext = List<Map<String, dynamic>>.from(_chatHistory);
      
      // Add dynamic context to the user message if we have relevant memories
      if (dynamicContext.isNotEmpty) {
        messagesWithContext.add({
          'role': 'user',
          'content': '$dynamicContext\n\nUser\'s current message: $userMessage',
        });
      } else {
        messagesWithContext.add({
          'role': 'user',
          'content': userMessage,
        });
      }

      // Call Groq API
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': messagesWithContext,
          'temperature': 0.9,
          'max_tokens': 1024,
          'top_p': 0.95,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final responseText = data['choices'][0]['message']['content'] ??
            'I\'m here for you. Tell me more about how you\'re feeling.';

        // Add to permanent chat history (without the dynamic context)
        _chatHistory.add({
          'role': 'user',
          'content': userMessage,
        });
        
        _chatHistory.add({
          'role': 'assistant',
          'content': responseText,
        });

        // Extract sentiment
        final sentiment = _extractSentiment(responseText);
        final cleanedText = _cleanResponseText(responseText);

        final aiChatMessage = ChatMessage(
          text: cleanedText,
          isUser: false,
          timestamp: DateTime.now(),
          sentiment: sentiment,
        );

        setState(() {
          _messages.add(aiChatMessage);
          _currentMood = sentiment;
          _isTyping = false;
        });
        _scrollToBottom();

        // Extract and save memories asynchronously (don't await)
        _memoryService.extractAndSaveMemories(
          userId: widget.userId,
          userMessage: userMessage,
          aiResponse: cleanedText,
        ).then((_) {
          // Refresh memory context after saving new memories
          _refreshMemoryContext();
        });

        // Update emotional profile
        _memoryService.updateEmotionalProfile(
          userId: widget.userId,
          sentiment: sentiment,
          topics: _extractTopics(userMessage),
        );
      } else {
        throw Exception('Failed to get response: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            text: 'I\'m having trouble connecting right now, but I\'m still here with you. Could you try again? 💙',
            isUser: false,
            timestamp: DateTime.now(),
            sentiment: 'neutral',
          ),
        );
        _isTyping = false;
      });
      _scrollToBottom();
      print('Error: $e');
    }
  }

  // NEW: Refresh memory context periodically
  Future<void> _refreshMemoryContext() async {
    try {
      final context = await _memoryService.loadUserMemoryContext(widget.userId);
      
      // Update the system message with new context
      if (_chatHistory.isNotEmpty && _chatHistory[0]['role'] == 'system') {
        _chatHistory[0]['content'] = '''You are "Buddy", a warm, empathetic emotional companion AI with a perfect memory.

$context

Your role is to:
1. Provide emotional support and companionship
2. ACTIVELY reference past conversations and specific details you remember
3. Use the person's name and other details when you know them
4. Ask thoughtful follow-up questions about things previously mentioned
5. Help users process their feelings
6. Offer gentle encouragement and positivity
7. Show that you genuinely remember and care about their life

IMPORTANT MEMORY USAGE:
- When the user mentions something you've discussed before, ACKNOWLEDGE it
- Reference specific names, events, and details from previous conversations
- If you know someone's name or other personal details, use them naturally
- Connect current conversations to past memories when relevant

Always start your response with a sentiment tag:
[SENTIMENT:positive/negative/neutral/anxious/sad/happy/angry]

Keep responses conversational, supportive, and around 2-4 sentences unless more detail is needed.
BE SPECIFIC when referencing memories - use actual names and details, not generic statements.''';
      }
    } catch (e) {
      print('Error refreshing memory context: $e');
    }
  }

  List<String> _extractTopics(String message) {
    // Simple topic extraction (you can make this more sophisticated)
    final keywords = ['work', 'family', 'health', 'stress', 'happy', 'sad', 'anxious', 'son', 'daughter', 'friend'];
    return keywords.where((k) => message.toLowerCase().contains(k)).toList();
  }

  String _extractSentiment(String text) {
    final sentimentPattern = RegExp(r'\[SENTIMENT:(.*?)\]');
    final match = sentimentPattern.firstMatch(text);
    if (match != null) {
      return match.group(1)?.toLowerCase() ?? 'neutral';
    }
    return 'neutral';
  }

  String _cleanResponseText(String text) {
    return text.replaceAll(RegExp(r'\[SENTIMENT:.*?\]'), '').trim();
  }

  Color _getSentimentColor(String sentiment) {
    switch (sentiment.toLowerCase()) {
      case 'positive':
      case 'happy':
        return Colors.green.shade100;
      case 'negative':
      case 'sad':
        return Colors.blue.shade100;
      case 'anxious':
        return Colors.orange.shade100;
      case 'angry':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  IconData _getSentimentIcon(String sentiment) {
    switch (sentiment.toLowerCase()) {
      case 'positive':
      case 'happy':
        return Icons.sentiment_very_satisfied;
      case 'negative':
      case 'sad':
        return Icons.sentiment_dissatisfied;
      case 'anxious':
        return Icons.sentiment_neutral;
      case 'angry':
        return Icons.sentiment_very_dissatisfied;
      default:
        return Icons.sentiment_satisfied;
    }
  }

  void _scrollToBottom() {
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

  // Show memory capsule dialog
  void _showMemoryCapsule() async {
    final stats = await _memoryService.getMemoryStats(widget.userId);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.auto_awesome, color: Colors.pink),
            SizedBox(width: 8),
            Text('Your Memory Capsule'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total Memories: ${stats['totalMemories']}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Categories:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              ...((stats['categories'] as Map<String, int>).entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Text('• ${e.key}: ${e.value}'),
                ),
              )),
              const SizedBox(height: 12),
              const Text(
                'Types:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              ...((stats['types'] as Map<String, int>).entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Text('• ${e.key}: ${e.value}'),
                ),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Save conversation when closing
  Future<void> _saveConversation() async {
    if (_messages.length > 1) {
      await _memoryService.saveConversation(
        userId: widget.userId,
        messages: _messages,
        dominantSentiment: _currentMood,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingMemories) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(color: Colors.pink),
              SizedBox(height: 16),
              Text('Loading your memories...'),
            ],
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        await _saveConversation();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.pink.shade400,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, size: 32, color: Colors.white),
            onPressed: () async {
              await _saveConversation();
              Navigator.pop(context);
            },
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.psychology, color: Colors.pink, size: 28),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'My Buddy',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Your emotional companion',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            // Memory capsule button
            IconButton(
              icon: const Icon(Icons.auto_awesome, color: Colors.white),
              onPressed: _showMemoryCapsule,
              tooltip: 'Memory Capsule',
            ),
            // Mood indicator
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Icon(
                _getSentimentIcon(_currentMood),
                color: Colors.white,
                size: 28,
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Chat Messages
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.pink.shade50, Colors.white],
                  ),
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length && _isTyping) {
                      return _buildTypingIndicator();
                    }
                    return _buildMessageBubble(_messages[index]);
                  },
                ),
              ),
            ),

            // Personalized Quick Responses (based on memories)
            if (_messages.length <= 2 && _personalizedQuestions.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'You might want to talk about:',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _personalizedQuestions
                          .map((q) => _buildQuickReply(q))
                          .toList(),
                    ),
                  ],
                ),
              ),

            // Message Input
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(26),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: SafeArea(
                child: Row(
                  children: [
                    // Voice Input Button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.pink.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Voice input coming soon!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.mic, color: Colors.pink),
                        iconSize: 28,
                        tooltip: 'Voice Input',
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Text Input
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            hintText: 'Share your feelings...',
                            hintStyle: TextStyle(fontSize: 18),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          style: const TextStyle(fontSize: 18),
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Send Button
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.pink.shade400, Colors.pink.shade600],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.pink.withAlpha(102),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: _isTyping ? null : _sendMessage,
                        icon: const Icon(Icons.send, color: Colors.white),
                        iconSize: 28,
                        tooltip: 'Send',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: message.sentiment != null
                    ? _getSentimentColor(message.sentiment!)
                    : Colors.pink.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                message.sentiment != null
                    ? _getSentimentIcon(message.sentiment!)
                    : Icons.psychology,
                color: Colors.pink,
                size: 24,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                gradient: message.isUser
                    ? LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                      )
                    : null,
                color: message.isUser
                    ? null
                    : (message.sentiment != null
                        ? _getSentimentColor(message.sentiment!)
                        : Colors.grey.shade100),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(message.isUser ? 20 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(26),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 18,
                      color: message.isUser ? Colors.white : Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: message.isUser
                              ? Colors.white.withAlpha(179)
                              : Colors.black54,
                        ),
                      ),
                      if (!message.isUser && message.sentiment != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(26),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            message.sentiment!,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.blue, size: 24),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.pink.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.psychology, color: Colors.pink, size: 24),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                _buildDot(0),
                const SizedBox(width: 5),
                _buildDot(1),
                const SizedBox(width: 5),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.grey.shade400.withOpacity(
              0.3 + (0.7 * ((value + index * 0.33) % 1.0)),
            ),
            shape: BoxShape.circle,
          ),
        );
      },
      onEnd: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  Widget _buildQuickReply(String text) {
    return InkWell(
      onTap: () {
        _messageController.text = text;
        _sendMessage();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.pink.shade200, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.pink.withAlpha(26),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            color: Colors.pink.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour > 12 ? timestamp.hour - 12 : timestamp.hour;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = timestamp.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}