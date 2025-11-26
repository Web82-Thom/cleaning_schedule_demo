import 'dart:async';
import 'package:cleaning_schedule_demo/controllers/auth_controller.dart';
import 'package:cleaning_schedule_demo/controllers/stub_controller.dart';
import 'package:cleaning_schedule_demo/models/rdv_model.dart';
import 'package:cleaning_schedule_demo/screens/stubPages/consumable_page.dart';
import 'package:cleaning_schedule_demo/screens/stubPages/view_tasks_no_weekly_page.dart';
import 'package:cleaning_schedule_demo/screens/stubPages/planning_page.dart';
import 'package:cleaning_schedule_demo/screens/stubPages/rdv_calendar_page.dart';
import 'package:cleaning_schedule_demo/widgets/build_tab_item_widget.dart';
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

  Drawer _buildDrawer(BuildContext context) {
    final user = widget.auth.currentUser;

    return Drawer(
      child: Column(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: user != null
                ? FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots()
                : const Stream.empty(),
            builder: (context, snapshot) {
              String fullName = 'Moniteur';
              String email = user?.email ?? '';

              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                final prenom = (data['prenom'] ?? '').toString().trim();
                final nom = (data['nom'] ?? '').toString().trim();
                final composed = '$prenom $nom'.trim();
                if (composed.isNotEmpty) {
                  fullName = composed;
                }
              }

              return UserAccountsDrawerHeader(
                accountName: Text(
                  fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                accountEmail: Text(
                  email,
                  style: const TextStyle(fontSize: 12),
                ),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.blue.shade200,
                  child: const Icon(
                    Icons.person,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),

          // Onglets principaux (les mêmes que le bottom bar)
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Planning'),
            selected: _selectedIndex == 0,
            onTap: () {
              Navigator.pop(context);
              _onItemTapped(0);
            },
          ),
          ListTile(
            leading: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.event),
                if (upcomingRdvs.isNotEmpty)
                  const Positioned(
                    right: -1,
                    top: -1,
                    child: CircleAvatar(
                      radius: 4,
                      backgroundColor: Colors.red,
                    ),
                  ),
              ],
            ),
            title: const Text('RDV'),
            selected: _selectedIndex == 1,
            onTap: () {
              Navigator.pop(context);
              _onItemTapped(1);
            },
          ),
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Prestations'),
            selected: _selectedIndex == 2,
            onTap: () {
              Navigator.pop(context);
              _onItemTapped(2);
            },
          ),
          ListTile(
            leading: const Icon(Icons.local_drink),
            title: const Text('Consommation'),
            selected: _selectedIndex == 3,
            onTap: () {
              Navigator.pop(context);
              _onItemTapped(3);
            },
          ),

          const Divider(),

          // Profil
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profil'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/profileInstructor');
            },
          ),
          // Documentation PDF
          ListTile(
            leading: const Icon(Icons.document_scanner_outlined),
            title: const Text('Á propos'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/about');
            },
          ),
          // A Propos
          ListTile(
            leading: const Icon(Icons.panorama_photosphere_select_rounded),
            title: const Text('Documentations PDF'),
            onTap: () {
              // Navigator.pop(context);
              Navigator.pushNamed(context, '/docAppPdf');
            },
          ),
          const Spacer(),
          // Déconnexion
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Déconnexion',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () {
              Navigator.pop(context);
              authController.signOut(context);
            },
          ),
        ],
      ),
    );
 
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white ,
        title: const Text(
          'Atelier de nettoyage',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      drawer: _buildDrawer(context),
      body: _pages[_selectedIndex],
      floatingActionButton: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('toDoList')
            .where('checked', isEqualTo: false)
            .snapshots(),
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
        color: Colors.indigo,
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
  bool get _loading => false; // ⚠️ si tu avais déjà une variable _loading, garde-la.
}
