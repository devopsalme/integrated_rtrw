import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';
import '../../core/supabase_service.dart';

class KasRTScreen extends StatefulWidget {
  final String rtId;
  final String userRole;
  const KasRTScreen({super.key, required this.rtId, required this.userRole});

  @override
  State<KasRTScreen> createState() => _KasRTScreenState();
}

class _KasRTScreenState extends State<KasRTScreen> {
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _kasList = [];
  
  double _saldoTotal = 0.0;
  double _totalMasuk = 0.0;
  double _totalKeluar = 0.0;

  final _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadKasData();
  }

  Future<void> _loadKasData() async {
    try {
      final list = await _supabaseService.getKasRTList(widget.rtId);
      
      double masuk = 0.0;
      double keluar = 0.0;
      
      for (var item in list) {
        final nominal = (item['nominal'] as num).toDouble();
        final tipe = item['tipe_aliran'] as String;
        if (tipe == 'masuk') {
          masuk += nominal;
        } else {
          keluar += nominal;
        }
      }

      if (mounted) {
        setState(() {
          _kasList = list;
          _totalMasuk = masuk;
          _totalKeluar = keluar;
          _saldoTotal = masuk - keluar;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat kas RT: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddTransactionDialog() {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final descController = TextEditingController();
    String selectedTipe = 'masuk';

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
                      'Catat Transaksi Kas RT',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 20),

                    // Tipe Aliran
                    Text('Tipe Aliran Dana', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8))),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        ChoiceChip(
                          label: Text('Kas Masuk', style: GoogleFonts.outfit()),
                          selected: selectedTipe == 'masuk',
                          selectedColor: const Color(0xFF10B981),
                          onSelected: (val) => setModalState(() => selectedTipe = 'masuk'),
                        ),
                        const SizedBox(width: 12),
                        ChoiceChip(
                          label: Text('Kas Keluar', style: GoogleFonts.outfit()),
                          selected: selectedTipe == 'keluar',
                          selectedColor: Colors.redAccent,
                          onSelected: (val) => setModalState(() => selectedTipe = 'keluar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Nominal
                    Text('Nominal (Rupiah)', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8))),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: _buildInputDecoration('Contoh: 150000', Icons.attach_money),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Nominal wajib diisi';
                        if (double.tryParse(v) == null) return 'Harus berupa angka';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Keterangan
                    Text('Keterangan / Deskripsi', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8))),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: descController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 2,
                      decoration: _buildInputDecoration('Contoh: Pembelian sapu lidi & cat pos ronda', Icons.notes_outlined),
                      validator: (v) => v == null || v.isEmpty ? 'Keterangan wajib diisi' : null,
                    ),
                    const SizedBox(height: 28),

                    // Submit Button
                    ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        
                        Navigator.pop(context); // Tutup Dialog
                        setState(() => _isLoading = true);

                        try {
                          final nominal = double.parse(amountController.text.trim());
                          await _supabaseService.addKasTransaction(
                            rtId: widget.rtId,
                            tipeAliran: selectedTipe,
                            nominal: nominal,
                            keterangan: descController.text.trim(),
                          );

                           ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Transaksi berhasil dicatat!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                          _loadKasData();
                        } catch (e) {
                          setState(() => _isLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gagal mencatat transaksi: $e'), backgroundColor: Colors.red),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text('Catat Transaksi', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
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
    final isAdminRT = widget.userRole == 'admin_rt';

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
          'Laporan Kas RT Terbuka',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      floatingActionButton: isAdminRT
          ? FloatingActionButton(
              onPressed: _showAddTransactionDialog,
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
      body: _isLoading
          ? const Center(child: SpinKitFadingCircle(color: Color(0xFF38BDF8), size: 50))
          : RefreshIndicator(
              onRefresh: _loadKasData,
              color: const Color(0xFF38BDF8),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Total Balance Card
                    _buildBalanceHeaderCard(),
                    
                    const SizedBox(height: 28),

                    // Ledger Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Riwayat Aliran Kas RT',
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            '${_kasList.length} transaksi',
                            style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Ledger List
                    _kasList.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 48.0),
                              child: Text('Belum ada riwayat transaksi kas.', style: TextStyle(color: Color(0xFF64748B))),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _kasList.length,
                            itemBuilder: (context, index) {
                              final item = _kasList[index];
                              final isMasuk = item['tipe_aliran'] == 'masuk';
                              final nominal = (item['nominal'] as num).toDouble();
                              final createdDate = DateTime.parse(item['created_at'] as String);
                              final dateStr = DateFormat('dd MMM yyyy').format(createdDate);
                              final creator = item['creator'] != null ? (item['creator'] as Map)['nama_lengkap'] : 'Admin';

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
                                      backgroundColor: isMasuk
                                          ? const Color(0xFF10B981).withOpacity(0.1)
                                          : Colors.redAccent.withOpacity(0.1),
                                      child: Icon(
                                        isMasuk ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                        color: isMasuk ? const Color(0xFF10B981) : Colors.redAccent,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['keterangan'] ?? '',
                                            style: GoogleFonts.outfit(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Oleh: $creator • $dateStr',
                                            style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${isMasuk ? "+" : "-"}${_currencyFormatter.format(nominal)}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isMasuk ? const Color(0xFF10B981) : Colors.redAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBalanceHeaderCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Text(
            'TOTAL SALDO KAS RT',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currencyFormatter.format(_saldoTotal),
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF38BDF8),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.arrow_circle_down_rounded, color: Color(0xFF10B981), size: 16),
                        const SizedBox(width: 4),
                        Text('Total Pemasukan', style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currencyFormatter.format(_totalMasuk),
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white10),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.arrow_circle_up_rounded, color: Colors.redAccent, size: 16),
                        const SizedBox(width: 4),
                        Text('Total Pengeluaran', style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currencyFormatter.format(_totalKeluar),
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
