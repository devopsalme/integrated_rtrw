import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../core/supabase_service.dart';

class HouseholdManagementScreen extends StatefulWidget {
  final String householdId;
  final String rtId;
  const HouseholdManagementScreen({
    super.key,
    required this.householdId,
    required this.rtId,
  });

  @override
  State<HouseholdManagementScreen> createState() => _HouseholdManagementScreenState();
}

class _HouseholdManagementScreenState extends State<HouseholdManagementScreen> {
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _members = [];
  bool _isHeadOfHousehold = false;

  @override
  void initState() {
    super.initState();
    _loadHouseholdMembers();
  }

  Future<void> _loadHouseholdMembers() async {
    try {
      final list = await _supabaseService.getHouseholdMembers(widget.householdId);
      
      // Cek apakah user yang login saat ini adalah kepala keluarga
      final currentUser = _supabaseService.currentUser;
      bool isHead = false;
      if (currentUser != null) {
        final currentMember = list.firstWhere(
          (m) => m['id'] == currentUser.id,
          orElse: () => <String, dynamic>{},
        );
        isHead = currentMember['is_head_of_household'] as bool? ?? false;
      }

      if (mounted) {
        setState(() {
          _members = list;
          _isHeadOfHousehold = isHead;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Kode Keluarga berhasil disalin!', style: GoogleFonts.outfit()),
        backgroundColor: Colors.teal,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Manajemen Keluarga',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: SpinKitFadingCircle(color: Color(0xFF38BDF8), size: 50))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Household ID / Kode KK Card
                  _buildHouseholdCodeCard(),
                  const SizedBox(height: 28),

                  // Header List
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Anggota Keluarga Terdaftar',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${_members.length} Orang',
                        style: GoogleFonts.outfit(fontSize: 13, color: Colors.blueGrey[400]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Members List
                  _members.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 32.0),
                            child: Text('Belum ada anggota keluarga.', style: TextStyle(color: Colors.blueGrey)),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _members.length,
                          itemBuilder: (context, index) {
                            final member = _members[index];
                            final isHead = member['is_head_of_household'] as bool? ?? false;
                            final nama = member['nama_lengkap'] ?? '';
                            final nik = member['nik'] ?? '-';
                            final hp = member['no_hp'] ?? '-';

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
                                    radius: 22,
                                    backgroundColor: isHead
                                        ? const Color(0xFF0284C7).withOpacity(0.2)
                                        : Colors.white.withOpacity(0.05),
                                    child: Icon(
                                      isHead ? Icons.star_rounded : Icons.person_outline_rounded,
                                      color: isHead ? const Color(0xFF38BDF8) : Colors.blueGrey[400],
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              nama,
                                              style: GoogleFonts.outfit(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            if (isHead) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF38BDF8).withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'Kepala KK',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: const Color(0xFF38BDF8),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'NIK: $nik',
                                          style: GoogleFonts.outfit(fontSize: 12, color: Colors.blueGrey[400]),
                                        ),
                                        Text(
                                          'No. HP: $hp',
                                          style: GoogleFonts.outfit(fontSize: 12, color: Colors.blueGrey[400]),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildHouseholdCodeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.vpn_key_outlined, color: Color(0xFF38BDF8), size: 24),
              const SizedBox(width: 8),
              Text(
                'KODE KELUARGA (HOUSEHOLD ID)',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF38BDF8),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Gunakan kode unik di bawah ini untuk menghubungkan akun keluarga baru ke dalam satu KK terpadu.',
            style: GoogleFonts.outfit(fontSize: 13, color: Colors.blueGrey[300]),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Text(
                    widget.householdId,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => _copyToClipboard(widget.householdId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Icon(Icons.copy, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Info untuk Kepala Keluarga tentang penambahan sub-akun
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Colors.blueGrey, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cara tambah keluarga: Salin kode di atas, lalu minta anggota keluarga Anda mengunduh aplikasi dan melakukan registrasi dengan memasukkan Kode Keluarga ini pada form pendaftaran.',
                    style: GoogleFonts.outfit(fontSize: 11, color: Colors.blueGrey[400], height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
