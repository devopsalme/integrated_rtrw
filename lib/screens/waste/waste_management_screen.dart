import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';
import '../../core/supabase_service.dart';

class WasteManagementScreen extends StatefulWidget {
  final String rtId;
  final String userRole;
  const WasteManagementScreen({super.key, required this.rtId, required this.userRole});

  @override
  State<WasteManagementScreen> createState() => _WasteManagementScreenState();
}

class _WasteManagementScreenState extends State<WasteManagementScreen> {
  final _supabaseService = SupabaseService();
  bool _isLoadingSchedule = true;
  bool _isLoadingRequests = true;

  List<Map<String, dynamic>> _scheduleList = [];
  List<Map<String, dynamic>> _pickupRequests = [];

  @override
  void initState() {
    super.initState();
    _loadSchedule();
    _loadPickupRequests();
  }

  Future<void> _loadSchedule() async {
    try {
      final list = await _supabaseService.getWasteSchedule(widget.rtId);
      if (mounted) {
        setState(() {
          _scheduleList = list;
          _isLoadingSchedule = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSchedule = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat jadwal sampah: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadPickupRequests() async {
    try {
      final list = await _supabaseService.getWastePickupRequests(widget.rtId);
      final myUid = _supabaseService.currentUser?.id;
      final isAdmin = widget.userRole == 'admin_rt';

      // Warga hanya bisa melihat request-nya sendiri, sedangkan Admin bisa melihat semuanya
      final filtered = isAdmin ? list : list.where((r) => r['created_by'] == myUid).toList();

      if (mounted) {
        setState(() {
          _pickupRequests = filtered;
          _isLoadingRequests = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRequests = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat pengajuan jemput: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleStatusUpdate(String requestId, String newStatus) async {
    setState(() => _isLoadingRequests = true);
    try {
      await _supabaseService.updateWastePickupStatus(
        requestId: requestId,
        status: newStatus,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status pengajuan berhasil diubah menjadi $newStatus.'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        _loadPickupRequests();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRequests = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengubah status: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showCreateRequestDialog() {
    final formKey = GlobalKey<FormState>();
    final descController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));

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
                      'Ajukan Jemput Sampah Besar',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 20),

                    // Deskripsi Sampah
                    Text('Deskripsi Sampah Besar', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8))),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: descController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 2,
                      decoration: _buildInputDecoration('Contoh: Penebangan pohon mangga, Lemari kayu rusak...', Icons.delete_outline),
                      validator: (v) => v == null || v.isEmpty ? 'Deskripsi sampah wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),

                    // Tanggal Penjemputan
                    Text('Rencana Tanggal Penjemputan', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8))),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
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

                    // Submit Button
                    ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        
                        Navigator.pop(context); // Tutup modal
                        setState(() => _isLoadingRequests = true);

                        try {
                          await _supabaseService.createWastePickupRequest(
                            rtId: widget.rtId,
                            deskripsi: descController.text.trim(),
                            scheduledDate: selectedDate.toIso8601String().substring(0, 10),
                          );

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Permintaan jemput sampah berhasil diajukan!', style: TextStyle(fontWeight: FontWeight.bold)),
                              backgroundColor: Color(0xFF10B981),
                            ),
                          );
                          _loadPickupRequests();
                        } catch (e) {
                          setState(() => _isLoadingRequests = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gagal mengajukan: $e'), backgroundColor: Colors.red),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text('Kirim Pengajuan', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
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
    final isWarga = widget.userRole == 'warga';

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
            'Layanan Sampah Lingkungan',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          bottom: TabBar(
            indicatorColor: const Color(0xFF38BDF8),
            labelColor: const Color(0xFF38BDF8),
            unselectedLabelColor: Colors.slate[400],
            tabs: [
              Tab(child: Text('Jadwal Rutin', style: GoogleFonts.outfit(fontWeight: FontWeight.bold))),
              Tab(child: Text(isWarga ? 'Jemput Khusus' : 'Pengajuan Warga', style: GoogleFonts.outfit(fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        floatingActionButton: isWarga
            ? FloatingActionButton.extended(
                onPressed: _showCreateRequestDialog,
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add),
                label: Text('Ajukan Jemput', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              )
            : null,
        body: TabBarView(
          children: [
            _buildScheduleTab(),
            _buildPickupTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleTab() {
    if (_isLoadingSchedule) {
      return const Center(child: SpinKitFadingCircle(color: Color(0xFF38BDF8), size: 50));
    }

    return RefreshIndicator(
      onRefresh: _loadSchedule,
      color: const Color(0xFF38BDF8),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: _scheduleList.length,
        itemBuilder: (context, index) {
          final s = _scheduleList[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF0284C7).withOpacity(0.1),
                  child: const Icon(Icons.local_shipping_outlined, color: Color(0xFF38BDF8)),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s['hari'] ?? '',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s['tipe_sampah'] ?? '',
                        style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFFCBD5E1)),
                      ),
                      Text(
                        'Estimasi Rute: ${s['jam'] ?? "Pagi"}',
                        style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPickupTab() {
    if (_isLoadingRequests) {
      return const Center(child: SpinKitFadingCircle(color: Color(0xFF38BDF8), size: 50));
    }

    if (_pickupRequests.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.delete_sweep_outlined, size: 72, color: Color(0xFF64748B)),
                const SizedBox(height: 16),
                Text(
                  'Tidak Ada Pengajuan',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.userRole == 'warga'
                      ? 'Ajukan penjemputan jika Anda memangkas pohon atau memiliki sampah rumah tangga ukuran besar.'
                      : 'Warga Anda belum mengajukan jemput sampah besar khusus.',
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
      onRefresh: _loadPickupRequests,
      color: const Color(0xFF38BDF8),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: _pickupRequests.length,
        itemBuilder: (context, index) {
          final r = _pickupRequests[index];
          final status = r['status'] as String;
          
          final isPending = status == 'pending';
          final isScheduled = status == 'scheduled';
          final isCompleted = status == 'completed';

          final scheduledDate = DateTime.parse(r['scheduled_date'] as String);
          final dateStr = DateFormat('dd MMMM yyyy').format(scheduledDate);
          final reporter = r['creator'] != null ? (r['creator'] as Map)['nama_lengkap'] as String? ?? 'Warga' : 'Warga';
          final reporterPhone = r['creator'] != null ? (r['creator'] as Map)['no_hp'] as String? ?? '' : '';

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCompleted 
                    ? const Color(0xFF10B981).withOpacity(0.2) 
                    : (isScheduled ? Colors.blue.withOpacity(0.2) : Colors.white.withOpacity(0.05)),
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
                        color: isCompleted 
                            ? const Color(0xFF10B981).withOpacity(0.15) 
                            : (isScheduled ? Colors.blue.withOpacity(0.15) : Colors.orangeAccent.withOpacity(0.15)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isCompleted ? const Color(0xFF10B981) : (isScheduled ? Colors.blue : Colors.orangeAccent),
                        ),
                      ),
                    ),
                    Text(
                      'Rencana Jemput: $dateStr',
                      style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFFCBD5E1)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Text(
                  r['deskripsi'] ?? '',
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                if (widget.userRole == 'admin_rt') ...[
                  Text(
                    'Pengaju: $reporter ($reporterPhone)',
                    style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8)),
                  ),
                ],

                if (widget.userRole == 'admin_rt' && !isCompleted) ...[
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isPending)
                        ElevatedButton.icon(
                          onPressed: () => _handleStatusUpdate(r['id'], 'scheduled'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          icon: const Icon(Icons.calendar_month_outlined, size: 16),
                          label: Text('Jadwalkan', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      if (isScheduled)
                        ElevatedButton.icon(
                          onPressed: () => _handleStatusUpdate(r['id'], 'completed'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          icon: const Icon(Icons.done_all, size: 16),
                          label: Text('Selesai Jemput', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  )
                ]
              ],
            ),
          );
        },
      ),
    );
  }
}
