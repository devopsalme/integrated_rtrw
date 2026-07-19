import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/supabase_service.dart';

class PanicAlertScreen extends StatefulWidget {
  final String rtId;
  final String userRole;
  const PanicAlertScreen({super.key, required this.rtId, required this.userRole});

  @override
  State<PanicAlertScreen> createState() => _PanicAlertScreenState();
}

class _PanicAlertScreenState extends State<PanicAlertScreen> {
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _allAlerts = [];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    try {
      final list = await _supabaseService.getActivePanicAlerts(widget.rtId);
      if (mounted) {
        setState(() {
          _allAlerts = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat alarm darurat: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleResolve(String alertId) async {
    setState(() => _isLoading = true);
    try {
      await _supabaseService.resolvePanicAlert(alertId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status darurat berhasil dinonaktifkan / diselesaikan.', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        _loadAlerts();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengubah status: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _callCitizen(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat melakukan panggilan telepon.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeAlerts = _allAlerts.where((a) => a['status'] == 'active').toList();
    final resolvedAlerts = _allAlerts.where((a) => a['status'] == 'resolved').toList();

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
          'Pusat Darurat RT',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _isLoading
          ? const Center(child: SpinKitFadingCircle(color: Color(0xFF38BDF8), size: 50))
          : RefreshIndicator(
              onRefresh: _loadAlerts,
              color: const Color(0xFF38BDF8),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Darurat Aktif Section
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: activeAlerts.isNotEmpty ? Colors.red : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'DARURAT AKTIF (${activeAlerts.length})',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: activeAlerts.isNotEmpty ? Colors.redAccent : Colors.grey,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (activeAlerts.isEmpty)
                      _buildNoActiveAlertsCard()
                    else
                      ...activeAlerts.map((alert) => _buildAlertCard(alert, isActive: true)),

                    const SizedBox(height: 32),

                    // Riwayat Teratasi Section
                    Text(
                      'RIWAYAT TERATASI (${resolvedAlerts.length})',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (resolvedAlerts.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                          child: Text(
                            'Belum ada riwayat alarm darurat.',
                            style: GoogleFonts.outfit(color: const Color(0xFF64748B)),
                          ),
                        ),
                      )
                    else
                      ...resolvedAlerts.map((alert) => _buildAlertCard(alert, isActive: false)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildNoActiveAlertsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          const Icon(Icons.shield_outlined, size: 56, color: Color(0xFF10B981)),
          const SizedBox(height: 12),
          Text(
            'Kondisi Lingkungan Aman',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Tidak ada panggilan darurat aktif di RT Anda saat ini.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert, {required bool isActive}) {
    final creator = alert['creator'] as Map?;
    final nama = creator != null ? creator['nama_lengkap'] as String? ?? 'Warga' : 'Warga';
    final phone = creator != null ? creator['no_hp'] as String? ?? '' : '';

    final createdDate = DateTime.parse(alert['created_at'] as String);
    final timeStr = DateFormat('HH:mm:ss • dd MMMM yyyy').format(createdDate);

    final isAdminRT = widget.userRole == 'admin_rt';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? Colors.redAccent.withOpacity(0.4) : Colors.white.withOpacity(0.05),
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isActive ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                    color: isActive ? Colors.redAccent : const Color(0xFF10B981),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isActive ? 'DARURAT SOS!' : 'SELESAI / TERATASI',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.redAccent : const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              Text(
                timeStr,
                style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text(
            nama,
            style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Membutuhkan bantuan segera di lingkungan RT.',
            style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFFCBD5E1)),
          ),
          const SizedBox(height: 18),

          if (isActive) ...[
            const Divider(color: Colors.white10),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (phone.isNotEmpty) ...[
                  OutlinedButton.icon(
                    onPressed: () => _callCitizen(phone),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.1)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    icon: const Icon(Icons.phone, size: 16),
                    label: Text('Hubungi', style: GoogleFonts.outfit(fontSize: 13)),
                  ),
                  const SizedBox(width: 12),
                ],
                if (isAdminRT)
                  ElevatedButton.icon(
                    onPressed: () => _handleResolve(alert['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    icon: const Icon(Icons.done_all, size: 16),
                    label: Text(
                      'Selesaikan',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
              ],
            )
          ]
        ],
      ),
    );
  }
}
