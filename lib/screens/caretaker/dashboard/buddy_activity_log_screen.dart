import 'package:flutter/material.dart';
import '../../../theme/caretaker_theme.dart';
import 'enhanced_buddy_activity_screen.dart';

class BuddyActivityLogScreen extends StatelessWidget {
  const BuddyActivityLogScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CaretakerColors.background,
      appBar: AppBar(
        title: const Text('Buddy Activity Log', style: CaretakerTextStyles.header),
        backgroundColor: CaretakerColors.cardWhite,
        iconTheme: const IconThemeData(color: CaretakerColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildLogList(),
            const SizedBox(height: 24),
            _buildEmotionalWellness(),
          ],
        ),
      ),
    );
  }

  Widget _buildLogList() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CaretakerColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLogItem(Icons.psychology, 'Detected loneliness pattern', 'Today, 2:00 PM', true),
          const Divider(),
          _buildLogItem(Icons.video_call, 'Facilitated video call', 'Yesterday, 6:00 PM', false),
          const Divider(),
          _buildLogItem(Icons.notifications_active, 'Reminded Caregiver', 'Oct 24, 9:00 AM', true),
        ],
      ),
    );
  }

  Widget _buildLogItem(IconData icon, String description, String timestamp, bool urgent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: CaretakerColors.lightGreen,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: CaretakerColors.primaryGreen, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(timestamp, style: CaretakerTextStyles.caption),
              ],
            ),
          ),
          if (urgent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: CaretakerColors.errorRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Urgent', style: TextStyle(fontSize: 10, color: CaretakerColors.errorRed, fontWeight: FontWeight.bold)),
            )
        ],
      ),
    );
  }

  Widget _buildEmotionalWellness() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CaretakerColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Emotional Wellness', style: CaretakerTextStyles.cardTitle),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Happy', style: TextStyle(fontWeight: FontWeight.bold, color: CaretakerColors.primaryGreen)),
              Text('65%', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: 0.65,
              minHeight: 10,
              backgroundColor: CaretakerColors.dividerGrey,
              color: CaretakerColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 8),
          const Align(
             alignment: Alignment.centerRight,
             child: Text('+5% this week', style: TextStyle(fontSize: 12, color: CaretakerColors.successGreen, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}


/*// Add navigation:
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => EnhancedBuddyActivityScreen(
      caretakerId: currentCaretakerId,
      elderlyId: elderlyUserId,
      elderlyName: elderlyUserName,
    ),
  ),
);*/

class YourScreen extends StatelessWidget {
  final String currentCaretakerId;
  final String elderlyUserId;
  final String elderlyUserName;

  const YourScreen({
    super.key,
    required this.currentCaretakerId,
    required this.elderlyUserId,
    required this.elderlyUserName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // NOW Navigator.push is inside a function
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => EnhancedBuddyActivityScreen(
                      caretakerId: currentCaretakerId,
                      elderlyId: elderlyUserId,
                      elderlyName: elderlyUserName,
                    ),
              ),
            );
          },
          child: const Text('View Buddy Activity'),
        ),
      ),
    );
  }
}


/*## 🔔 Notification Triggers

The system automatically sends notifications when it detects:

✅ **Missing someone** - "I miss mom", "wish dad would visit"  
✅ **Loneliness** - "feeling lonely", "no one to talk to"  
✅ **Health concerns** - "not feeling well", "pain in my chest"  
✅ **Sadness/Depression** - persistent sad sentiment  
✅ **Anxiety** - "worried", "scared", "anxious"

## 📊 Weekly Reports Include:

- Emotional wellness score (0-100)
- Sentiment breakdown (% happy, sad, anxious, etc.)
- Concerning patterns detected
- AI-generated summary with recommendations
- Total conversation count

## 🧪 Testing

Test with these messages in the elderly buddy chat:
```
"I really miss my daughter. I wish she would visit more often."
*/