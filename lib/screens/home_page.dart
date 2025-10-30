import 'dart:async';
import 'package:cleaning_schedule/controllers/auth_controller.dart';
import 'package:cleaning_schedule/controllers/stub_controller.dart';
import 'package:cleaning_schedule/models/rdv_model.dart';
import 'package:cleaning_schedule/screens/stubPages/consumable_page.dart';
import 'package:cleaning_schedule/screens/stubPages/view_tasks_no_weekly_page.dart';
import 'package:cleaning_schedule/screens/stubPages/planning_page.dart';
import 'package:cleaning_schedule/screens/stubPages/rdv_calendar_page.dart';
import 'package:cleaning_schedule/widgets/build_tab_item_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatefulWidget {
  final FirebaseAuth auth;

  HomePage({super.key, FirebaseAuth? auth})
      : auth = auth ?? FirebaseAuth.instance;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  AuthController authController = AuthController();
  StubController stubController = StubController();
  int _selectedIndex = 0;
  List<RdvModel> upcomingRdvs = [];
  Timer? _rdvTimer;

  final List<Widget> _pages = const [
    PlanningPage(),
    RdvCalendarPage(),
    ViewTasksNoWeeklyPage(),
    ConsumablePage(),
  ];

  final _tabs = [
    {'icon': Icons.calendar_today, 'label': 'Planning'},
    {'icon': Icons.event, 'label': 'RDV'},
    {'icon': Icons.category, 'label': 'Divers'},
    {'icon': Icons.local_drink, 'label': 'Consommation'},
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  
  Future<void> _waitForUser() async {
    int retries = 0;
    while (FirebaseAuth.instance.currentUser == null && retries < 10) {
      await Future.delayed(const Duration(milliseconds: 300));
      retries++;
    }
  }

  Future<void> _checkUpcomingRdvs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('Utilisateur non connecté, attente...');
      return;
    }

    final userId = user.uid;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('rdvs')
          .where('monitorIds', arrayContains: userId)
          .orderBy('date')
          .get();

      final now = DateTime.now();
      final rdvs = snapshot.docs
          .map((doc) => RdvModel.fromFirestore(doc.id, doc.data()))
          .toList();

      final filtered = rdvs.where((rdv) {
        final startWindow = rdv.date.subtract(const Duration(hours: 24));
        final endWindow = rdv.date.add(const Duration(hours: 1));
        return now.isAfter(startWindow) && now.isBefore(endWindow);
      }).toList();

      if (mounted && (filtered.length != upcomingRdvs.length)) {
        setState(() => upcomingRdvs = filtered);
      }
    } catch (e) {
      print('Erreur RDV: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _waitForUser();
      _checkUpcomingRdvs();
      _rdvTimer = Timer.periodic(const Duration(minutes: 1), (_) => _checkUpcomingRdvs());
    });
  }

  @override
  void dispose() {
    _rdvTimer?.cancel();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Atelier de nettoyage',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.person_sharp),
                tooltip: 'Profil',
                onPressed: () => Navigator.pushNamed(context, '/profileInstructor'),
              ),
              if (upcomingRdvs.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: () => authController.signOut(context),
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      floatingActionButton: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('toDoList').where('checked', isEqualTo: false).snapshots(),
      builder: (context, snapshot) {
        bool hasNotes = false;
        if (snapshot.hasData) { 
          hasNotes = snapshot.data!.docs.any((doc) {
            final data = doc.data()! as Map<String, dynamic>;
            return (data['note'] ?? '').toString().trim().isNotEmpty;
          });
        }

          return Stack(
            clipBehavior: Clip.none,
            children: [
              FloatingActionButton(
                heroTag: null,
                onPressed: () => stubController.onFabPressed(context),
                tooltip: 'Nouveau planning',
                backgroundColor: Colors.indigo,
                child: const Icon(Icons.edit),
              ),

              // Badge animé
              Positioned(
                right: -2,
                top: -2,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: hasNotes ? 1.0 : 0.0,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 300),
                    scale: hasNotes ? 1.0 : 0.0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          children: List.generate(_tabs.length, (index) {
            final tab = _tabs[index];
            return Expanded(
              child: BuildTabItemWidget(
                icon: tab['icon'] as IconData,
                isSelected: _selectedIndex == index,
                onTap: () => _onItemTapped(index),
              ),
            );
          }),
        ),
      ),
    );
  }
}
