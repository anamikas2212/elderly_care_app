// lib/screens/elderly/home/elderly_dashboard.dart

/*import 'package:elderly_care_app/screens/elderly/medication/AddMedicationScreen.dart';
import 'package:flutter/material.dart';
import '../../auth/login_screen.dart';
import '../medication/medication_list_screen.dart';
import '../location_screen.dart';
import '../games_screen.dart';
import '../buddy_chat_screen.dart';
import '../zone_selection_screen.dart';

late String userId;

class ElderlyDashboard extends StatefulWidget {
  final String? currentUserId;
  const ElderlyDashboard({super.key, this.currentUserId});

  @override
  State<ElderlyDashboard> createState() => _ElderlyDashboardState();
}

class _ElderlyDashboardState extends State<ElderlyDashboard> {
  double zoomLevel = 1.0;
  int currentTab = 0;
  bool showDemo = true;
  int demoStep = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (showDemo) {
        _showDemoOverlay();
      }
    });
  }

  void _showDemoOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(color: Colors.black.withAlpha(179)),
                  ),
                ),

                if (demoStep >= 1 && demoStep <= 4)
                  Positioned(
                    top: _getHighlightTop(demoStep),
                    left: _getHighlightLeft(demoStep),
                    child: IgnorePointer(
                      child: Container(
                        width: _getHighlightWidth(demoStep),
                        height: _getHighlightHeight(demoStep),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.yellow, width: 4),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.yellow.withAlpha(128),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                if (demoStep >= 1 && demoStep <= 4)
                  Positioned(
                    top: _getArrowTop(demoStep),
                    left: _getArrowLeft(demoStep),
                    child: Icon(
                      Icons.arrow_downward,
                      size: 60,
                      color: Colors.yellow,
                      shadows: [
                        Shadow(
                          color: Colors.black.withAlpha(128),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),

                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(51),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withAlpha(77),
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                'Step ${demoStep + 1} of 5',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                setState(() {
                                  showDemo = false;
                                });
                              },
                              icon: const Icon(Icons.close, size: 24),
                              label: const Text(
                                'Skip',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 25,
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.white, Colors.blue.shade50],
                          ),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withAlpha(128),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.blue.shade200,
                            width: 3,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _getDemoIcon(demoStep),
                              size: 80,
                              color: _getDemoColor(demoStep),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _getDemoTitle(demoStep),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 15),
                            Text(
                              _getDemoDescription(demoStep),
                              style: const TextStyle(
                                fontSize: 20,
                                color: Colors.black87,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 25),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            if (demoStep > 0)
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    setDialogState(() {
                                      demoStep--;
                                    });
                                  },
                                  icon: const Icon(Icons.arrow_back, size: 28),
                                  label: const Text(
                                    'Back',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey.shade300,
                                    foregroundColor: Colors.black87,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 20,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                ),
                              ),
                            if (demoStep > 0) const SizedBox(width: 15),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  if (demoStep < 4) {
                                    setDialogState(() {
                                      demoStep++;
                                    });
                                  } else {
                                    Navigator.pop(context);
                                    setState(() {
                                      showDemo = false;
                                    });
                                  }
                                },
                                icon: Icon(
                                  demoStep < 4
                                      ? Icons.arrow_forward
                                      : Icons.check,
                                  size: 28,
                                ),
                                label: Text(
                                  demoStep < 4 ? 'Next' : 'Got It!',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 25),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            width: index == demoStep ? 35 : 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color:
                                  index == demoStep
                                      ? Colors.white
                                      : Colors.white.withAlpha(77),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.white.withAlpha(128),
                                width: 1,
                              ),
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 25),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          child: Container(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.logout, size: 80, color: Colors.red),
                const SizedBox(height: 20),
                const Text(
                  'Logout?',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Do you want to go back to the login screen?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, color: Colors.black54),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade300,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          'Yes, Logout',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _getHighlightTop(int step) {
    switch (step) {
      case 1:
        return 220;
      case 2:
        return 220;
      case 3:
        return 470;
      case 4:
        return 640;
      default:
        return 0;
    }
  }

  double _getHighlightLeft(int step) {
    switch (step) {
      case 1:
        return 16;
      case 2:
        return MediaQuery.of(context).size.width / 2 + 8;
      case 3:
        return 16;
      case 4:
        return 16;
      default:
        return 0;
    }
  }

  double _getHighlightWidth(int step) {
    switch (step) {
      case 1:
      case 2:
      case 3:
        return MediaQuery.of(context).size.width / 2 - 24;
      case 4:
        return MediaQuery.of(context).size.width - 32;
      default:
        return 0;
    }
  }

  double _getHighlightHeight(int step) {
    switch (step) {
      case 1:
      case 2:
      case 3:
        return 220;
      case 4:
        return 80;
      default:
        return 0;
    }
  }

  double _getArrowTop(int step) {
    switch (step) {
      case 1:
        return 160;
      case 2:
        return 160;
      case 3:
        return 410;
      case 4:
        return 580;
      default:
        return 0;
    }
  }

  double _getArrowLeft(int step) {
    switch (step) {
      case 1:
        return MediaQuery.of(context).size.width / 4 - 30;
      case 2:
        return MediaQuery.of(context).size.width * 3 / 4 - 30;
      case 3:
        return MediaQuery.of(context).size.width / 4 - 30;
      case 4:
        return MediaQuery.of(context).size.width / 2 - 30;
      default:
        return 0;
    }
  }

  IconData _getDemoIcon(int step) {
    switch (step) {
      case 0:
        return Icons.waving_hand;
      case 1:
        return Icons.medication;
      case 2:
        return Icons.location_on;
      case 3:
        return Icons.psychology;
      case 4:
        return Icons.warning;
      default:
        return Icons.info;
    }
  }

  Color _getDemoColor(int step) {
    switch (step) {
      case 0:
        return Colors.blue;
      case 1:
        return Colors.green;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.purple;
      case 4:
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _getDemoTitle(int step) {
    switch (step) {
      case 0:
        return 'Welcome to Your Care App!';
      case 1:
        return 'Never Miss Your Pills';
      case 2:
        return 'Stay Safe with GPS';
      case 3:
        return 'Keep Your Mind Sharp';
      case 4:
        return 'Emergency SOS Button';
      default:
        return '';
    }
  }

  String _getDemoDescription(int step) {
    switch (step) {
      case 0:
        return 'Let\'s take a quick tour! I\'ll show you where everything is and how to use it.';
      case 1:
        return 'Tap this GREEN card to see your medicines. Press "Taken" when you take them!';
      case 2:
        return 'Tap this BLUE card to see where you are. Your family knows you\'re safe!';
      case 3:
        return 'Tap this PURPLE card to play fun games that keep your mind sharp!';
      case 4:
        return 'Press this BIG RED BUTTON in any emergency. Or shake your phone hard. Help comes fast!';
      default:
        return '';
    }
  }

  void increaseZoom() {
    if (zoomLevel < 1.5) setState(() => zoomLevel += 0.1);
  }

  void decreaseZoom() {
    if (zoomLevel > 0.8) setState(() => zoomLevel -= 0.1);
  }

  void _showZoomDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          child: Container(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.search, size: 80, color: Colors.blue),
                const SizedBox(height: 20),
                const Text(
                  'Screen Magnifier',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Use the zoom buttons below to adjust text size',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, color: Colors.black54),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        decreaseZoom();
                      },
                      icon: const Icon(Icons.zoom_out, size: 32),
                      label: const Text(
                        'Smaller',
                        style: TextStyle(fontSize: 20),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade700,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        increaseZoom();
                      },
                      icon: const Icon(Icons.zoom_in, size: 32),
                      label: const Text(
                        'Bigger',
                        style: TextStyle(fontSize: 20),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontSize: 22, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.purple.shade50],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(26),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed:
                                () => Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                ),
                            icon: const Icon(Icons.arrow_back),
                            iconSize: 32,
                            color: Colors.black87,
                            tooltip: 'Back to Login',
                          ),
                        ),
                        const Expanded(
                          child: Center(
                            child: Text(
                              'My Dashboard',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(26),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: () => _showZoomDialog(context),
                            icon: const Icon(Icons.search),
                            iconSize: 32,
                            color: Colors.blue,
                            tooltip: 'Magnifier',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(26),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: () => _showLogoutDialog(context),
                            icon: const Icon(Icons.logout),
                            iconSize: 32,
                            color: Colors.red,
                            tooltip: 'Logout',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(26),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello, ${widget.currentUserId ?? "Friend"}! 👋',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'Ready to play?',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(26),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: decreaseZoom,
                                icon: const Icon(Icons.zoom_out),
                                iconSize: 32,
                                color: Colors.grey.shade700,
                              ),
                              IconButton(
                                onPressed: increaseZoom,
                                icon: const Icon(Icons.zoom_in),
                                iconSize: 32,
                                color: Colors.blue,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Transform.scale(
                  scale: zoomLevel,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.9,
                          children: [
                            // Pill Reminder Card
                            _buildFeatureCard(
                              icon: Icons.medication,
                              title: 'Pill\nReminder',
                              gradient: [
                                Colors.green.shade400,
                                Colors.green.shade600,
                              ],
                              badge: '1 NOW',
                              badgeColor: Colors.red,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => MedicationListScreen(
                                          userId:
                                              widget.currentUserId ?? 'Unknown',
                                          role: UserRole.elderly, // Added
                                        ),
                                  ),
                                );
                              },
                            ),
                            // Location Card
                            _buildFeatureCard(
                              icon: Icons.location_on,
                              title: 'My\nLocation',
                              gradient: [
                                Colors.blue.shade400,
                                Colors.blue.shade600,
                              ],
                              badge: 'Safe ✓',
                              badgeColor: Colors.green,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LocationScreen(),
                                  ),
                                );
                              },
                            ),
                            // Brain Games Card
                            _buildFeatureCard(
                              icon: Icons.psychology,
                              title: 'Brain\nGames',
                              gradient: [
                                Colors.purple.shade400,
                                Colors.purple.shade600,
                              ],
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => ZoneSelectionScreen(
                                          userId:
                                              widget.currentUserId ??
                                              'Elderly User',
                                        ),
                                  ),
                                );
                              },
                            ),
                            // Buddy Chat Card
                            _buildFeatureCard(
                              icon: Icons.chat,
                              title: 'My\nBuddy',
                              gradient: [
                                Colors.pink.shade400,
                                Colors.pink.shade600,
                              ],
                              badge: '💬',
                              badgeColor: Colors.yellow.shade700,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => BuddyChatScreen(
                                          userId:
                                              widget.currentUserId ??
                                              'Unknown', // Added
                                        ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.warning, size: 40, color: Colors.white),
                  SizedBox(width: 15),
                  Text(
                    'SOS EMERGENCY',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 15),
                  Icon(Icons.phone, size: 40, color: Colors.white),
                ],
              ),
            ),
          ),
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
            child: BottomNavigationBar(
              currentIndex: currentTab,
              onTap: (index) => setState(() => currentTab = index),
              selectedFontSize: 16,
              unselectedFontSize: 16,
              iconSize: 32,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart),
                  label: 'Activity',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required List<Color> gradient,
    String? badge,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withAlpha(128),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(25),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 50, color: gradient[1]),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


/*import 'package:elderly_care_app/screens/elderly/medication/AddMedicationScreen.dart';
import 'package:flutter/material.dart';
import '../../auth/login_screen.dart';
import '../medication/medication_list_screen.dart';
import '../location_screen.dart';
import '../games_screen.dart';
import '../buddy_chat_screen.dart';
import '../zone_selection_screen.dart';

late String userId;

class ElderlyDashboard extends StatefulWidget {
  final String? currentUserId;
  const ElderlyDashboard({super.key, this.currentUserId});

  @override
  State<ElderlyDashboard> createState() => _ElderlyDashboardState();
}

class _ElderlyDashboardState extends State<ElderlyDashboard> {
  double zoomLevel = 1.0;
  int currentTab = 0;
  bool showDemo = true;
  int demoStep = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (showDemo) {
        _showDemoOverlay();
      }
    });
  }

  void _showDemoOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Stack(
              children: [
                // Semi-transparent background
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(color: Colors.black.withAlpha(179)),
                  ),
                ),

                // Highlight specific feature based on step
                if (demoStep >= 1 && demoStep <= 4)
                  Positioned(
                    top: _getHighlightTop(demoStep),
                    left: _getHighlightLeft(demoStep),
                    child: IgnorePointer(
                      child: Container(
                        width: _getHighlightWidth(demoStep),
                        height: _getHighlightHeight(demoStep),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.yellow, width: 4),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.yellow.withAlpha(128),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Arrow pointing to feature
                if (demoStep >= 1 && demoStep <= 4)
                  Positioned(
                    top: _getArrowTop(demoStep),
                    left: _getArrowLeft(demoStep),
                    child: Icon(
                      Icons.arrow_downward,
                      size: 60,
                      color: Colors.yellow,
                      shadows: [
                        Shadow(
                          color: Colors.black.withAlpha(128),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),

                // Demo content
                SafeArea(
                  child: Column(
                    children: [
                      // Skip button at top
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(51),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withAlpha(77),
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                'Step ${demoStep + 1} of 5',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                setState(() {
                                  showDemo = false;
                                });
                              },
                              icon: const Icon(Icons.close, size: 24),
                              label: const Text(
                                'Skip',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 25,
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Demo instruction card at bottom
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.white, Colors.blue.shade50],
                          ),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withAlpha(128),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.blue.shade200,
                            width: 3,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _getDemoIcon(demoStep),
                              size: 80,
                              color: _getDemoColor(demoStep),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _getDemoTitle(demoStep),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 15),
                            Text(
                              _getDemoDescription(demoStep),
                              style: const TextStyle(
                                fontSize: 20,
                                color: Colors.black87,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 25),

                      // Navigation buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            if (demoStep > 0)
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    setDialogState(() {
                                      demoStep--;
                                    });
                                  },
                                  icon: const Icon(Icons.arrow_back, size: 28),
                                  label: const Text(
                                    'Back',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey.shade300,
                                    foregroundColor: Colors.black87,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 20,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                ),
                              ),
                            if (demoStep > 0) const SizedBox(width: 15),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  if (demoStep < 4) {
                                    setDialogState(() {
                                      demoStep++;
                                    });
                                  } else {
                                    Navigator.pop(context);
                                    setState(() {
                                      showDemo = false;
                                    });
                                  }
                                },
                                icon: Icon(
                                  demoStep < 4
                                      ? Icons.arrow_forward
                                      : Icons.check,
                                  size: 28,
                                ),
                                label: Text(
                                  demoStep < 4 ? 'Next' : 'Got It!',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 25),

                      // Page indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            width: index == demoStep ? 35 : 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color:
                                  index == demoStep
                                      ? Colors.white
                                      : Colors.white.withAlpha(77),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.white.withAlpha(128),
                                width: 1,
                              ),
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 25),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          child: Container(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.logout, size: 80, color: Colors.red),
                const SizedBox(height: 20),
                const Text(
                  'Logout?',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Do you want to go back to the login screen?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, color: Colors.black54),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade300,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          'Yes, Logout',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper methods to position highlights
  double _getHighlightTop(int step) {
    switch (step) {
      case 1:
        return 220;
      case 2:
        return 220;
      case 3:
        return 470;
      case 4:
        return 640;
      default:
        return 0;
    }
  }

  double _getHighlightLeft(int step) {
    switch (step) {
      case 1:
        return 16;
      case 2:
        return MediaQuery.of(context).size.width / 2 + 8;
      case 3:
        return 16;
      case 4:
        return 16;
      default:
        return 0;
    }
  }

  double _getHighlightWidth(int step) {
    switch (step) {
      case 1:
      case 2:
      case 3:
        return MediaQuery.of(context).size.width / 2 - 24;
      case 4:
        return MediaQuery.of(context).size.width - 32;
      default:
        return 0;
    }
  }

  double _getHighlightHeight(int step) {
    switch (step) {
      case 1:
      case 2:
      case 3:
        return 220;
      case 4:
        return 80;
      default:
        return 0;
    }
  }

  double _getArrowTop(int step) {
    switch (step) {
      case 1:
        return 160;
      case 2:
        return 160;
      case 3:
        return 410;
      case 4:
        return 580;
      default:
        return 0;
    }
  }

  double _getArrowLeft(int step) {
    switch (step) {
      case 1:
        return MediaQuery.of(context).size.width / 4 - 30;
      case 2:
        return MediaQuery.of(context).size.width * 3 / 4 - 30;
      case 3:
        return MediaQuery.of(context).size.width / 4 - 30;
      case 4:
        return MediaQuery.of(context).size.width / 2 - 30;
      default:
        return 0;
    }
  }

  IconData _getDemoIcon(int step) {
    switch (step) {
      case 0:
        return Icons.waving_hand;
      case 1:
        return Icons.medication;
      case 2:
        return Icons.location_on;
      case 3:
        return Icons.psychology;
      case 4:
        return Icons.warning;
      default:
        return Icons.info;
    }
  }

  Color _getDemoColor(int step) {
    switch (step) {
      case 0:
        return Colors.blue;
      case 1:
        return Colors.green;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.purple;
      case 4:
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _getDemoTitle(int step) {
    switch (step) {
      case 0:
        return 'Welcome to Your Care App!';
      case 1:
        return 'Never Miss Your Pills';
      case 2:
        return 'Stay Safe with GPS';
      case 3:
        return 'Keep Your Mind Sharp';
      case 4:
        return 'Emergency SOS Button';
      default:
        return '';
    }
  }

  String _getDemoDescription(int step) {
    switch (step) {
      case 0:
        return 'Let\'s take a quick tour! I\'ll show you where everything is and how to use it.';
      case 1:
        return 'Tap this GREEN card to see your medicines. Press "Taken" when you take them!';
      case 2:
        return 'Tap this BLUE card to see where you are. Your family knows you\'re safe!';
      case 3:
        return 'Tap this PURPLE card to play fun games that keep your mind sharp!';
      case 4:
        return 'Press this BIG RED BUTTON in any emergency. Or shake your phone hard. Help comes fast!';
      default:
        return '';
    }
  }

  void increaseZoom() {
    if (zoomLevel < 1.5) {
      setState(() {
        zoomLevel += 0.1;
      });
    }
  }

  void decreaseZoom() {
    if (zoomLevel > 0.8) {
      setState(() {
        zoomLevel -= 0.1;
      });
    }
  }

  void _showZoomDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          child: Container(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.search, size: 80, color: Colors.blue),
                const SizedBox(height: 20),
                const Text(
                  'Screen Magnifier',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Use the zoom buttons below to adjust text size',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, color: Colors.black54),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        decreaseZoom();
                      },
                      icon: const Icon(Icons.zoom_out, size: 32),
                      label: const Text(
                        'Smaller',
                        style: TextStyle(fontSize: 20),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade700,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        increaseZoom();
                      },
                      icon: const Icon(Icons.zoom_in, size: 32),
                      label: const Text(
                        'Bigger',
                        style: TextStyle(fontSize: 20),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontSize: 22, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.purple.shade50],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar with Back Button, Greeting and Zoom Controls
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Back Button Row
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(26),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.arrow_back),
                            iconSize: 32,
                            color: Colors.black87,
                            tooltip: 'Back to Login',
                          ),
                        ),
                        const Expanded(
                          child: Center(
                            child: Text(
                              'My Dashboard',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                        // Magnifier Button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(26),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: () {
                              _showZoomDialog(context);
                            },
                            icon: const Icon(Icons.search),
                            iconSize: 32,
                            color: Colors.blue,
                            tooltip: 'Magnifier',
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Logout Button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(26),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: () {
                              _showLogoutDialog(context);
                            },
                            icon: const Icon(Icons.logout),
                            iconSize: 32,
                            color: Colors.red,
                            tooltip: 'Logout',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Greeting and Zoom Controls Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Greeting Card
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(26),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello, ${widget.currentUserId ?? "Friend"}! 👋',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'Ready to play?',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Zoom Controls
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(26),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: decreaseZoom,
                                icon: const Icon(Icons.zoom_out),
                                iconSize: 32,
                                color: Colors.grey.shade700,
                              ),
                              IconButton(
                                onPressed: increaseZoom,
                                icon: const Icon(Icons.zoom_in),
                                iconSize: 32,
                                color: Colors.blue,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Main Content with Zoom
              Expanded(
                child: Transform.scale(
                  scale: zoomLevel,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // Feature Grid
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.9,
                          children: [
                            // Pill Reminder Card
                            _buildFeatureCard(
                              icon: Icons.medication,
                              title: 'Pill\nReminder',
                              gradient: [
                                Colors.green.shade400,
                                Colors.green.shade600,
                              ],
                              badge: '1 NOW',
                              badgeColor: Colors.red,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => MedicationListScreen(
                                          userId:
                                              widget.currentUserId ?? 'Unknown',
                                          role: UserRole.elderly,
                                        ),
                                  ),
                                );
                              },
                            ),
                            // Location Card
                            _buildFeatureCard(
                              icon: Icons.location_on,
                              title: 'My\nLocation',
                              gradient: [
                                Colors.blue.shade400,
                                Colors.blue.shade600,
                              ],
                              badge: 'Safe ✓',
                              badgeColor: Colors.green,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LocationScreen(),
                                  ),
                                );
                              },
                            ),
                            // Brain Games Card
                            _buildFeatureCard(
                              icon: Icons.psychology,
                              title: 'Brain\nGames',
                              gradient: [
                                Colors.purple.shade400,
                                Colors.purple.shade600,
                              ],
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => ZoneSelectionScreen(
                                          userId:
                                              widget.currentUserId ??
                                              'Elderly User',
                                        ),
                                  ),
                                );
                              },
                            ),
                            // Buddy Chat Card
                            _buildFeatureCard(
                              icon: Icons.chat,
                              title: 'My\nBuddy',
                              gradient: [
                                Colors.pink.shade400,
                                Colors.pink.shade600,
                              ],
                              badge: '💬',
                              badgeColor: Colors.yellow.shade700,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const BuddyChatScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // Bottom Navigation
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // SOS Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.warning, size: 40, color: Colors.white),
                  SizedBox(width: 15),
                  Text(
                    'SOS EMERGENCY',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 15),
                  Icon(Icons.phone, size: 40, color: Colors.white),
                ],
              ),
            ),
          ),
          // Navigation Bar
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
            child: BottomNavigationBar(
              currentIndex: currentTab,
              onTap: (index) {
                setState(() {
                  currentTab = index;
                });
              },
              selectedFontSize: 16,
              unselectedFontSize: 16,
              iconSize: 32,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart),
                  label: 'Activity',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required List<Color> gradient,
    String? badge,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withAlpha(128),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(25),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 50, color: gradient[1]),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
   */*/

