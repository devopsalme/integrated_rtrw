import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';
import '../../core/supabase_service.dart';

class GuestReportScreen extends StatefulWidget {
  final String rtId;
  const GuestReportScreen({super.key, required this.rtId});

  @override
  State<GuestReportScreen> createState() => _GuestReportScreenState();
}

class _GuestReportScreenState extends State<GuestReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabaseService = SupabaseService();

  // Controllers
  final _namaController = TextEditingController();
  final _nikController = TextEditingController();
  final _hubunganController = TextEditingController();
  final _keteranganController = TextEditingController();

  DateTime _tglDatang = DateTime.now();
  DateTime _tglPulang = DateTime.now().add(const Duration(days: 1));

  bool _isSubmitting = false;
  bool _isLoadingHistory = true;
  List<Map<String, dynamic>> _myReports = [];

  @override
  void initState() {
    super.initState();
    _loadMyReports();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _nikController.dispose();
    _hubunganController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  Future<void> _loadMyReports() async {
    try {
      final list = await _supabaseService.getGuestReports(widget.rtId);
      final myUid = _supabaseService.currentUser?.id;
      
      // Filter laporan milik diri sendiri saja untuk Warga
      final filtered = list.where((r) => r['created_by'] == myUid).toList();

      if (mounted) {
        setState(() {
          _myReports = filtered;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat riwayat lapor tamu: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await _supabaseService.reportGuest(
        nama: _namaController.text.trim(),
        nik: _nikController.text.trim(),
        hubungan: _hubunganController.text.trim(),
        tglDatang: _tglDatang.toIso8601String().substring(0, 10),
        tglPulang: _tglPulang.toIso8601String().substring(0, 10),
        keterangan: _keteranganController.text.trim(),
        rtId: widget.rtId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Laporan tamu berhasil dikirim ke RT!', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Reset form
        _namaController.clear();
        _nikController.clear();
        _hubunganController.clear();
        _keteranganController.clear();
        
        setState(() {
          _tglDatang = DateTime.now();
          _tglPulang = DateTime.now().add(const Duration(days: 1));
          _isLoadingHistory = true;
        });
        
        _loadMyReports(); // Reload history
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim laporan: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            'Lapor Tamu Wajib (24 Jam)',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          bottom: TabBar(
            indicatorColor: const Color(0xFF38BDF8),
            labelColor: const Color(0xFF38BDF8),
            unselectedLabelColor: Colors.slate[400],
            tabs: [
              Tab(child: Text('Formulir Lapor', style: GoogleFonts.outfit(fontWeight: FontWeight.bold))),
              Tab(child: Text('Riwayat Laporan', style: GoogleFonts.outfit(fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildFormTab(),
            _buildHistoryTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildFormTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildLabel('Nama Lengkap Tamu'),
            TextFormField(
              controller: _namaController,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration('Nama lengkap sesuai KTP...', Icons.person_outline),
              validator: (v) => v == null || v.isEmpty ? 'Nama tamu wajib diisi' : null,
            ),
            const SizedBox(height: 18),

            _buildLabel('NIK / No. KTP Tamu'),
            TextFormField(
              controller: _nikController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration('16 digit nomor induk kependudukan...', Icons.badge_outlined),
              validator: (v) {
                if (v == null || v.isEmpty) return 'NIK wajib diisi';
                if (v.length < 16) return 'NIK harus terdiri dari 16 digit';
                return null;
              },
            ),
            const SizedBox(height: 18),

            _buildLabel('Hubungan dengan Tuan Rumah'),
            TextFormField(
              controller: _hubunganController,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration('Contoh: Orang tua, Saudara, Teman...', Icons.people_alt_outlined),
              validator: (v) => v == null || v.isEmpty ? 'Hubungan kekeluargaan wajib diisi' : null,
            ),
            const SizedBox(height: 18),

            // Date Pickers
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Tanggal Datang'),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _tglDatang,
                            firstDate: DateTime.now().subtract(const Duration(days: 7)),
                            lastDate: DateTime.now().add(const Duration(days: 90)),
                          );
                          if (picked != null) {
                            setState(() => _tglDatang = picked);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withOpacity(0.1)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.date_range, size: 16),
                        label: Text(DateFormat('dd MMM yyyy').format(_tglDatang)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Tanggal Pulang (Estimasi)'),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _tglPulang,
                            firstDate: _tglDatang,
                            lastDate: DateTime.now().add(const Duration(days: 180)),
                          );
                          if (picked != null) {
                            setState(() => _tglPulang = picked);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withOpacity(0.1)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.date_range, size: 16),
                        label: Text(DateFormat('dd MMM yyyy').format(_tglPulang)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            _buildLabel('Keterangan / Keperluan Menginap'),
            TextFormField(
              controller: _keteranganController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration('Contoh: Menginap dalam rangka silaturahmi lebaran...', Icons.notes_outlined),
              validator: (v) => v == null || v.isEmpty ? 'Keterangan/keperluan kunjungan wajib diisi' : null,
            ),
            const SizedBox(height: 36),

            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const SpinKitThreeBounce(color: Colors.white, size: 24)
                  : Text('Kirim Laporan Tamu', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_isLoadingHistory) {
      return const Center(child: SpinKitFadingCircle(color: Color(0xFF38BDF8), size: 50));
    }

    if (_myReports.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.assignment_turned_in_outlined, size: 64, color: Color(0xFF64748B)),
              const SizedBox(height: 16),
              Text(
                'Belum Ada Laporan',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                'Anda belum pernah membuat laporan tamu masuk 24 jam.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _myReports.length,
      itemBuilder: (context, index) {
        final r = _myReports[index];
        final status = r['status'] as String;
        final isApproved = status == 'approved';
        final isRejected = status == 'rejected';

        final tglDatang = DateTime.parse(r['tanggal_datang'] as String);
        final tglPulang = DateTime.parse(r['tanggal_pulang'] as String);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                    '${DateFormat('dd MMM').format(tglDatang)} - ${DateFormat('dd MMM yyyy').format(tglPulang)}',
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
                'Hubungan: ${r['hubungan']} • NIK: ${r['nik_tamu']}',
                style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFFCBD5E1)),
              ),
              const SizedBox(height: 8),
              Text(
                'Keterangan: ${r['keterangan']}',
                style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hintText, IconData icon) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF64748B)),
      prefixIcon: Icon(icon, color: const Color(0xFF38BDF8)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
      ),
    );
  }
}
