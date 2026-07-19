import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // NOTE: Ganti URL dan Anon Key dengan konfigurasi proyek Supabase Anda.
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
          brightness: Brightness.light,
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
              child: CircularProgressIndicator(),
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
  final _supabase = Supabase.instance.client;
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
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('profiles')
          .select('nama_lengkap, role')
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          _role = data['role'] as String?;
          _nama = data['nama_lengkap'] as String?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
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
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Gagal memuat profil pengguna:',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    _fetchUserProfile();
                  },
                  child: const Text('Coba Lagi'),
                ),
                TextButton(
                  onPressed: () => _supabase.auth.signOut(),
                  child: const Text('Log Out'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Arahkan dashboard berdasarkan role
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

// =========================================================================
// SCREEN PLACEHOLDERS (Login & Dashboards)
// =========================================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      await _supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login Gagal: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.maps_home_work_rounded, size: 80, color: Color(0xFF0F172A)),
              const SizedBox(height: 24),
              Text(
                'Sistem Terpadu RT/RW',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                'Silakan login untuk mengakses layanan warga',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: Colors.grey[600]),
              ),
              const SizedBox(height: 36),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminRWDashboard extends StatelessWidget {
  final String nama;
  const AdminRWDashboard({super.key, required this.nama});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Admin RW'),
        actions: [
          IconButton(
            onPressed: () => Supabase.instance.client.auth.signOut(),
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: Center(
        child: Text('Selamat Datang, $nama!\nAnda memiliki hak akses Admin RW (Super Admin).'),
      ),
    );
  }
}

class AdminRTDashboard extends StatelessWidget {
  final String nama;
  const AdminRTDashboard({super.key, required this.nama});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Admin RT'),
        actions: [
          IconButton(
            onPressed: () => Supabase.instance.client.auth.signOut(),
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: Center(
        child: Text('Selamat Datang, $nama!\nAnda memiliki hak akses Admin RT.'),
      ),
    );
  }
}

class WargaDashboard extends StatelessWidget {
  final String nama;
  const WargaDashboard({super.key, required this.nama});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Warga'),
        actions: [
          IconButton(
            onPressed: () => Supabase.instance.client.auth.signOut(),
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: Center(
        child: Text('Selamat Datang, $nama!\nAnda login sebagai Warga.'),
      ),
    );
  }
}
