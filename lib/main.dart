import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/inventory_screen.dart';
import 'screens/login_screen.dart';
import 'screens/treasury_screen.dart';
import 'screens/members_screen.dart';
import 'screens/events_screen.dart';
import 'screens/cards_screen.dart';
import 'screens/cards_presidenti_screen.dart';
import 'screens/admin_screen.dart';
import 'dialogs/change_password_dialog.dart';
import 'services/profile_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://siazgzcueknbxobbjwnr.supabase.co',
    publishableKey: 'sb_publishable_0ry-H1OtcoOQ1hID234TLQ_dQ2BrliU',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Inventory',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    final initialSession = client.auth.currentSession;

    debugPrint('AuthGate: initialSession = ${initialSession != null}');

    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      initialData: AuthState(
        AuthChangeEvent.initialSession,
        initialSession,
      ),
      builder: (context, snapshot) {
        final session = snapshot.data?.session;
        debugPrint('AuthGate: session = ${session != null}');
        if (session == null) {
          ProfileService().clearCache();
          return const LoginScreen();
        }
        return const MainNavigationScreen();
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  String? _role;
  bool _isLoadingRole = true;

  final _profileService = ProfileService();

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    try {
      final role = await _profileService.getCurrentUserRole();
      debugPrint('Ruolo caricato: $role');
      if (mounted) {
        setState(() {
          _role = role;
          _isLoadingRole = false;
          if (role != 'admin') {
            _selectedIndex = 0;
          }
        });
      }
    } catch (e) {
      debugPrint('Errore caricamento ruolo: $e');
      if (mounted) {
        setState(() {
          _role = 'membro';
          _isLoadingRole = false;
        });
      }
    }
  }

  bool get _isAdmin => _role == 'admin';
  bool get _isPresidente => _role == 'presidente';

  List<Widget> get _screens {
    if (_isAdmin) {
      return [
        const InventoryScreen(),
        const TreasuryScreen(),
        const MembersScreen(),
        const EventsScreen(),
        const CardsScreen(),
        const CardsPresidentiScreen(),
        const AdminScreen(),
      ];
    }
    if (_isPresidente) {
      return [
        const CardsPresidentiScreen(),
      ];
    }
    return [];
  }

  List<String> get _titles {
    if (_isAdmin) {
      return [
        'Inventario Sede',
        'Tesoreria & Cassa',
        'Gestione Soci',
        'Eventi Personalizzati',
        'Schede',
        'Schede Presidenti',
        'Amministrazione',
      ];
    }
    if (_isPresidente) {
      return [
        'Schede Presidenti',
      ];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_role != 'admin' && _role != 'presidente') {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text(
                'Accesso non autorizzato',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Non hai i permessi per utilizzare questa applicazione.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                },
                child: const Text('Esci'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        centerTitle: true,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.deepOrange),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'Smart Inventory',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'Gestionale Sede',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ruolo: ${_role!.toUpperCase()}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (_isAdmin) ...[
              ListTile(
                leading: const Icon(Icons.inventory),
                title: const Text('Inventario'),
                selected: _selectedIndex == 0,
                onTap: () {
                  setState(() => _selectedIndex = 0);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet),
                title: const Text('Tesoreria'),
                selected: _selectedIndex == 1,
                onTap: () {
                  setState(() => _selectedIndex = 1);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('Soci & Quote'),
                selected: _selectedIndex == 2,
                onTap: () {
                  setState(() => _selectedIndex = 2);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.event),
                title: const Text('Eventi'),
                selected: _selectedIndex == 3,
                onTap: () {
                  setState(() => _selectedIndex = 3);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.credit_card),
                title: const Text('Schede'),
                selected: _selectedIndex == 4,
                onTap: () {
                  setState(() => _selectedIndex = 4);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.assignment_ind),
                title: const Text('Schede Presidenti'),
                selected: _selectedIndex == 5,
                onTap: () {
                  setState(() => _selectedIndex = 5);
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: const Text('Amministrazione'),
                selected: _selectedIndex == 6,
                onTap: () {
                  setState(() => _selectedIndex = 6);
                  Navigator.pop(context);
                },
              ),
            ],
            if (_isPresidente) ...[
              ListTile(
                leading: const Icon(Icons.assignment_ind),
                title: const Text('Schede Presidenti'),
                selected: _selectedIndex == 0,
                onTap: () {
                  setState(() => _selectedIndex = 0);
                  Navigator.pop(context);
                },
              ),
            ],
            const Divider(),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Cambia Password'),
              onTap: () {
                Navigator.pop(context);
                showChangePasswordDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Esci'),
              onTap: () async {
                Navigator.pop(context);
                await Supabase.instance.client.auth.signOut();
              },
            ),
          ],
        ),
      ),
      body: _screens.isNotEmpty ? _screens[_selectedIndex] : const SizedBox(),
    );
  }
}
