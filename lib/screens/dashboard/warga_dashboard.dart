import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../core/supabase_service.dart';
import '../household/household_management_screen.dart';

class WargaDashboard extends StatefulWidget {
  final String nama;
  const WargaDashboard({super.key, required this.nama});

  @override
  State<WargaDashboard> createState() => _WargaDashboardState();
}

class _WargaDashboardState extends State<WargaDashboard> {
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _activeSatpam = [];
  bool _isPanicLoading = false;

  @override
  void initState() {
    super.initState();
    _loadWargaData();
  }

  Future<void> _loadWargaData() async {
    try {
      final profile = await _supabaseService.getCurrentProfile();
      if (profile == null) return;

      final rtId = profile['rt_id'] as String;
      final religion = profile['agama'] as String;
      final client = _supabaseService.client;

      // 1. Ambil pengumuman yang sesuai dengan RT & Agama warga
      // rt_id is null (tingkat RW) atau rt_id warga
      // target_agama is null (umum) atau target_agama warga
      final annRes = await client
          .from('pengumuman')
          .select('*, sender:sender_id(nama_lengkap)')
          .or('rt_id.is.null,rt_id.eq.$rtId')
          .or('target_agama.is.null,target_agama.eq.$religion')
          .order('created_at', ascending: false)
          .limit(5);

      // 2. Ambil Satpam yang sedang piket di RT ini
      final satpamRes = await client
          .from('satpam')
          .select('*')
          .eq('rt_id', rtId)
          .eq('is_piket', true);

      if (mounted) {
        setState(() {
          _profile = profile;
          _announcements = List<Map<String, dynamic>>.from(annRes);
          _activeSatpam = List<Map<String, dynamic>>.from(satpamRes);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _triggerPanicButton() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          'TRIGGER PANIC BUTTON?',
          style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Tindakan ini akan mengirim notifikasi darurat langsung ke Admin RT dan petugas satpam yang sedang berjaga. Gunakan hanya untuk keadaan darurat!',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: GoogleFonts.outfit(color: Colors.slate[400])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text('YA, DARURAT!', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isPanicLoading = true);

    try {
      final user = _supabaseService.currentUser;
      final rtId = _profile?['rt_id'] as String?;
      if (user == null || rtId == null) return;

      await _supabaseService.client.from('panic_alerts').insert({
        'profile_id': user.id,
        'rt_id': rtId,
        'status': 'active',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning, color: Colors.white),
                const SizedBox(width: 8),
                Text('Sinyal Darurat Terkirim! Bantuan sedang diarahkan.', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              ],
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim sinyal darurat: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPanicLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rtInfo = _profile?['rt'] as Map?;
    final rwNum = rtInfo != null ? (rtInfo['rw'] as Map?)?['nomor_rw'] ?? '' : '';
    final rtNum = rtInfo != null ? rtInfo['nomor_rt'] ?? '' : '';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard Warga',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
            Text(
              _profile != null ? 'RT $rtNum / RW $rwNum' : 'Loading...',
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
              onRefresh: _loadWargaData,
              color: const Color(0xFF38BDF8),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome & Profile Summary Card
                    _buildProfileCard(rtNum, rwNum),
                    const SizedBox(height: 28),

                    // Panic Button Section (Glow effect red button)
                    _buildPanicButtonSection(),
                    const SizedBox(height: 28),

                    // Grid Quick Actions
                    Text(
                      'Layanan Digital RT/RW',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    _buildQuickActionsGrid(),
                    const SizedBox(height: 28),

                    // Satpam On Duty Status
                    Text(
                      'Live Status Satpam Piket',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    _buildSatpamStatusCard(),
                    const SizedBox(height: 28),

                    // Targeted Broadcast / Announcements
                    Row(
                      mainAxisAlignment: MainAxisAlignment.between,
                      children: [
                        Text(
                          'Pengumuman RT & RW',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          'Terbaru',
                          style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF38BDF8)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildAnnouncementsList(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileCard(dynamic rtNum, dynamic rwNum) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF0284C7).withOpacity(0.15),
            child: const Icon(Icons.account_circle_outlined, size: 40, color: Color(0xFF38BDF8)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.nama,
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'RT $rtNum / RW $rwNum • Status: ${_profile?['status_hunian'] ?? ''}',
                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.slate[400]),
                ),
                Text(
                  'Agama: ${_profile?['agama'] ?? ''}',
                  style: GoogleFonts.outfit(fontSize: 11, color: Colors.slate[400]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanicButtonSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tombol Darurat (Panic Button)',
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.redAccent),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tekan jika membutuhkan bantuan darurat dari satpam & warga terdekat.',
                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.slate[400]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          InkWell(
            onTap: _isPanicLoading ? null : _triggerPanicButton,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withOpacity(0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: _isPanicLoading
                  ? const SpinKitDoubleBounce(color: Colors.white, size: 30)
                  : const Icon(Icons.notifications_active, color: Colors.white, size: 32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.95,
      children: [
        _buildActionCard(
          icon: Icons.family_restroom_rounded,
          label: 'Keluarga',
          color: const Color(0xFF38BDF8),
          onTap: () {
            final householdId = _profile?['household_id'] as String?;
            if (householdId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HouseholdManagementScreen(
                    householdId: householdId,
                    rtId: _profile?['rt_id'] as String,
                  ),
                ),
              ).then((_) => _loadWargaData());
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Rumah tangga Anda belum terdaftar.')),
              );
            }
          },
        ),
        _buildActionCard(
          icon: Icons.receipt_long_outlined,
          label: 'Bayar Iuran',
          color: const Color(0xFF34D399),
          onTap: () {},
        ),
        _buildActionCard(
          icon: Icons.assignment_ind_outlined,
          label: 'Lapor Tamu',
          color: const Color(0xFFFBBF24),
          onTap: () {},
        ),
        _buildActionCard(
          icon: Icons.delete_sweep_outlined,
          label: 'Jadwal Sampah',
          color: const Color(0xFFF472B6),
          onTap: () {},
        ),
        _buildActionCard(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Kas RT',
          color: const Color(0xFFA78BFA),
          onTap: () {},
        ),
        _buildActionCard(
          icon: Icons.help_outline_rounded,
          label: 'Bantuan',
          color: Colors.slate,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSatpamStatusCard() {
    if (_activeSatpam.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.shield_moon_outlined, color: Colors.slate, size: 28),
            const SizedBox(width: 12),
            Text(
              'Tidak ada satpam terdaftar yang piket saat ini.',
              style: GoogleFonts.outfit(color: Colors.slate, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _activeSatpam.map((satpam) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF34D399).withOpacity(0.1),
                child: const Icon(Icons.local_police_outlined, color: Color(0xFF34D399)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      satpam['nama'] ?? 'Petugas Keamanan',
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Piket Shift: ${satpam['shift_mulai'] ?? ''} - ${satpam['shift_selesai'] ?? ''}',
                      style: GoogleFonts.outfit(fontSize: 11, color: Colors.slate[400]),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.phone_rounded, color: Color(0xFF34D399)),
                onPressed: () {
                  // Call satpam phone
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAnnouncementsList() {
    if (_announcements.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Tidak ada pengumuman untuk Anda.',
            style: GoogleFonts.outfit(color: Colors.slate, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      children: _announcements.map((ann) {
        final isRwLevel = ann['rt_id'] == null;
        final senderName = ann['sender'] != null ? (ann['sender'] as Map)['nama_lengkap'] : 'Admin';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.between,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isRwLevel ? const Color(0xFF1E3A8A) : const Color(0xFF0F766E),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isRwLevel ? 'Info RW' : 'Info RT',
                      style: GoogleFonts.outfit(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    'Oleh: $senderName',
                    style: GoogleFonts.outfit(fontSize: 11, color: Colors.slate[400]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                ann['judul'] ?? '',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                ann['isi'] ?? '',
                style: GoogleFonts.outfit(fontSize: 13, color: Colors.slate[300]),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
