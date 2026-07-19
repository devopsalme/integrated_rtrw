import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/supabase_service.dart';

class AdminRWDashboard extends StatefulWidget {
  final String nama;
  const AdminRWDashboard({super.key, required this.nama});

  @override
  State<AdminRWDashboard> createState() => _AdminRWDashboardState();
}

class _AdminRWDashboardState extends State<AdminRWDashboard> {
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  int _totalRT = 0;
  int _totalKK = 0;
  int _totalWarga = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final client = _supabaseService.client;
      
      // Mengambil total RT
      final rtRes = await client.from('rt').select('id', const FetchOptions(count: CountOption.exact));
      // Mengambil total KK
      final kkRes = await client.from('households').select('id', const FetchOptions(count: CountOption.exact));
      // Mengambil total Warga
      final wargaRes = await client.from('profiles').select('id', const FetchOptions(count: CountOption.exact));

      if (mounted) {
        setState(() {
          _totalRT = rtRes.count ?? 0;
          _totalKK = kkRes.count ?? 0;
          _totalWarga = wargaRes.count ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B), // Slate 800
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard Admin RW',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
            Text(
              'Super Admin Wilayah',
              style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF38BDF8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: () => _supabaseService.signOut(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : RefreshIndicator(
              onRefresh: _loadStats,
              color: const Color(0xFF38BDF8),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFF1E293B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: const Color(0xFF38BDF8).withOpacity(0.2),
                            child: const Icon(Icons.person, size: 32, color: Color(0xFF38BDF8)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Halo, ${widget.nama}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Selamat datang kembali di panel kendali wilayah RW.',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: Colors.slate[300],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Stats Grid
                    Text(
                      'Statistik Wilayah',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildStatCard(
                          title: 'Total RT',
                          value: _totalRT.toString(),
                          icon: Icons.holiday_village_outlined,
                          color: const Color(0xFF38BDF8),
                        ),
                        _buildStatCard(
                          title: 'Total Rumah (KK)',
                          value: _totalKK.toString(),
                          icon: Icons.home_outlined,
                          color: const Color(0xFF34D399), // Emerald 400
                        ),
                        _buildStatCard(
                          title: 'Total Warga',
                          value: _totalWarga.toString(),
                          icon: Icons.people_outline_rounded,
                          color: const Color(0xFFFBBF24), // Amber 400
                        ),
                        _buildStatCard(
                          title: 'Kas RW',
                          value: 'Rp 4.5M',
                          icon: Icons.account_balance_wallet_outlined,
                          color: const Color(0xFFF472B6), // Pink 400
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Quick Actions
                    Text(
                      'Menu Cepat RW',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    _buildMenuRow(
                      icon: Icons.campaign_rounded,
                      title: 'Buat Pengumuman RW',
                      subtitle: 'Broadcast ke seluruh RT / Agama tertentu',
                      color: const Color(0xFF38BDF8),
                    ),
                    _buildMenuRow(
                      icon: Icons.settings_accessibility_rounded,
                      title: 'Kelola Data Ketua RT',
                      subtitle: 'Atur nomor kontak & akun admin RT',
                      color: const Color(0xFF34D399),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.slate[400],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.slate[400]),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.slate[500]),
        ],
      ),
    );
  }
}
