
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';

// ML Kit — mobile only
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// Tesseract JS interop — web only
import 'tesseract_ocr.dart' if (dart.library.io) 'tesseract_ocr_stub.dart';

class VisionGuardianScreen extends StatefulWidget {
  final String userId;
  const VisionGuardianScreen({Key? key, required this.userId})
    : super(key: key);

  @override
  State<VisionGuardianScreen> createState() => _VisionGuardianScreenState();
}

class _VisionGuardianScreenState extends State<VisionGuardianScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  TextRecognizer? _textRecognizer;

  bool _isAnalyzing = false;
  String? _detectedMedicineName;
  Map<String, dynamic>? _medicationInfo;

  File? _selectedImage; // mobile
  Uint8List? _webImageBytes; // web

  List<String> _extractedWords = [];
  String _analyzeStatus = 'Reading label...';

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  static const _stopWords = {
    'mg',
    'ml',
    'mcg',
    'iu',
    'tablet',
    'tablets',
    'tab',
    'tabs',
    'capsule',
    'capsules',
    'cap',
    'caps',
    'syrup',
    'solution',
    'injection',
    'cream',
    'ointment',
    'gel',
    'drops',
    'patch',
    'dose',
    'doses',
    'take',
    'taken',
    'daily',
    'twice',
    'thrice',
    'once',
    'before',
    'after',
    'with',
    'food',
    'water',
    'meal',
    'meals',
    'the',
    'and',
    'for',
    'use',
    'only',
    'keep',
    'out',
    'of',
    'reach',
    'children',
    'store',
    'below',
    'room',
    'temp',
    'exp',
    'batch',
    'mfg',
    'lot',
    'net',
    'wt',
    'each',
    'contains',
    'manufactured',
    'by',
    'ltd',
    'pvt',
    'inc',
    'pharma',
    'labs',
    'pharmaceuticals',
    'directions',
    'warning',
    'caution',
  };

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    }
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _textRecognizer?.close();
    _animController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 32, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '👁️ Vision Guardian',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_detectedMedicineName == null && !_isAnalyzing) ...[
              _buildInstructionCard(),
              const SizedBox(height: 24),
            ],

            Row(
              children: [
                if (!kIsWeb)
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.camera_alt,
                      label: 'Take Photo',
                      color: Colors.blue,
                      onTap: () => _captureImage(ImageSource.camera),
                    ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.photo_library,
                    label: kIsWeb ? 'Upload Photo/Take photo' : 'Choose Photo',
                    color: Colors.purple,
                    onTap: () => _captureImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Image preview
            if (kIsWeb && _webImageBytes != null) ...[
              _buildWebImagePreview(),
              const SizedBox(height: 20),
            ],
            if (!kIsWeb && _selectedImage != null) ...[
              _buildMobileImagePreview(),
              const SizedBox(height: 20),
            ],

            if (_isAnalyzing) _buildLoadingIndicator(),

            /*if (_extractedWords.isNotEmpty && !_isAnalyzing) ...[
              _buildExtractedTextCard(),
              const SizedBox(height: 20),
            ],*/
            if (_detectedMedicineName != null && !_isAnalyzing)
              FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child:
                      _medicationInfo != null
                          ? _buildMatchFoundCard()
                          : _buildNotFoundCard(),
                ),
              ),

            if (_detectedMedicineName != null && !_isAnalyzing) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _resetScan,
                icon: const Icon(Icons.refresh, size: 22),
                label: const Text(
                  'Scan Another Medicine',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),
            _buildRecentScansSection(),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // UI WIDGETS
  // ===========================================================================

  Widget _buildInstructionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.purple.shade50],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade200, width: 2),
      ),
      child: Column(
        children: [
          const Icon(Icons.info_outline, size: 40, color: Colors.blue),
          const SizedBox(height: 12),
          const Text(
            'How it works',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            '1. Upload a photo of your medicine label\n'
            '2. Vision Guardian reads the text\n'
            '3. We check if it\'s in your schedule\n'
            '4. You get safety confirmation instantly',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: kIsWeb ? Colors.blue.shade100 : Colors.green.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  kIsWeb ? Icons.language : Icons.offline_bolt,
                  size: 16,
                  color: kIsWeb ? Colors.blue.shade700 : Colors.green.shade700,
                ),
                const SizedBox(width: 6),
                Text(
                  kIsWeb
                      ? 'Tesseract.js OCR • No API Key Needed'
                      : 'ML Kit • Works 100% Offline',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color:
                        kIsWeb ? Colors.blue.shade700 : Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isAnalyzing ? null : onTap,
      child: Opacity(
        opacity: _isAnalyzing ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withOpacity(0.75)]),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, size: 40, color: Colors.white),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebImagePreview() {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(
              _webImageBytes!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '📸 Uploaded',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileImagePreview() {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              _selectedImage!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '📸 Scanned',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(strokeWidth: 3),
          const SizedBox(height: 20),
          Text(
            _analyzeStatus,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (kIsWeb)
            Text(
              'Tesseract.js is processing your image...\nThis may take 5–15 seconds on first run.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            )
          else
            Text(
              'Please wait...',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }

  Widget _buildExtractedTextCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.text_fields, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              const Text(
                'Text detected from label:',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _extractedWords.map((word) {
                  final isMatch =
                      _detectedMedicineName != null &&
                      (word.toLowerCase().contains(
                            _detectedMedicineName!.toLowerCase(),
                          ) ||
                          _detectedMedicineName!.toLowerCase().contains(
                            word.toLowerCase(),
                          ));
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isMatch ? Colors.green.shade100 : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            isMatch
                                ? Colors.green.shade400
                                : Colors.orange.shade300,
                        width: isMatch ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      word,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isMatch ? Colors.green.shade800 : Colors.black87,
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchFoundCard() {
    final med = _medicationInfo!;
    final String name = med['name'] ?? 'Unknown';
    final String dose = med['dose'] ?? '';
    final String time = med['time'] ?? 'Not set';
    final String days = med['days'] ?? 'Daily';
    final String note = med['note'] ?? '';
    final bool takenToday = med['takenToday'] ?? false;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.green.shade400, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF16a34a), Color(0xFF15803d)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      '✓',
                      style: TextStyle(
                        fontSize: 30,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'This is YOUR medicine!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Found in your medication schedule ✓',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    if (dose.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.green.shade200,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          dose,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _detailBox('⏰', 'Time', time)),
                    const SizedBox(width: 12),
                    Expanded(child: _detailBox('📅', 'Frequency', days)),
                  ],
                ),
                const SizedBox(height: 16),
                takenToday ? _alreadyTakenBox() : _notYetTakenBox(time),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.shade200,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text('🍽️', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            note,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                if (!takenToday)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _markAsTaken(med),
                      icon: const Icon(Icons.check_circle_outline, size: 26),
                      label: const Text(
                        'Mark as Taken',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 3,
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade700,
                          size: 26,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Already Taken Today!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailBox(String emoji, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _notYetTakenBox(String time) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200, width: 1.5),
      ),
      child: Row(
        children: [
          const Text('⏰', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Not Yet Taken Today',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Scheduled at  $time',
                  style: TextStyle(fontSize: 14, color: Colors.orange.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _alreadyTakenBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade200, width: 1.5),
      ),
      child: Row(
        children: [
          const Text('✅', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Already Taken Today!',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.green.shade900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Great job staying on schedule 🎉',
                  style: TextStyle(fontSize: 14, color: Colors.green.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.red.shade400, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFdc2626), Color(0xFFb91c1c)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 2.5,
                    ),
                  ),
                  child: const Center(
                    child: Text('⚠️', style: TextStyle(fontSize: 36)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'NOT Your Medicine!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'This is not in your schedule',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.red.shade200, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DETECTED MEDICINE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.red.shade400,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _detectedMedicineName ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.red.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '⛔  Do NOT take this medicine!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please check with your doctor or caretaker before taking it.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _callCaretaker,
                    icon: const Icon(Icons.phone, size: 24),
                    label: const Text(
                      'Call Caretaker',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentScansSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Scans',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('vision_guardian_scans')
                  .where('userId', isEqualTo: widget.userId)
                  .orderBy('timestamp', descending: true)
                  .limit(5)
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'No scans yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final data =
                    snapshot.data!.docs[index].data() as Map<String, dynamic>;
                return _buildScanHistoryItem(data);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildScanHistoryItem(Map<String, dynamic> data) {
    final String name = data['medicineName'] ?? 'Unknown';
    final bool found = data['found'] ?? false;
    final Timestamp ts = data['timestamp'] ?? Timestamp.now();
    final String timeAgo = _getTimeAgo(ts.toDate());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: found ? Colors.green.shade200 : Colors.red.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: found ? Colors.green.shade100 : Colors.red.shade100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                found ? '✓' : '✗',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: found ? Colors.green : Colors.red,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeAgo,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: found ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              found ? 'Matched' : 'Not Found',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: found ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CAPTURE + ANALYZE
  // ===========================================================================

  Future<void> _captureImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();

      setState(() {
        _webImageBytes = bytes;
        if (!kIsWeb) _selectedImage = File(image.path);
        _isAnalyzing = true;
        _analyzeStatus = 'Reading label...';
        _detectedMedicineName = null;
        _medicationInfo = null;
        _extractedWords = [];
      });

      if (kIsWeb) {
        await _analyzeWithTesseract(bytes);
      } else {
        await _analyzeWithMlKit(File(image.path));
      }
    } catch (e) {
      setState(() => _isAnalyzing = false);
      _showError('Failed to load image: $e');
    }
  }

  // ── Web: Tesseract.js (no API key, runs in browser) ──────────────────────
  Future<void> _analyzeWithTesseract(Uint8List imageBytes) async {
    try {
      setState(() => _analyzeStatus = 'Running Tesseract OCR...');
      final List<String> words = await TesseractOcr.recognizeFromBytes(
        imageBytes,
      );

      setState(() {
        _extractedWords = words;
        _analyzeStatus = 'Checking your medication list...';
      });

      if (words.isEmpty) {
        setState(() => _isAnalyzing = false);
        _showError('No text detected. Try a clearer photo.');
        return;
      }

      await _findMedicineInDatabase(words);
    } catch (e) {
      setState(() => _isAnalyzing = false);
      _showError('Tesseract OCR failed: $e');
    }
  }

  // ── Mobile: ML Kit (offline) ─────────────────────────────────────────────
  Future<void> _analyzeWithMlKit(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognized = await _textRecognizer!.processImage(
        inputImage,
      );

      final List<String> words = [];
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          for (final element in line.elements) {
            final w = element.text.trim();
            if (w.isNotEmpty) words.add(w);
          }
        }
      }

      setState(() {
        _extractedWords = words;
        _analyzeStatus = 'Checking your medication list...';
      });

      if (words.isEmpty) {
        setState(() => _isAnalyzing = false);
        _showError('No text detected. Try a clearer photo.');
        return;
      }

      await _findMedicineInDatabase(words);
    } catch (e) {
      setState(() => _isAnalyzing = false);
      _showError('Failed to analyze image: $e');
    }
  }

  // ===========================================================================
  // DATABASE MATCHING
  // ===========================================================================

  Future<void> _findMedicineInDatabase(List<String> words) async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .collection('medications')
              .get();

      if (snapshot.docs.isEmpty) {
        final guessed = _guessMedicineName(words);
        setState(() {
          _detectedMedicineName = guessed;
          _medicationInfo = null;
          _isAnalyzing = false;
        });
        await _saveScanToHistory(guessed, false);
        _animController.forward(from: 0);
        return;
      }

      Map<String, dynamic>? bestMatch;
      String? bestDocId;
      String? bestName;
      int bestScore = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final medName = (data['name'] ?? '').toString().trim();
        if (medName.isEmpty) continue;

        final score = _matchScore(medName, words);
        if (score > bestScore) {
          bestScore = score;
          bestMatch = data;
          bestDocId = doc.id;
          bestName = medName;
        }
      }

      if (bestScore >= 60 && bestMatch != null) {
        final bool takenToday = _wasTakenToday(bestMatch['lastTaken']);
        setState(() {
          _detectedMedicineName = bestName;
          _medicationInfo = {
            'id': bestDocId,
            'name': bestMatch!['name'] ?? '',
            'dose': bestMatch['dose'] ?? '',
            'time': bestMatch['time'] ?? '',
            'days': bestMatch['days'] ?? 'Daily',
            'note': bestMatch['note'] ?? '',
            'takenToday': takenToday,
          };
          _isAnalyzing = false;
        });
        await _saveScanToHistory(bestName!, true);
      } else {
        final guessed = _guessMedicineName(words);
        setState(() {
          _detectedMedicineName = guessed;
          _medicationInfo = null;
          _isAnalyzing = false;
        });
        await _saveScanToHistory(guessed, false);
      }

      _animController.forward(from: 0);
    } catch (e) {
      setState(() => _isAnalyzing = false);
      _showError('Failed to check your medication list: $e');
    }
  }

  int _matchScore(String medName, List<String> words) {
    final med = medName.toLowerCase().trim();
    final fullText = words.join(' ').toLowerCase();

    if (fullText.contains(med)) return 100;

    for (final word in words) {
      final w = word.toLowerCase().trim();
      if (w.length < 4) continue;
      if (med.contains(w)) return 90;
      if (w.length >= 5) {
        final prefix = w.substring(0, (w.length * 0.7).round());
        if (med.startsWith(prefix)) return 80;
      }
      if (w.length >= 5 &&
          med.length >= 5 &&
          med.substring(0, 5) == w.substring(0, 5))
        return 70;
      if (w.length >= 4 &&
          med.length >= 4 &&
          med.substring(0, 4) == w.substring(0, 4))
        return 60;
    }
    return 0;
  }

  String _guessMedicineName(List<String> words) {
    final candidates =
        words.where((w) {
          final lower = w.toLowerCase();
          return w.length >= 4 &&
              !_stopWords.contains(lower) &&
              !RegExp(r'^\d+$').hasMatch(w) &&
              RegExp(r'[a-zA-Z]').hasMatch(w);
        }).toList();

    if (candidates.isEmpty) {
      return words.isNotEmpty ? words.first : 'Unknown';
    }
    candidates.sort((a, b) => b.length.compareTo(a.length));
    return candidates.first;
  }

  bool _wasTakenToday(dynamic lastTaken) {
    if (lastTaken == null) return false;
    try {
      final DateTime taken = (lastTaken as Timestamp).toDate();
      final DateTime now = DateTime.now();
      return taken.year == now.year &&
          taken.month == now.month &&
          taken.day == now.day;
    } catch (_) {
      return false;
    }
  }

  // ===========================================================================
  // ACTIONS
  // ===========================================================================

  Future<void> _markAsTaken(Map<String, dynamic> med) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('medications')
          .doc(med['id'])
          .update({
            'takenToday': true,
            'lastTaken': Timestamp.now(),
            'status': 'taken',
          });

      setState(() {
        _medicationInfo = {..._medicationInfo!, 'takenToday': true};
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Marked as taken! Great job!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      _showError('Failed to mark as taken: $e');
    }
  }

  Future<void> _saveScanToHistory(String medicineName, bool found) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('vision_guardian_scans')
          .add({
            'userId': widget.userId,
            'medicineName': medicineName,
            'found': found,
            'timestamp': Timestamp.now(),
          });
      print('✅ Scan saved: ${doc.id}'); // add this
    } catch (e) {
      print('❌ Save failed: $e'); // add this
    }
  }

  void _resetScan() {
    setState(() {
      _selectedImage = null;
      _webImageBytes = null;
      _detectedMedicineName = null;
      _medicationInfo = null;
      _extractedWords = [];
      _isAnalyzing = false;
    });
    _animController.reset();
  }

  void _callCaretaker() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('📞 Call Caretaker'),
            content: const Text('Calling your caretaker for assistance...'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  String _getTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _showError(String msg) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Error'),
            content: Text(msg),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }
}