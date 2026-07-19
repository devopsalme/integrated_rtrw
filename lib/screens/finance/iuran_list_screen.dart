import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../core/supabase_service.dart';

class IuranListScreen extends StatefulWidget {
  final String householdId;
  const IuranListScreen({super.key, required this.householdId});

  @override
  State<IuranListScreen> createState() => _IuranListScreenState();
}

class _IuranListScreenState extends State<IuranListScreen> {
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _iuranList = [];

  final _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadIuranData();
  }

  Future<void> _loadIuranData() async {
    try {
      final list = await _supabaseService.getIuranList(widget.householdId);
      if (mounted) {
        setState(() {
          _iuranList = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat iuran: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleUploadBukti(String iuranId) async {
    // 1. Pilih File Bukti Bayar
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final fileBytes = file.bytes;
    final fileName = file.name;

    // Jika bytes kosong (biasanya di platform tertentu, fallback baca jalur)
    if (fileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membaca berkas. Silakan coba lagi.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _supabaseService.uploadBuktiBayar(
        iuranId: iuranId,
        fileName: fileName,
        fileBytes: fileBytes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bukti transfer berhasil diunggah! Menunggu konfirmasi Admin RT.', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadIuranData(); // Reload list iuran
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengunggah bukti: $e'), backgroundColor: Colors.red),
        );
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Tagihan Iuran Keluarga',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _isLoading
          ? const Center(child: SpinKitFadingCircle(color: Color(0xFF38BDF8), size: 50))
          : RefreshIndicator(
              onRefresh: _loadIuranData,
              color: const Color(0xFF38BDF8),
              child: _iuranList.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      itemCount: _iuranList.length,
                      itemBuilder: (context, index) {
                        final iuran = _iuranList[index];
                        return _buildIuranCard(iuran);
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.receipt_long_outlined, size: 72, color: Color(0xFF64748B)),
              const SizedBox(height: 16),
              Text(
                'Tidak Ada Tagihan',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Keluarga Anda tidak memiliki daftar iuran aktif saat ini.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIuranCard(Map<String, dynamic> iuran) {
    final status = iuran['status'] as String;
    final nominal = (iuran['nominal'] as num).toDouble();
    final tipe = iuran['tipe'] as String;
    final jatuhTempo = DateTime.parse(iuran['jatuh_tempo'] as String);
    final isLunas = status == 'lunas';
    final hasUploadedProof = iuran['bukti_bayar_url'] != null;

    final dateStr = DateFormat('dd MMM yyyy').format(jatuhTempo);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLunas ? const Color(0xFF10B981).withOpacity(0.2) : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header iuran card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isLunas ? const Color(0xFF10B981).withOpacity(0.15) : Colors.orangeAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isLunas ? 'LUNAS' : (hasUploadedProof ? 'PROSES VERIFIKASI' : 'BELUM BAYAR'),
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isLunas ? const Color(0xFF10B981) : Colors.orangeAccent,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tipe.toUpperCase(),
                  style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Nama Iuran
          Text(
            iuran['nama_iuran'] ?? '',
            style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Jatuh Tempo: $dateStr',
            style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),

          // Nominal & Upload Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nominal Tagihan',
                    style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8)),
                  ),
                  Text(
                    _currencyFormatter.format(nominal),
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              if (!isLunas)
                ElevatedButton.icon(
                  onPressed: () => _handleUploadBukti(iuran['id']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasUploadedProof ? const Color(0xFF1E293B) : const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    side: hasUploadedProof ? BorderSide(color: Colors.white.withOpacity(0.1)) : null,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Icon(hasUploadedProof ? Icons.replay_rounded : Icons.upload_file_rounded, size: 18),
                  label: Text(
                    hasUploadedProof ? 'Upload Ulang' : 'Bayar Sekarang',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
                  onPressed: () {
                    // Tampilkan bukti bayar url jika di klik
                    if (iuran['bukti_bayar_url'] != null) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFF1E293B),
                          title: Text('Bukti Pembayaran', style: GoogleFonts.outfit(color: Colors.white)),
                          content: Image.network(iuran['bukti_bayar_url']),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Tutup', style: GoogleFonts.outfit(color: Colors.white)),
                            )
                          ],
                        ),
                      );
                    }
                  },
                )
            ],
          ),
        ],
      ),
    );
  }
}
