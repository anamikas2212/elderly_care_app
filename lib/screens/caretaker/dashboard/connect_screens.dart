
import 'package:flutter/material.dart';
import '../../../theme/caretaker_theme.dart';

class VisionGuardianScreen extends StatelessWidget {
  const VisionGuardianScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CaretakerColors.background,
      appBar: AppBar(
        title: const Text('Vision Guardian', style: CaretakerTextStyles.header),
        backgroundColor: CaretakerColors.cardWhite,
        iconTheme: const IconThemeData(color: CaretakerColors.textPrimary),
        elevation: 0,
      ),
      body: ListView(
        padding: CaretakerLayout.screenPadding,
        children: [
          _buildSectionHeader('AI Camera Verification'),
          const SizedBox(height: 16),
          _buildVerificationItem('Aspirin', '8:05 AM', true),
          const SizedBox(height: 12),
          _buildVerificationItem('Vitamin D', '9:12 AM', true),
          const SizedBox(height: 12),
          _buildVerificationItem('Atorvastatin', 'Pending', false),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: CaretakerTextStyles.sectionTitle);
  }

  Widget _buildVerificationItem(String medName, String time, bool verified) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CaretakerColors.cardWhite,
        borderRadius: CaretakerLayout.cardRadius,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CaretakerColors.lightGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.camera_alt, color: CaretakerColors.primaryGreen),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(medName, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(time, style: CaretakerTextStyles.caption),
              ],
            ),
          ),
          if (verified)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: CaretakerColors.successGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Verified', style: TextStyle(color: CaretakerColors.successGreen, fontWeight: FontWeight.bold, fontSize: 12)),
            )
        ],
      ),
    );
  }
}

class BuddyChatScreen extends StatelessWidget {
  const BuddyChatScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CaretakerColors.background,
      appBar: AppBar(
        title: const Text('My Buddy', style: CaretakerTextStyles.header),
        backgroundColor: CaretakerColors.cardWhite,
        iconTheme: const IconThemeData(color: CaretakerColors.textPrimary),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: CaretakerLayout.screenPadding,
        child: Column(
          children: [
            _buildCareBuddyStatus(),
            const SizedBox(height: 20),
            _buildCallReminderCard(),
            const SizedBox(height: 20),
            _buildVoiceMessagesList(),
             const SizedBox(height: 20),
            _buildActivityLog(),
          ],
        ),
      ),
    );
  }

  Widget _buildCareBuddyStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CaretakerColors.lightGreen,
        borderRadius: CaretakerLayout.cardRadius,
        border: Border.all(color: CaretakerColors.primaryGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: const [
          Icon(Icons.handshake, color: CaretakerColors.primaryGreen),
          SizedBox(width: 12),
          Text('Care Buddy Active', style: TextStyle(fontWeight: FontWeight.bold, color: CaretakerColors.primaryGreen)),
        ],
      ),
    );
  }

  Widget _buildCallReminderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: CaretakerLayout.cardRadius,
        border: Border.all(color: CaretakerColors.errorRed.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Time to call!', style: CaretakerTextStyles.cardTitle),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: CaretakerColors.errorRed, borderRadius: BorderRadius.circular(10)),
                child: const Text('3 days overdue', style: TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
             'AI Insight: She might be feeling lonely.',
             style: TextStyle(color: CaretakerColors.textSecondary, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.call, color: Colors.white),
                  label: const Text('Call Now', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CaretakerColors.successGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceMessagesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Voice Messages', style: CaretakerTextStyles.sectionTitle),
        const SizedBox(height: 12),
        _buildVoiceMessageItem('Morning Check-in', 'Happy', '0:45', '10:00 AM'),
        const SizedBox(height: 12),
        _buildVoiceMessageItem('Feeling confused', 'Anxious', '1:20', 'Yesterday'),
      ],
    );
  }

  Widget _buildVoiceMessageItem(String title, String emotion, String duration, String time) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CaretakerColors.cardWhite,
        borderRadius: CaretakerLayout.cardRadius,
        boxShadow: [
           BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
             backgroundColor: CaretakerColors.highlightBlue.withOpacity(0.1),
             child: const Icon(Icons.play_arrow, color: CaretakerColors.highlightBlue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                 Row(
                   children: [
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                       decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4)),
                       child: Text(emotion, style: TextStyle(fontSize: 10, color: Colors.orange.shade800)),
                     ),
                     const SizedBox(width: 8),
                     Text('$duration • $time', style: CaretakerTextStyles.caption),
                   ],
                 ),
               ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityLog() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Buddy Activity Log', style: CaretakerTextStyles.sectionTitle),
        const SizedBox(height: 12),
        _buildLogItem(Icons.favorite, 'Detected loneliness pattern', 'Today', true),
        const SizedBox(height: 12),
        _buildLogItem(Icons.video_call, 'Facilitated video call', 'Yesterday', false),
      ],
    );
  }

  Widget _buildLogItem(IconData icon, String text, String time, bool urgent) {
    return Container(
       padding: const EdgeInsets.all(16),
       decoration: BoxDecoration(
         color: CaretakerColors.cardWhite,
         borderRadius: CaretakerLayout.cardRadius,
       ),
       child: Row(
         children: [
           Icon(icon, color: urgent ? CaretakerColors.errorRed : CaretakerColors.textSecondary),
           const SizedBox(width: 16),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
                 Text(time, style: CaretakerTextStyles.caption),
               ],
             ),
           ),
           if (urgent)
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
               decoration: BoxDecoration(color: CaretakerColors.errorRed.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
               child: const Text('Important', style: TextStyle(fontSize: 10, color: CaretakerColors.errorRed)),
             ),
         ],
       ),
    );
  }
}
