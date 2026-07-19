import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';
import '../../core/supabase_service.dart';

class IuranManageScreen extends StatefulWidget {
  final String rtId;
  const IuranManageScreen({super.key, required this.rtId});

  @override
  State<IuranManageScreen> createState() => _IuranManageScreenState();
}

class _IuranManageScreenState extends State<IuranManageScreen> {
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _iuranList = [];
  List<Map<String, dynamic>> _householdsList = [];

  final _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final list = await _supabaseService.getIuranAllByRT(widget.rtId);
      final hh = await _supabaseService.getHouseholdsByRT(widget.rtId);
      if (mounted) {
        setState(() {
          _iuranList = list;
          _householdsList = hh;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleApprovePayment(Map<String, dynamic> iuran) async {
    setState(() => _isLoading = true);

    try {
      final iuranId = iuran['id'] as String;
      final nominal = (iuran['nominal'] as num).toDouble();
      final namaIuran = iuran['nama_iuran'] as String;
      final hh = iuran['household'] as Map?;
      final alamat = hh != null ? hh['alamat'] as String? ?? '' : '';

      // 1. Setujui Pembayaran (Update status = lunas)
      await _supabaseService.updateIuranStatus(
        iuranId: iuranId,
        status: 'lunas',
      );

      // 2. Tambahkan Ke Kas RT Otomatis
      await _supabaseService.addKasTransaction(
        rtId: widget.rtId,
        tipeAliran: 'masuk',
        nominal: nominal,
        keterangan: 'Iuran Warga Lunas: $namaIuran (Alamat: $alamat)',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pembayaran disetujui! Saldo Kas RT bertambah.', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadInitialData();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memverifikasi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleRejectPayment(String iuranId) async {
    setState(() => _isLoading = true);

    try {
      await _supabaseService.client.from('iuran').update({
        'status': 'belum_lunas',
        'bukti_bayar_url': null, // Hapus bukti salah
        'tanggal_bayar': null,
      }).eq('id', iuranId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pembayaran ditolak. Status tagihan dikembalikan.', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.orangeAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadInitialData();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menolak pembayaran: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showCreateBillingDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    
    String? selectedHouseholdId; // Null means "Semua Rumah/KK"
    String selectedTipe = 'wajib';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 30));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Buat Tagihan Baru',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 20),

                    // Pilih Target Rumah Tangga
                    Text('Target Penerima Iuran', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String?>(
                      value: selectedHouseholdId,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      decoration: _buildInputDecoration('', Icons.people),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Semua KK di RT', style: GoogleFonts.outfit()),
                        ),
                        ..._householdsList.map((hh) {
                          return DropdownMenuItem<String?>(
                            value: hh['id'] as String,
                            child: Text(
                              'KK: ${hh['nomor_kk'] ?? ""} (${hh['alamat']})',
                              style: GoogleFonts.outfit(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) => setModalState(() => selectedHouseholdId = val),
                    ),
                    const SizedBox(height: 16),

                    // Nama Iuran
                    Text('Nama Iuran', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8))),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _buildInputDecoration('Contoh: Iuran Kebersihan Bulanan', Icons.receipt),
                      validator: (v) => v == null || v.isEmpty ? 'Nama iuran wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),

                    // Nominal
                    Text('Nominal (Rupiah)', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8))),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: _buildInputDecoration('Contoh: 50000', Icons.attach_money_rounded),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Nominal wajib diisi';
                        if (double.tryParse(v) == null) return 'Harus berupa angka';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Tipe
                    Text('Tipe Iuran', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8))),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        ChoiceChip(
                          label: Text('Wajib', style: GoogleFonts.outfit()),
                          selected: selectedTipe == 'wajib',
                          selectedColor: const Color(0xFF0284C7),
                          onSelected: (val) => setModalState(() => selectedTipe = 'wajib'),
                        ),
                        const SizedBox(width: 12),
                        ChoiceChip(
                          label: Text('Insidental', style: GoogleFonts.outfit()),
                          selected: selectedTipe == 'insidental',
                          selectedColor: const Color(0xFF0284C7),
                          onSelected: (val) => setModalState(() => selectedTipe = 'insidental'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Jatuh Tempo
                    Text('Jatuh Tempo', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8))),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(DateFormat('dd MMMM yyyy').format(selectedDate)),
                    ),
                    const SizedBox(height: 28),

                    // Submit
                    ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        
                        Navigator.pop(context); // Tutup Dialog
                        setState(() => _isLoading = true);

                        try {
                          final double nominal = double.parse(amountController.text.trim());
                          final String name = nameController.text.trim();
                          final String dateStr = selectedDate.toIso8601String().substring(0, 10);

                          if (selectedHouseholdId != null) {
                            // Tagih satu KK
                            await _supabaseService.createIuran(
                              householdId: selectedHouseholdId!,
                              rtId: widget.rtId,
                              namaIuran: name,
                              nominal: nominal,
                              tipe: selectedTipe,
                              jatuhTempo: dateStr,
                            );
                          } else {
                            // Tagih semua KK di RT
                            for (var hh in _householdsList) {
                              await _supabaseService.createIuran(
                                householdId: hh['id'] as String,
                                rtId: widget.rtId,
                                namaIuran: name,
                                nominal: nominal,
                                tipe: selectedTipe,
                                jatuhTempo: dateStr,
                              );
                            }
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Tagihan iuran berhasil diterbitkan!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                          _loadInitialData();
                        } catch (e) {
                          setState(() => _isLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gagal membuat tagihan: $e'), backgroundColor: Colors.red),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text('Terbitkan Tagihan', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
          'Kelola Iuran Warga',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_card_rounded, color: Color(0xFF38BDF8)),
            onPressed: _showCreateBillingDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: SpinKitFadingCircle(color: Color(0xFF38BDF8), size: 50))
          : RefreshIndicator(
              onRefresh: _loadInitialData,
              color: const Color(0xFF38BDF8),
              child: _iuranList.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      itemCount: _iuranList.length,
                      itemBuilder: (context, index) {
                        final iuran = _iuranList[index];
                        return _buildIuranManageCard(iuran);
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
              const Icon(Icons.payment_rounded, size: 72, color: Color(0xFF64748B)),
              const SizedBox(height: 16),
              Text(
                'Belum Ada Tagihan',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Klik tombol tambah di pojok kanan atas untuk menerbitkan tagihan iuran perdana.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIuranManageCard(Map<String, dynamic> iuran) {
    final status = iuran['status'] as String;
    final nominal = (iuran['nominal'] as num).toDouble();
    final tipe = iuran['tipe'] as String;
    final jatuhTempo = DateTime.parse(iuran['jatuh_tempo'] as String);
    final isLunas = status == 'lunas';
    final hasUploadedProof = iuran['bukti_bayar_url'] != null;

    final hh = iuran['household'] as Map?;
    final alamat = hh != null ? hh['alamat'] as String? ?? '' : 'Tidak diketahui';

    final dateStr = DateFormat('dd MMM yyyy').format(jatuhTempo);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLunas 
              ? const Color(0xFF10B981).withOpacity(0.2) 
              : (hasUploadedProof ? Colors.orangeAccent.withOpacity(0.3) : Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isLunas 
                      ? const Color(0xFF10B981).withOpacity(0.15) 
                      : (hasUploadedProof ? Colors.orangeAccent.withOpacity(0.15) : const Color(0xFF64748B).withOpacity(0.15)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isLunas ? 'LUNAS' : (hasUploadedProof ? 'VERIFIKASI PENDING' : 'BELUM BAYAR'),
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isLunas ? const Color(0xFF10B981) : (hasUploadedProof ? Colors.orangeAccent : const Color(0xFF64748B)),
                  ),
                ),
              ),
              Text(
                tipe.toUpperCase(),
                style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            iuran['nama_iuran'] ?? '',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Alamat: $alamat',
            style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFFCBD5E1)),
          ),
          Text(
            'Jatuh Tempo: $dateStr • Nominal: ${_currencyFormatter.format(nominal)}',
            style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8)),
          ),
          
          if (!isLunas && hasUploadedProof) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color(0xFF1E293B),
                        title: Text('Verifikasi Bukti Transfer', style: GoogleFonts.outfit(color: Colors.white)),
                        content: Image.network(iuran['bukti_bayar_url']),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Tutup', style: GoogleFonts.outfit(color: Colors.white)),
                          )
                        ],
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.1)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.image_outlined, size: 16),
                  label: Text('Lihat Bukti', style: GoogleFonts.outfit(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                  onPressed: () => _handleRejectPayment(iuran['id']),
                ),
                const SizedBox(width: 4),
                ElevatedButton.icon(
                  onPressed: () => _handleApprovePayment(iuran),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: Text('Setujui', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            )
          ]
        ],
      ),
    );
  }
}
