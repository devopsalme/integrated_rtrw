import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';
import '../../core/supabase_service.dart';

class GuestManageScreen extends StatefulWidget {
  final String rtId;
  const GuestManageScreen({super.key, required this.rtId});

  @override
  State<GuestManageScreen> createState() => _GuestManageScreenState();
}

class _GuestManageScreenState extends State<GuestManageScreen> {
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _reports = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      final list = await _supabaseService.getGuestReports(widget.rtId);
      if (mounted) {
        setState(() {
          _reports = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data tamu: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleStatusUpdate(String reportId, String newStatus) async {
    setState(() => _isLoading = true);

    try {
      await _supabaseService.updateGuestReportStatus(
        reportId: reportId,
        status: newStatus,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'approved' ? 'Laporan tamu telah disetujui!' : 'Laporan tamu ditolak.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: newStatus == 'approved' ? const Color(0xFF10B981) : Colors.orangeAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadReports();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui status: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingReports = _reports.where((r) => r['status'] == 'pending').toList();
    final processedReports = _reports.where((r) => r['status'] != 'pending').toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A), // Slate 900
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Kelola Laporan Tamu',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          bottom: TabBar(
            indicatorColor: const Color(0xFF38BDF8),
            labelColor: const Color(0xFF38BDF8),
            unselectedLabelColor: Colors.slate[400],
            tabs: [
              Tab(child: Text('Menunggu (${pendingReports.length})', style: GoogleFonts.outfit(fontWeight: FontWeight.bold))),
              Tab(child: Text('Riwayat (${processedReports.length})', style: GoogleFonts.outfit(fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: SpinKitFadingCircle(color: Color(0xFF38BDF8), size: 50))
            : TabBarView(
                children: [
                  _buildList(pendingReports, isPendingTab: true),
                  _buildList(processedReports, isPendingTab: false),
                ],
              ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> list, {required bool isPendingTab}) {
    if (list.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.assignment_ind_outlined, size: 72, color: Color(0xFF64748B)),
                const SizedBox(height: 16),
                Text(
                  isPendingTab ? 'Tidak Ada Laporan Pending' : 'Belum Ada Riwayat',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  isPendingTab
                      ? 'Seluruh laporan kedatangan tamu di RT Anda telah diproses.'
                      : 'Laporan tamu yang disetujui/ditolak akan tertera di sini.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReports,
      color: const Color(0xFF38BDF8),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final r = list[index];
          final reporter = r['reporter'] != null ? (r['reporter'] as Map)['nama_lengkap'] as String? ?? 'Warga' : 'Warga';
          final status = r['status'] as String;
          final isApproved = status == 'approved';
          final isRejected = status == 'rejected';

          final tglDatang = DateTime.parse(r['tanggal_datang'] as String);
          final tglPulang = DateTime.parse(r['tanggal_pulang'] as String);
          final dateStr = '${DateFormat('dd MMM').format(tglDatang)} - ${DateFormat('dd MMM yyyy').format(tglPulang)}';

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isApproved 
                    ? const Color(0xFF10B981).withOpacity(0.2) 
                    : (isRejected ? Colors.redAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.between,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isApproved 
                            ? const Color(0xFF10B981).withOpacity(0.15) 
                            : (isRejected ? Colors.redAccent.withOpacity(0.15) : Colors.orangeAccent.withOpacity(0.15)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isApproved ? const Color(0xFF10B981) : (isRejected ? Colors.redAccent : Colors.orangeAccent),
                        ),
                      ),
                    ),
                    Text(
                      dateStr,
                      style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Text(
                  r['nama_tamu'] ?? '',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pelapor (Tuan Rumah): $reporter',
                  style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFFCBD5E1), fontWeight: FontWeight.bold),
                ),
                Text(
                  'Hubungan: ${r['hubungan']} • NIK Tamu: ${r['nik_tamu']}',
                  style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFFCBD5E1)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Keterangan: ${r['keterangan']}',
                  style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8)),
                ),

                if (isPendingTab) ...[
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _handleStatusUpdate(r['id'], 'rejected'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        icon: const Icon(Icons.cancel_outlined, size: 16),
                        label: Text('Tolak', style: GoogleFonts.outfit(fontSize: 13)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _handleStatusUpdate(r['id'], 'approved'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: Text('Setujui', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ]
              ],
            ),
          );
        },
      ),
    );
  }
}
