// pubspec.yaml dependencies needed:
// google_generative_ai: ^0.2.0
// flutter_dotenv: ^5.1.0
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
class BuddyChatScreen extends StatefulWidget {
const BuddyChatScreen({super.key});
@override
State<BuddyChatScreen> createState() => _BuddyChatScreenState();
}
class _BuddyChatScreenState extends State<BuddyChatScreen> {
final TextEditingController _messageController = TextEditingController();
final ScrollController _scrollController = ScrollController();
final List<ChatMessage> _messages = [];
bool _isTyping = false;
// Gemini API setup
late final GenerativeModel _model;
late final ChatSession _chat;
String _currentMood = 'neutral';
// Replace with your actual API key
static const String _apiKey = 'AIzaSyC3AE58MFE2tDZGZQ89qMKjDdf7Z-QWuPY';
@override
void initState() {
super.initState();
_initializeGemini();
// Welcome message
_messages.add(
ChatMessage(
text: 'Hello! I\'m your friendly buddy. How are you feeling today? 😊',
isUser: false,
timestamp: DateTime.now(),
sentiment: 'positive',
),
);

}
void _initializeGemini() {
_model = GenerativeModel(
model: 'gemini-pro',
apiKey: _apiKey,
generationConfig: GenerationConfig(
temperature: 0.9,
topK: 40,
topP: 0.95,
maxOutputTokens: 1024,
),
safetySettings: [
SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
],
);
// Initialize chat with context about being an emotional companion
_chat = _model.startChat(
history: [
Content.text(
'''You are a warm, empathetic emotional companion AI named "Buddy".
Your role is to:
1. Provide emotional support and companionship
2. Listen actively and respond with empathy
3. Help users process their feelings
4. Offer gentle encouragement and positivity
5. Remember context from the conversation
6. Use simple, warm language suitable for all ages
7. Include appropriate emojis to convey warmth
Always start your response with a sentiment analysis tag in this format:
[SENTIMENT:positive/negative/neutral/anxious/sad/happy/angry]
Keep responses conversational, supportive, and around 2-4 sentences unless the user
needs more detailed help.''',
),
],
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
setState(() {
_messages.add(
ChatMessage(text: userMessage, isUser: true, timestamp: DateTime.now()),
);
_isTyping = true;
});
_messageController.clear();
_scrollToBottom();
try {
// Send message to Gemini API
final response = await _chat.sendMessage(Content.text(userMessage));
final responseText =
response.text ??
'I\'m here for you. Tell me more about how you\'re feeling.';
// Extract sentiment from response
final sentiment = _extractSentiment(responseText);
final cleanedText = _cleanResponseText(responseText);
setState(() {
_messages.add(
ChatMessage(
text: cleanedText,
isUser: false,
timestamp: DateTime.now(),
sentiment: sentiment,
),
);
_currentMood = sentiment;

_isTyping = false;
});
_scrollToBottom();
} catch (e) {
setState(() {
_messages.add(
ChatMessage(
text:'I\'m having trouble connecting right now, but I\'m still here with you. Could you try again? 💙',
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
@override
Widget build(BuildContext context) {
return Scaffold(

backgroundColor: Colors.white,
appBar: AppBar(
backgroundColor: Colors.pink.shade400,
elevation: 0,
leading: IconButton(
icon: const Icon(Icons.arrow_back, size: 32, color: Colors.white),
onPressed: () => Navigator.pop(context),
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
// Quick Responses
if (_messages.length <= 2)
Container(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(

'Quick replies:',
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
children: [
_buildQuickReply('I\'m feeling great!'),
_buildQuickReply('I\'m a bit sad today'),
_buildQuickReply('I need someone to talk to'),
_buildQuickReply('Tell me something positive'),
],
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
color:
message.sentiment != null
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
gradient:
message.isUser
? LinearGradient(
colors: [Colors.blue.shade400, Colors.blue.shade600],
)
: null,
color:
message.isUser
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
color:
message.isUser
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
// Chat Message Model
class ChatMessage {
final String text;
final bool isUser;
final DateTime timestamp;
final String? sentiment;
ChatMessage({
required this.text,
required this.isUser,
required this.timestamp,
this.sentiment,
});
}

/*import 'package:flutter/material.dart';
class BuddyChatScreen extends StatefulWidget {
const BuddyChatScreen({super.key});
@override
State<BuddyChatScreen> createState() => _BuddyChatScreenState();
}
class _BuddyChatScreenState extends State<BuddyChatScreen> {
final TextEditingController _messageController = TextEditingController();
final ScrollController _scrollController = ScrollController();
final List<ChatMessage> _messages = [];
bool _isTyping = false;
@override
void initState() {
super.initState();

// Welcome message
_messages.add(
ChatMessage(
text: 'Hello! I\'m your friendly buddy. How are you feeling today? 😊',
isUser: false,
timestamp: DateTime.now(),
),
);
}
@override
void dispose() {
_messageController.dispose();
_scrollController.dispose();
super.dispose();
}
void _sendMessage() {
if (_messageController.text.trim().isEmpty) return;
final userMessage = _messageController.text.trim();
setState(() {
_messages.add(
ChatMessage(text: userMessage, isUser: true, timestamp: DateTime.now()),
);
_isTyping = true;
});
_messageController.clear();
_scrollToBottom();
// Simulate AI response (replace with actual Gemini API call)
Future.delayed(const Duration(seconds: 2), () {
setState(() {
_messages.add(
ChatMessage(
text: _generateResponse(userMessage),
isUser: false,
timestamp: DateTime.now(),
),
);
_isTyping = false;

});
_scrollToBottom();
});
}
String _generateResponse(String userMessage) {
// Simple response logic - replace with Gemini API
final message = userMessage.toLowerCase();
if (message.contains('hello') || message.contains('hi')) {
return 'Hello there! It\'s wonderful to hear from you! How can I help you today?
😊';
} else if (message.contains('how are you')) {
return 'I\'m doing great, thank you for asking! I\'m here to chat with you
anytime. How are YOU doing today?';
} else if (message.contains('pill') || message.contains('medicine')) {
return 'Don\'t forget to take your pills on time! You can check your pill
reminder from the home screen. Would you like me to remind you about something?';
} else if (message.contains('sad') || message.contains('lonely')) {
return 'I\'m sorry you\'re feeling that way. Remember, I\'m always here to chat
with you. Would you like to play a game or talk about something that makes you
happy?';
} else if (message.contains('game') || message.contains('play')) {
return 'That sounds fun! You can play brain games from the home screen. They\'re
great for keeping your mind sharp! 🎮🧠';
} else if (message.contains('help')) {
return 'I\'m here to help! You can ask me about your pills, play games, or just
chat. What would you like to do?';
} else if (message.contains('thank')) {
return 'You\'re very welcome! I\'m always happy to help you. Feel free to chat
anytime! 💙';
} else {
return 'That\'s interesting! Tell me more about that. I love chatting with you!
😊';
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
@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: Colors.white,
appBar: AppBar(
backgroundColor: Colors.pink.shade400,
elevation: 0,
leading: IconButton(
icon: const Icon(Icons.arrow_back, size: 32, color: Colors.white),
onPressed: () => Navigator.pop(context),
),
title: Row(
children: [
Container(
padding: const EdgeInsets.all(8),
decoration: const BoxDecoration(
color: Colors.white,
shape: BoxShape.circle,
),
child: const Icon(Icons.smart_toy, color: Colors.pink, size: 28),
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
'Always here for you',

style: TextStyle(fontSize: 14, color: Colors.white70),
),
],
),
],
),
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
// Quick Responses
if (_messages.length <= 2)
Container(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'Quick replies:',

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
children: [
_buildQuickReply('How are you?'),
_buildQuickReply('Tell me a joke'),
_buildQuickReply('I need help'),
_buildQuickReply('Let\'s play a game'),
],
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
hintText: 'Type a message...',
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
onPressed: _sendMessage,
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
color: Colors.pink.shade100,
shape: BoxShape.circle,
),
child: const Icon(Icons.smart_toy, color: Colors.pink, size: 24),
),
const SizedBox(width: 8),
],
Flexible(
child: Container(
padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
decoration: BoxDecoration(
gradient:
message.isUser
? LinearGradient(
colors: [Colors.blue.shade400, Colors.blue.shade600],
)
: LinearGradient(
colors: [Colors.grey.shade100, Colors.grey.shade200],
),
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
Text(
_formatTime(message.timestamp),
style: TextStyle(
fontSize: 12,
color:
message.isUser
? Colors.white.withAlpha(179)

: Colors.black54,

),
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
child: const Icon(Icons.smart_toy, color: Colors.pink, size: 24),
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
// Chat Message Model
class ChatMessage {
final String text;
final bool isUser;
final DateTime timestamp;
ChatMessage({
required this.text,
required this.isUser,
required this.timestamp,
});
}
*/