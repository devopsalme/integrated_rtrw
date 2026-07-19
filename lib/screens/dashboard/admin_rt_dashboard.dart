import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/supabase_service.dart';

class AdminRTDashboard extends StatefulWidget {
  final String nama;
  const AdminRTDashboard({super.key, required this.nama});

  @override
  State<AdminRTDashboard> createState() => _AdminRTDashboardState();
}

class _AdminRTDashboardState extends State<AdminRTDashboard> {
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  String _nomorRT = '';
  int _totalWarga = 0;
  int _totalKK = 0;
  int _pendingTamu = 0;
  int _activePanic = 0;
  List<Map<String, dynamic>> _wargaList = [];

  @override
  void initState() {
    super.initState();
    _loadRTData();
  }

  Future<void> _loadRTData() async {
    try {
      final profile = await _supabaseService.getCurrentProfile();
      if (profile == null) return;

      final rtId = profile['rt_id'] as String;
      final rtInfo = profile['rt'] as Map?;
      final nr = rtInfo != null ? rtInfo['nomor_rt'] as String : '';

      final client = _supabaseService.client;

      // 1. Ambil list warga di RT ini
      final wargaRes = await client
          .from('profiles')
          .select('id, nama_lengkap, no_hp, status_hunian, is_head_of_household')
          .eq('rt_id', rtId)
          .order('nama_lengkap', ascending: true);

      // 2. Hitung statistik
      final kkCount = await client
          .from('households')
          .select('id')
          .eq('rt_id', rtId);

      final tamuCount = await client
          .from('tamu_reports')
          .select('id')
          .eq('rt_id', rtId)
          .eq('status', 'pending');

      final panicCount = await client
          .from('panic_alerts')
          .select('id')
          .eq('rt_id', rtId)
          .eq('status', 'active');

      if (mounted) {
        setState(() {
          _nomorRT = nr;
          _wargaList = List<Map<String, dynamic>>.from(wargaRes);
          _totalWarga = wargaRes.length;
          _totalKK = kkCount.length;
          _pendingTamu = tamuCount.length;
          _activePanic = panicCount.length;
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
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard Admin RT $_nomorRT',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
            Text(
              'Rukun Tetangga $_nomorRT',
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
              onRefresh: _loadRTData,
              color: const Color(0xFF38BDF8),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Alerts banner if there is active panic alert
                    if (_activePanic > 0) ...[
                      _buildPanicBanner(),
                      const SizedBox(height: 16),
                    ],

                    // Welcome Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F766E), Color(0xFF1E293B)], // Teal 700 to Slate 800
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
                            backgroundColor: const Color(0xFF2DD4BF).withOpacity(0.2), // Teal 400
                            child: const Icon(Icons.shield_outlined, size: 32, color: Color(0xFF2DD4BF)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Halo, Pak/Bu ${widget.nama}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Siap melayani warga RT $_nomorRT hari ini.',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: Colors.blueGrey[300],
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
                      'Statistik RT $_nomorRT',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            title: 'Warga',
                            value: _totalWarga.toString(),
                            color: const Color(0xFF38BDF8),
                            icon: Icons.people_outline,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            title: 'Rumah (KK)',
                            value: _totalKK.toString(),
                            color: const Color(0xFF34D399),
                            icon: Icons.home_outlined,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            title: 'Laporan Tamu',
                            value: _pendingTamu.toString(),
                            color: _pendingTamu > 0 ? Colors.orangeAccent : Colors.blueGrey,
                            icon: Icons.assignment_ind_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // List Warga
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Daftar Warga RT $_nomorRT',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          '${_wargaList.length} orang',
                          style: GoogleFonts.outfit(fontSize: 13, color: Colors.blueGrey[400]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _wargaList.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 32.0),
                              child: Text('Belum ada warga terdaftar.', style: TextStyle(color: Colors.blueGrey)),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _wargaList.length,
                            itemBuilder: (context, index) {
                              final warga = _wargaList[index];
                              final hp = warga['no_hp'] ?? '-';
                              final status = warga['status_hunian'] ?? 'Pemilik';
                              final isHead = warga['is_head_of_household'] as bool? ?? false;

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
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: isHead
                                          ? const Color(0xFF0284C7).withOpacity(0.2)
                                          : Colors.white.withOpacity(0.05),
                                      child: Icon(
                                        isHead ? Icons.star_rounded : Icons.person_outline,
                                        color: isHead ? const Color(0xFF0284C7) : Colors.blueGrey[400],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            warga['nama_lengkap'] ?? '',
                                            style: GoogleFonts.outfit(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'HP: $hp • Hunian: $status',
                                            style: GoogleFonts.outfit(fontSize: 12, color: Colors.blueGrey[400]),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isHead)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0284C7).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Kepala KK',
                                          style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF38BDF8), fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPanicBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.15),
        border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ALARM DARURAT AKTIF!',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.redAccent),
                ),
                Text(
                  'Ada $_activePanic warga yang menekan tombol panic button.',
                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.white),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // Action panic alerts
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('CEK', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 11, color: Colors.blueGrey[400]),
          ),
        ],
      ),
    );
  }
}
