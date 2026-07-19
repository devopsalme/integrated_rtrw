import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/supabase_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/admin_rt_dashboard.dart';
import 'screens/dashboard/admin_rw_dashboard.dart';
import 'screens/dashboard/warga_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // NOTE: Silakan ganti URL dan Anon Key dengan kredensial proyek Supabase Anda.
  await Supabase.initialize(
    url: 'https://your-project-id.supabase.co',
    anonKey: 'your-anon-key',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistem Informasi Terpadu RW & RT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F172A), // Slate 900
          primary: const Color(0xFF0F172A),
          secondary: const Color(0xFF0284C7), // Sky 600
          brightness: Brightness.dark, // Set dark mode as default for rich aesthetics
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.outfitTextTheme(Theme.of(context).textTheme),
      ),
      home: const AuthGate(),
    );
  }
}

/// Gerbang Autentikasi untuk memeriksa session aktif Supabase
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
            ),
          );
        }

        final session = snapshot.data?.session;
        if (session != null) {
          return const DashboardGate();
        }

        return const LoginScreen();
      }
    );
  }
}

/// Gerbang Dashboard untuk memeriksa role pengguna dan mengarahkan ke dashboard yang sesuai
class DashboardGate extends StatefulWidget {
  const DashboardGate({super.key});

  @override
  State<DashboardGate> createState() => _DashboardGateState();
}

class _DashboardGateState extends State<DashboardGate> {
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  String? _role;
  String? _nama;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    try {
      final data = await _supabaseService.getCurrentProfile();

      if (mounted) {
        if (data != null) {
          setState(() {
            _role = data['role'] as String?;
            _nama = data['nama_lengkap'] as String?;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Profil warga tidak ditemukan. Hubungi Admin RT.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat profil: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(
                  'Terjadi Kesalahan',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.slate),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    _fetchUserProfile();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Coba Lagi'),
                ),
                TextButton(
                  onPressed: () => _supabaseService.signOut(),
                  child: const Text('Log Out', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Arahkan dashboard berdasarkan role hasil query
    switch (_role) {
      case 'admin_rw':
        return AdminRWDashboard(nama: _nama ?? 'Admin RW');
      case 'admin_rt':
        return AdminRTDashboard(nama: _nama ?? 'Admin RT');
      case 'warga':
      default:
        return WargaDashboard(nama: _nama ?? 'Warga');
    }
  }
}
