import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../core/supabase_service.dart';

class CreateAnnouncementScreen extends StatefulWidget {
  const CreateAnnouncementScreen({super.key});

  @override
  State<CreateAnnouncementScreen> createState() => _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabaseService = SupabaseService();

  // Controllers
  final _judulController = TextEditingController();
  final _isiController = TextEditingController();

  // Selections
  String? _selectedRTId; // Null means "Semua RT" (Only for RW Admin)
  String? _selectedAgama; // Null means "Semua Agama"

  // User Profile States
  bool _isLoadingProfile = true;
  String? _userRole;
  String? _userRtId;
  String? _userRwId;
  List<Map<String, dynamic>> _rtList = [];

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _judulController.dispose();
    _isiController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final profile = await _supabaseService.getCurrentProfile();
      if (profile == null) throw Exception('Profil tidak ditemukan');

      final role = profile['role'] as String;
      final rtId = profile['rt_id'] as String;
      // Ambil rw_id dari join rt
      final rtData = profile['rt'] as Map?;
      final rwId = rtData != null ? profile['rt']['rw_id'] as String? : null;

      List<Map<String, dynamic>> rts = [];
      if (role == 'admin_rw') {
        rts = await _supabaseService.getRTList();
      }

      setState(() {
        _userRole = role;
        _userRtId = rtId;
        _userRwId = rwId;
        _rtList = rts;
        if (role == 'admin_rt') {
          _selectedRTId = rtId; // Admin RT hanya bisa mengirim ke RT sendiri
        }
        _isLoadingProfile = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data: $e'), backgroundColor: Colors.red),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _submitAnnouncement() async {
    if (!_formKey.currentState!.validate()) return;
    if (_userRwId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mendapatkan ID RW Anda.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _supabaseService.createAnnouncement(
        judul: _judulController.text.trim(),
        isi: _isiController.text.trim(),
        rtId: _selectedRTId, // Bisa null untuk RW admin (Semua RT)
        targetAgama: _selectedAgama, // Bisa null untuk Semua Agama
        rwId: _userRwId!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pengumuman berhasil diposting!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true); // Kembali ke dashboard dengan sinyal reload
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memposting pengumuman: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
          'Buat Pengumuman Baru',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _isLoadingProfile
          ? const Center(child: SpinKitFadingCircle(color: Color(0xFF38BDF8), size: 50))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Judul Pengumuman
                    _buildLabel('Judul Pengumuman'),
                    TextFormField(
                      controller: _judulController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _buildInputDecoration('Masukkan judul pengumuman...', Icons.title_rounded),
                      validator: (v) => v == null || v.isEmpty ? 'Judul pengumuman wajib diisi.' : null,
                    ),
                    const SizedBox(height: 18),

                    // Isi Pengumuman
                    _buildLabel('Isi Pengumuman'),
                    TextFormField(
                      controller: _isiController,
                      maxLines: 5,
                      style: const TextStyle(color: Colors.white),
                      decoration: _buildInputDecoration('Tulis detail isi pengumuman di sini...', Icons.description_outlined),
                      validator: (v) => v == null || v.isEmpty ? 'Isi pengumuman wajib diisi.' : null,
                    ),
                    const SizedBox(height: 18),

                    // Target RT (Hanya admin RW yang bisa memilih, admin RT terkunci ke RT-nya sendiri)
                    _buildLabel('Target RT'),
                    if (_userRole == 'admin_rt')
                      _buildLockedRTCard()
                    else
                      _buildRTDropdown(),
                    const SizedBox(height: 18),

                    // Target Agama
                    _buildLabel('Target Segmentasi Agama (Opsional)'),
                    _buildAgamaDropdown(),
                    const SizedBox(height: 4),
                    Text(
                      'Pilih agama tertentu jika info sensitif ibadah/kegiatan keagamaan agar tidak memicu fatigue notifikasi bagi pemeluk agama lain.',
                      style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 36),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitAnnouncement,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const SpinKitThreeBounce(color: Colors.white, size: 24)
                          : Text(
                              'Post Pengumuman',
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
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

  Widget _buildLockedRTCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, color: Color(0xFF64748B), size: 20),
          const SizedBox(width: 12),
          Text(
            'Target Terkunci: RT Anda sendiri',
            style: GoogleFonts.outfit(color: const Color(0xFFCBD5E1), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildRTDropdown() {
    return DropdownButtonFormField<String?>(
      value: _selectedRTId,
      dropdownColor: const Color(0xFF1E293B),
      style: const TextStyle(color: Colors.white),
      decoration: _buildInputDecoration('', Icons.home_work_outlined),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text('Semua RT (Seluruh RW)', style: GoogleFonts.outfit()),
        ),
        ..._rtList.map((rt) {
          return DropdownMenuItem<String?>(
            value: rt['id'] as String,
            child: Text('RT ${rt['nomor_rt']}', style: GoogleFonts.outfit()),
          );
        }),
      ],
      onChanged: (val) {
        setState(() {
          _selectedRTId = val;
        });
      },
    );
  }

  Widget _buildAgamaDropdown() {
    return DropdownButtonFormField<String?>(
      value: _selectedAgama,
      dropdownColor: const Color(0xFF1E293B),
      style: const TextStyle(color: Colors.white),
      decoration: _buildInputDecoration('', Icons.people_outline),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text('Semua Warga (Semua Agama)', style: GoogleFonts.outfit()),
        ),
        ...['Islam', 'Kristen', 'Katolik', 'Hindu', 'Buddha', 'Khonghucu', 'Lainnya'].map((agama) {
          return DropdownMenuItem<String?>(
            value: agama,
            child: Text(agama, style: GoogleFonts.outfit()),
          );
        }),
      ],
      onChanged: (val) {
        setState(() {
          _selectedAgama = val;
        });
      },
    );
  }
}
