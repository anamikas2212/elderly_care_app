
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/caretaker_theme.dart';
import '../../../services/caretaker_data_service.dart';
import 'cognitive_health_screen.dart';
import 'safety_monitor_screen.dart';
import 'medication_screen.dart';
import 'medication_management_screen.dart';
import 'buddy_activity_log_screen.dart';
import 'connect_screens.dart';
import '../../auth/login_screen.dart';

class CaretakerDashboard extends StatefulWidget {
  const CaretakerDashboard({Key? key}) : super(key: key);

  @override
  State<CaretakerDashboard> createState() => _CaretakerDashboardState();
}

class _CaretakerDashboardState extends State<CaretakerDashboard> {
  // Using Mock/Real Service
  final CaretakerDataService _dataService = CaretakerDataService();
  String elderlyName = "Loading...";
  String age = "--";
  String gender = "--";

  @override
  void initState() {
    super.initState();
    _loadElderlyName();
  }

  Future<void> _loadElderlyName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      elderlyName = prefs.getString('elderly_user_name') ?? "No Active Patient";
      age = prefs.getString('elderly_user_age') ?? "--";
      gender = prefs.getString('elderly_user_gender') ?? "--";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CaretakerColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: CaretakerLayout.screenPadding,
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildPatientHeaderCard(context),
                const SizedBox(height: 16),
                _buildAlertBanner(context),
                const SizedBox(height: 16),
                _buildStatsCardsRow(context),
                const SizedBox(height: 24),
                _buildSectionTitle("Quick Access"),
                const SizedBox(height: 12),
                _buildQuickAccessGrid(context),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: CaretakerColors.cardWhite,
      floating: true,
      pinned: true,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: CaretakerColors.lightGreen,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text(
            "EC",
            style: TextStyle(
              color: CaretakerColors.primaryGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Overview", style: CaretakerTextStyles.header),
          Text("Caretaker Dashboard", style: CaretakerTextStyles.caption.copyWith(fontSize: 12)),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none, color: CaretakerColors.textPrimary),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: CaretakerColors.errorRed),
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildPatientHeaderCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [CaretakerColors.primaryGreen, Color(0xFF2DBE91)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: CaretakerLayout.cardRadius,
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                elderlyName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Age $age • $gender",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    "Living Room • 5 min ago",
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: CaretakerColors.lightGreen,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              "Stable",
              style: TextStyle(
                color: CaretakerColors.successGreen,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5), // Light Amber
        borderRadius: CaretakerLayout.cardRadius,
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: CaretakerColors.warningAmber, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Missed Evening Medication",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5D4037),
                    fontSize: 14,
                    fontFamily: 'Inter',
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Blood pressure pill overdue by 2 hours",
                  style: TextStyle(color: Color(0xFF8D6E63), fontSize: 12),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MedicationManagementScreen()));
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF5D4037),
              side: const BorderSide(color: Color(0xFF5D4037)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("View"),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCardsRow(BuildContext context) {
    return StreamBuilder<int>(
      stream: _dataService.getColorTapGameCount(elderlyName),
      builder: (context, snapshot) {
        final gameCount = snapshot.data ?? 0;
        
        return Row(
          children: [
            Expanded(
              child: _buildSmallStatCard(
                title: "Color Tap Games",
                value: "$gameCount",
                subtext: "Total played",
                icon: Icons.videogame_asset,
                color: CaretakerColors.highlightBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSmallStatCard(
                title: "Meds",
                value: "87%",
                subtext: "Adherence",
                icon: Icons.medication,
                color: CaretakerColors.successGreen,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSmallStatCard({required String title, required String value, required String subtext, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CaretakerColors.cardWhite,
        borderRadius: CaretakerLayout.cardRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: CaretakerTextStyles.caption),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: CaretakerColors.textPrimary,
            ),
          ),
          Text(subtext, style: const TextStyle(fontSize: 11, color: CaretakerColors.successGreen)),
        ],
      ),
    );
  }

  Widget _buildCognitiveScoreCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CaretakerColors.cardWhite,
        borderRadius: CaretakerLayout.cardRadius,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 100,
                          width: 100,
                          child: CircularProgressIndicator(
                            value: 0.76,
                            strokeWidth: 10,
                            backgroundColor: CaretakerColors.lightGreen,
                            color: CaretakerColors.primaryGreen,
                          ),
                        ),
                        const Text("76", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text("Cognitive Health", style: CaretakerTextStyles.cardTitle),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _buildScoreRow("Memory", 0.82, CaretakerColors.primaryGreen),
                    const SizedBox(height: 8),
                    _buildScoreRow("Attention", 0.71, CaretakerColors.warningAmber),
                    const SizedBox(height: 8),
                    _buildScoreRow("Processing", 0.75, CaretakerColors.highlightBlue),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
               onPressed: () {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => const CognitiveHealthScreen()));
               },
               style: ElevatedButton.styleFrom(
                 backgroundColor: CaretakerColors.primaryGreen,
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
               ),
               child: const Text("View Details", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreRow(String label, double value, Color color) {
    return Row(
      children: [
        SizedBox(width: 70, child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: CaretakerColors.dividerGrey,
            color: color,
            minHeight: 6,
          ),
        ),
        const SizedBox(width: 8),
        Text("${(value * 100).toInt()}%", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: CaretakerTextStyles.sectionTitle);
  }

  Widget _buildQuickAccessGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildNavCard(context, "Safety Monitor", Icons.security, Colors.red.shade100, Colors.red, const SafetyMonitorScreen()),
        _buildNavCard(context, "Medication", Icons.medical_services, Colors.blue.shade100, Colors.blue, const MedicationScreen()),
        _buildNavCard(context, "Care Connect", Icons.people, Colors.purple.shade100, Colors.purple, const VisionGuardianScreen()),
        _buildNavCard(context, "Activity Log", Icons.history, Colors.orange.shade100, Colors.orange, const BuddyActivityLogScreen()),
      ],
    );
  }

  Widget _buildNavCard(BuildContext context, String title, IconData icon, Color bg, Color iconColor, Widget screen) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
      },
      child: Container(
        decoration: BoxDecoration(
          color: CaretakerColors.cardWhite,
          borderRadius: CaretakerLayout.cardRadius,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(height: 8),
            Text(title, style: CaretakerTextStyles.cardTitle),
          ],
        ),
      ),
    );
  }
}