import 'package:elderly_care_app/screens/elderly/medication/AddMedicationScreen.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../auth/login_screen.dart';
import '../medication/medication_list_screen.dart';
import '../location_screen.dart';
import '../games_screen.dart';
import '../buddy_chat_screen.dart';
import '../zone_selection_screen.dart';
import '../../../services/sos_service.dart';
import '../../../services/user_id_helper.dart';
import 'dart:async'; // For Timer
import '../visionguardian/vision_guardian_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

late String userId;

class ElderlyDashboard extends StatefulWidget {
  final String? currentUserId;
  const ElderlyDashboard({super.key, this.currentUserId});

  @override
  State<ElderlyDashboard> createState() => _ElderlyDashboardState();
}

class _ElderlyDashboardState extends State<ElderlyDashboard> {
  final SOSService _sosService = SOSService();
  double zoomLevel = 1.0;
  int currentTab = 0;
  bool showDemo = true;
  int demoStep = 0;
  bool _triggeringSOS = false;
  String? _careCode;

  Timer? _autoConfirmTimer;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _loadCareCode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (showDemo) {
        _showDemoOverlay();
      }
    });
  }

  Future<void> _loadCareCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('care_code');
    print('🔍 Loading care code from SharedPreferences: $code');
    if (code != null && mounted) {
      setState(() => _careCode = code);
    }
  }

  @override
  void dispose() {
    // ✅ Cancel any active timers
    _autoConfirmTimer?.cancel();
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  /// Trigger SOS Alert with Timer Features
  Future<void> _triggerSOSAlert() async {
    if (_triggeringSOS) return;

    setState(() => _triggeringSOS = true);

    try {
      // Get current user ID
      final elderlyUserId =
          widget.currentUserId ?? await UserIdHelper.getCurrentUserId();

      if (elderlyUserId == null || elderlyUserId.isEmpty) {
        throw Exception('User ID not found');
      }

      // ✅ ADDED: Get location status BEFORE showing dialog
      final locationStatus = await _sosService.getLocationStatus(elderlyUserId);
      final isHome = locationStatus['isHome'] as bool? ?? false;
      final position = locationStatus['position'] as Position?;

      if (!mounted) return;

      // ✅ ADDED: Auto-confirm after 6 seconds
      bool? confirmed;

      // Start auto-confirm timer
      _autoConfirmTimer = Timer(const Duration(seconds: 6), () {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context, true); // Auto-confirm as YES
        }
      });

      // Show confirmation dialog with auto-confirm message
      confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            child: Container(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 100,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Emergency SOS',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'This will alert your caretakers immediately. Are you in an emergency?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  // ✅ ADDED: Auto-confirm countdown message
                  Text(
                    'Auto-confirming in 6 seconds...',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade300,
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: const Text(
                            'No',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: const Text(
                            'Yes, Send SOS',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );

      // ✅ ADDED: Cancel auto-confirm timer if user clicked
      _autoConfirmTimer?.cancel();

      // ✅ ADDED: If null (dialog dismissed by timer), treat as confirmed
      if (confirmed == null) {
        confirmed = true;
      }

      // ✅ ADDED: Handle false alarm
      if (confirmed == false) {
        // User clicked "No" - log false alarm
        await _sosService.triggerFalseAlarm(
          elderlyUserId: elderlyUserId,
          elderlyUserName: elderlyUserId,
        );

        if (!mounted) return;

        // Show false alarm message briefly
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('False alarm logged'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );

        setState(() => _triggeringSOS = false);
        return;
      }

      // Get current location (fallback if not already loaded)
      Position? currentLocation = position;
      if (currentLocation == null) {
        try {
          currentLocation = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
        } catch (e) {
          print('Could not get location: $e');
        }
      }

      // ✅ MODIFIED: Trigger SOS with location status
      await _sosService.triggerSOS(
        elderlyUserId: elderlyUserId,
        elderlyUserName: widget.currentUserId ?? 'Elderly User',
        currentLocation: currentLocation,
        isInsideSafeZone: isHome, // ✅ Pass safe zone status
      );

      if (!mounted) return;

      // ✅ MODIFIED: Show success dialog without OK button
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              child: Container(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 100,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'SOS Alert Sent!',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Your caretakers have been notified. Help is on the way.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, color: Colors.black54),
                    ),
                    const SizedBox(height: 15),
                  ],
                ),
              ),
            ),
      );

      // ✅ ADDED: Auto-dismiss success dialog after 5 seconds
      _autoDismissTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send SOS: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _triggeringSOS = false);
      }
    }
  }

  void _showDemoOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(color: Colors.black.withAlpha(179)),
                  ),
                ),

                // Highlight specific feature based on step
                if (demoStep >= 1 && demoStep <= 4)
                  Positioned(
                    top: _getHighlightTop(demoStep),
                    left: _getHighlightLeft(demoStep),
                    child: IgnorePointer(
                      child: Container(
                        width: _getHighlightWidth(demoStep),
                        height: _getHighlightHeight(demoStep),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.yellow, width: 4),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.yellow.withAlpha(128),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Arrow pointing to feature
                if (demoStep >= 1 && demoStep <= 4)
                  Positioned(
                    top: _getArrowTop(demoStep),
                    left: _getArrowLeft(demoStep),
                    child: Icon(
                      Icons.arrow_downward,
                      size: 60,
                      color: Colors.yellow,
                      shadows: [
                        Shadow(
                          color: Colors.black.withAlpha(128),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(51),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withAlpha(77),
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                'Step ${demoStep + 1} of 5',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                setState(() => showDemo = false);
                              },
                              icon: const Icon(Icons.close, size: 24),
                              label: const Text(
                                'Skip',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 25,
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.white, Colors.blue.shade50],
                          ),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withAlpha(128),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.blue.shade200,
                            width: 3,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _getDemoIcon(demoStep),
                              size: 80,
                              color: _getDemoColor(demoStep),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _getDemoTitle(demoStep),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 15),
                            Text(
                              _getDemoDescription(demoStep),
                              style: const TextStyle(
                                fontSize: 20,
                                color: Colors.black87,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            if (demoStep > 0)
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    setDialogState(() => demoStep--);
                                  },
                                  icon: const Icon(Icons.arrow_back, size: 28),
                                  label: const Text(
                                    'Back',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey.shade300,
                                    foregroundColor: Colors.black87,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 20,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                ),
                              ),
                            if (demoStep > 0) const SizedBox(width: 15),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  if (demoStep < 4) {
                                    setDialogState(() => demoStep++);
                                  } else {
                                    Navigator.pop(context);
                                    setState(() => showDemo = false);
                                  }
                                },
                                icon: Icon(
                                  demoStep < 4
                                      ? Icons.arrow_forward
                                      : Icons.check,
                                  size: 28,
                                ),
                                label: Text(
                                  demoStep < 4 ? 'Next' : 'Got It!',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),

                      // Page indicators (5 dots)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            width: index == demoStep ? 35 : 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color:
                                  index == demoStep
                                      ? Colors.white
                                      : Colors.white.withAlpha(77),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.white.withAlpha(128),
                                width: 1,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 25),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Demo Helper Methods (6-step from File 1) ──────────────────────────────

  double _getHighlightTop(int step) {
    switch (step) {
      case 1:
        return 220;
      case 2:
        return 220;
      case 3:
        return 470;
      case 4:
        return 640;
      default:
        return 0;
    }
  }

  double _getHighlightLeft(int step) {
    switch (step) {
      case 1:
        return 16;
      case 2:
        return MediaQuery.of(context).size.width / 2 + 8;
      case 3:
        return 16;
      case 4:
        return 16;
      default:
        return 0;
    }
  }

  double _getHighlightWidth(int step) {
    switch (step) {
      case 1:
      case 2:
      case 3:
        return MediaQuery.of(context).size.width / 2 - 24;
      case 4:
        return MediaQuery.of(context).size.width - 32;
      default:
        return 0;
    }
  }

  double _getHighlightHeight(int step) {
    switch (step) {
      case 1:
      case 2:
      case 3:
        return 220;
      case 4:
        return 80;
      default:
        return 0;
    }
  }

  double _getArrowTop(int step) {
    switch (step) {
      case 1:
        return 160;
      case 2:
        return 160;
      case 3:
        return 410;
      case 4:
        return 580;
      default:
        return 0;
    }
  }

  double _getArrowLeft(int step) {
    switch (step) {
      case 1:
        return MediaQuery.of(context).size.width / 4 - 30;
      case 2:
        return MediaQuery.of(context).size.width * 3 / 4 - 30;
      case 3:
        return MediaQuery.of(context).size.width / 4 - 30;
      case 4:
        return MediaQuery.of(context).size.width / 2 - 30;
      default:
        return 0;
    }
  }

  IconData _getDemoIcon(int step) {
    switch (step) {
      case 0:
        return Icons.waving_hand;
      case 1:
        return Icons.medication;
      case 2:
        return Icons.location_on;
      case 3:
        return Icons.psychology;
      case 4:
        return Icons.warning;
      default:
        return Icons.info;
    }
  }

  Color _getDemoColor(int step) {
    switch (step) {
      case 0:
        return Colors.blue;
      case 1:
        return Colors.green;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.purple;
      case 4:
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _getDemoTitle(int step) {
    switch (step) {
      case 0:
        return 'Welcome to Your Care App!';
      case 1:
        return 'Never Miss Your Pills';
      case 2:
        return 'Stay Safe with GPS';
      case 3:
        return 'Keep Your Mind Sharp';
      case 4:
        return 'Emergency SOS Button';
      default:
        return '';
    }
  }

  String _getDemoDescription(int step) {
    switch (step) {
      case 0:
        return 'Let\'s take a quick tour! I\'ll show you where everything is and how to use it.';
      case 1:
        return 'Tap this GREEN card to see your medicines. Use the camera icon to scan them!';
      case 2:
        return 'Tap this BLUE card to see where you are. Your family knows you\'re safe!';
      case 3:
        return 'Tap this PURPLE card to play fun games that keep your mind sharp!';
      case 4:
        return 'Press this BIG RED BUTTON in any emergency. Or shake your phone hard. Help comes fast!';
      default:
        return '';
    }
  }

  // ── Logout Dialog ─────────────────────────────────────────────────────────

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          child: Container(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.logout, size: 80, color: Colors.red),
                const SizedBox(height: 20),
                const Text(
                  'Logout?',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Do you want to go back to the login screen?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, color: Colors.black54),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade300,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          'Yes, Logout',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void increaseZoom() {
    if (zoomLevel < 1.5) {
      setState(() => zoomLevel += 0.1);
    }
  }

  void decreaseZoom() {
    if (zoomLevel > 0.8) {
      setState(() => zoomLevel -= 0.1);
    }
  }

  void _showZoomDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          child: Container(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.search, size: 80, color: Colors.blue),
                const SizedBox(height: 20),
                const Text(
                  'Screen Magnifier',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Use the zoom buttons below to adjust text size',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, color: Colors.black54),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        decreaseZoom();
                      },
                      icon: const Icon(Icons.zoom_out, size: 32),
                      label: const Text(
                        'Smaller',
                        style: TextStyle(fontSize: 20),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade700,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        increaseZoom();
                      },
                      icon: const Icon(Icons.zoom_in, size: 32),
                      label: const Text(
                        'Bigger',
                        style: TextStyle(fontSize: 20),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontSize: 22, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F1), // warm cream background
      body: SafeArea(
        child: Transform.scale(
          scale: zoomLevel,
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  // ─── Dashboard Title Bubble ────────────────────────────────
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB74D), // warm peachy-orange
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFB74D).withAlpha(80),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Text(
                        'MY DASHBOARD',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ─── Action Buttons: Zoom + Logout ─────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Zoom Out
                      _buildActionButton(
                        icon: Icons.text_decrease_rounded,
                        color: const Color(
                          0xFF7E57C2,
                        ), // matching purple gradient
                        onTap: decreaseZoom,
                        tooltip: 'Decrease text size',
                      ),
                      const SizedBox(width: 12),
                      // Zoom In
                      _buildActionButton(
                        icon: Icons.text_increase_rounded,
                        color: const Color(0xFF7E57C2),
                        onTap: increaseZoom,
                        tooltip: 'Increase text size',
                      ),
                      const SizedBox(width: 12),
                      // Logout
                      _buildActionButton(
                        icon: Icons.power_settings_new_rounded,
                        color: const Color(0xFFE57373), // soft red
                        onTap: () => _showLogoutDialog(context),
                        tooltip: 'Logout',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ─── Header Card ──────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFEDE7F6), // soft lavender
                          Color(0xFFF3E5F5), // softer pink-lavender
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFCE93D8).withAlpha(60),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withAlpha(25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left: greeting + name
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  children: const [
                                    Text(
                                      'Welcome back ',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF8E6DAF),
                                      ),
                                    ),
                                    Text('👋', style: TextStyle(fontSize: 26)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  widget.currentUserId ?? 'Friend',
                                  style: const TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF4A148C),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Right: code badge
                        if (_careCode != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF5C6BC0),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF5C6BC0).withAlpha(60),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.link,
                                  size: 18,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Code: ',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white70,
                                  ),
                                ),
                                Text(
                                  '${_careCode!.substring(0, 3)}-${_careCode!.substring(3)}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 0.95,
                    children: [
                      _buildPillsCard(),
                      _buildPastelCard(
                        icon: Icons.pin_drop,
                        title: 'My Location',
                        bgColor: const Color(0xFFE3F2FD),
                        borderColor: const Color(0xFF90CAF9),
                        iconColor: const Color(0xFFE91E63),
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LocationScreen(),
                              ),
                            ),
                      ),
                      _buildPastelCard(
                        icon: Icons.extension,
                        title: 'Brain Games',
                        bgColor: const Color(0xFFE8F5E9),
                        borderColor: const Color(0xFFA5D6A7),
                        iconColor: const Color(0xFF66BB6A),
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => ZoneSelectionScreen(
                                      userId:
                                          widget.currentUserId ??
                                          'Elderly User',
                                    ),
                              ),
                            ),
                      ),
                      _buildPastelCard(
                        icon: Icons.chat_bubble,
                        title: 'My Buddy',
                        bgColor: const Color(0xFFF3E5F5),
                        borderColor: const Color(0xFFCE93D8),
                        iconColor: const Color(0xFFBA68C8),
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => BuddyChatScreen(
                                      userId: widget.currentUserId ?? 'Unknown',
                                    ),
                              ),
                            ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ─── SOS Emergency Button ──────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _triggeringSOS ? null : _triggerSOSAlert,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 4,
                      ),
                      child:
                          _triggeringSOS
                              ? const SizedBox(
                                height: 28,
                                width: 28,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                              : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(
                                    Icons.phone,
                                    size: 28,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'SOS Emergency',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                ],
                              ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Action Button Builder ────────────────────────────────────────────────

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(80),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, size: 24, color: Colors.white),
        ),
      ),
    );
  }

  // ── Pastel Card Builder ──────────────────────────────────────────────────

  Widget _buildPastelCard({
    required IconData icon,
    required String title,
    required Color bgColor,
    required Color borderColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: iconColor),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── My Pills Card (with camera icon) ─────────────────────────────────────

  Widget _buildPillsCard() {
    const bgColor = Color(0xFFFFEBEE); // soft pink
    const borderColor = Color(0xFFEF9A9A);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Stack(
        children: [
          // Main card content
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () async {
                final resolvedUserId =
                    await UserIdHelper.getCurrentUserId() ??
                    widget.currentUserId ??
                    'Unknown';
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => MedicationListScreen(
                          userId: resolvedUserId,
                          role: UserRole.elderly,
                        ),
                  ),
                );
              },
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.medication,
                      size: 48,
                      color: Colors.orange.shade400,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'My Pills',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Camera icon — opens Vision Guardian
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => VisionGuardianScreen(
                            userId: widget.currentUserId ?? 'Unknown',
                          ),
                    ),
                  ),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(40),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.camera_alt,
                  size: 32,
                  color: Colors.red.shade400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
