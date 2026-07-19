import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../core/supabase_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabaseService = SupabaseService();

  // Controllers
  final _namaController = TextEditingController();
  final _nikController = TextEditingController();
  final _hpController = TextEditingController();
  final _alamatController = TextEditingController();
  final _householdIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Selected values
  String? _selectedRTId;
  String _selectedStatusHunian = 'Pemilik';
  String _selectedAgama = 'Islam';
  bool _isHeadOfHousehold = true; // Toggle for Head vs Family Member

  
  // State flags
  bool _isLoadingRTs = true;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _rtList = [];
  String? _rtFetchError;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadRTList();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _nikController.dispose();
    _hpController.dispose();
    _alamatController.dispose();
    _householdIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadRTList() async {
    try {
      final list = await _supabaseService.getRTList();
      setState(() {
        _rtList = list;
        if (list.isNotEmpty) {
          _selectedRTId = list.first['id'] as String?;
        }
        _isLoadingRTs = false;
      });
    } catch (e) {
      setState(() {
        _rtFetchError = 'Gagal memuat daftar RT: $e';
        _isLoadingRTs = false;
      });
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRTId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilihlah RT terlebih dahulu.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_isHeadOfHousehold) {
        await _supabaseService.signUpHeadOfHousehold(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          namaLengkap: _namaController.text.trim(),
          nik: _nikController.text.trim(),
          noHp: _hpController.text.trim(),
          rtId: _selectedRTId!,
          statusHunian: _selectedStatusHunian,
          agama: _selectedAgama,
          alamat: _alamatController.text.trim(),
        );
      } else {
        await _supabaseService.signUpFamilyMember(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          namaLengkap: _namaController.text.trim(),
          nik: _nikController.text.trim(),
          noHp: _hpController.text.trim(),
          rtId: _selectedRTId!,
          statusHunian: _selectedStatusHunian,
          agama: _selectedAgama,
          householdId: _householdIdController.text.trim(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Registrasi Berhasil! Silakan masuk ke aplikasi.',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context); // Kembali ke Login
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registrasi Gagal: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Daftar Warga Baru',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoadingRTs
          ? const Center(
              child: SpinKitFadingCircle(color: Color(0xFF38BDF8), size: 50),
            )
          : _rtFetchError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off, color: Colors.redAccent, size: 64),
                        const SizedBox(height: 16),
                        Text(_rtFetchError!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isLoadingRTs = true;
                              _rtFetchError = null;
                            });
                            _loadRTList();
                          },
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Toggle Role / Tipe Registrasi
                        _buildLabel('Tipe Registrasi Keluarga'),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: Text('Kepala Keluarga', style: GoogleFonts.outfit(fontSize: 13)),
                                selected: _isHeadOfHousehold,
                                selectedColor: const Color(0xFF0284C7),
                                backgroundColor: Colors.white.withOpacity(0.05),
                                labelStyle: TextStyle(color: _isHeadOfHousehold ? Colors.white : Colors.blueGrey[400]),
                                onSelected: (val) => setState(() => _isHeadOfHousehold = true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ChoiceChip(
                                label: Text('Anggota Keluarga', style: GoogleFonts.outfit(fontSize: 13)),
                                selected: !_isHeadOfHousehold,
                                selectedColor: const Color(0xFF0284C7),
                                backgroundColor: Colors.white.withOpacity(0.05),
                                labelStyle: TextStyle(color: !_isHeadOfHousehold ? Colors.white : Colors.blueGrey[400]),
                                onSelected: (val) => setState(() => _isHeadOfHousehold = false),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        Text(
                          _isHeadOfHousehold ? 'Data Kepala Keluarga & Rumah' : 'Data Diri Anggota Keluarga',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF38BDF8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isHeadOfHousehold 
                              ? 'Informasi ini digunakan untuk inisialisasi satu KK (Household ID).'
                              : 'Akun Anda akan dimasukkan ke dalam KK kepala keluarga Anda.',
                          style: GoogleFonts.outfit(fontSize: 13, color: Colors.blueGrey[400]),
                        ),
                        const SizedBox(height: 24),

                        // Nama Lengkap
                        _buildLabel('Nama Lengkap (Sesuai KTP)'),
                        _buildTextField(
                          controller: _namaController,
                          hintText: 'Faza Alme',
                          icon: Icons.person_outline,
                          validator: (v) => v == null || v.isEmpty ? 'Nama lengkap harus diisi' : null,
                        ),
                        const SizedBox(height: 16),

                        // NIK
                        _buildLabel('Nomor Induk Kependudukan (NIK)'),
                        _buildTextField(
                          controller: _nikController,
                          hintText: '3273xxxxxxxxxxxx',
                          icon: Icons.badge_outlined,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'NIK harus diisi';
                            if (v.length != 16) return 'NIK harus 16 digit';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // No. HP
                        _buildLabel('No. Handphone'),
                        _buildTextField(
                          controller: _hpController,
                          hintText: '0812xxxxxxxx',
                          icon: Icons.phone_android_outlined,
                          keyboardType: TextInputType.phone,
                          validator: (v) => v == null || v.isEmpty ? 'Nomor HP harus diisi' : null,
                        ),
                        const SizedBox(height: 16),

                        // RT Dropdown
                        _buildLabel('Pilih Wilayah RT'),
                        _buildRTDropdown(),
                        const SizedBox(height: 16),

                        // Status Hunian Dropdown
                        _buildLabel('Status Hunian'),
                        _buildDropdown(
                          value: _selectedStatusHunian,
                          items: ['Pemilik', 'Ngontrak', 'Kos'],
                          onChanged: (v) => setState(() => _selectedStatusHunian = v!),
                        ),
                        const SizedBox(height: 16),

                        // Agama Dropdown
                        _buildLabel('Agama'),
                        _buildDropdown(
                          value: _selectedAgama,
                          items: ['Islam', 'Kristen', 'Katolik', 'Hindu', 'Buddha', 'Khonghucu', 'Lainnya'],
                          onChanged: (v) => setState(() => _selectedAgama = v!),
                        ),
                        const SizedBox(height: 16),

                        // Conditional: Address vs Household ID
                        if (_isHeadOfHousehold) ...[
                          _buildLabel('Alamat Lengkap Rumah'),
                          _buildTextField(
                            controller: _alamatController,
                            hintText: 'Jl. Merpati No. 12, Kav. B',
                            icon: Icons.location_on_outlined,
                            maxLines: 2,
                            validator: (v) => v == null || v.isEmpty ? 'Alamat harus diisi' : null,
                          ),
                        ] else ...[
                          _buildLabel('Kode Keluarga (Household ID)'),
                          _buildTextField(
                            controller: _householdIdController,
                            hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
                            icon: Icons.key_outlined,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Kode Keluarga harus diisi';
                              if (v.length != 36) return 'Kode Keluarga harus berupa UUID (36 karakter)';
                              return null;
                            },
                          ),
                        ],

                        Text(
                          'Kredensial Akun',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF38BDF8),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Email
                        _buildLabel('Email Akun'),
                        _buildTextField(
                          controller: _emailController,
                          hintText: 'nama@domain.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Email harus diisi';
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                              return 'Format email tidak valid';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password
                        _buildLabel('Password'),
                        _buildPasswordField(),
                        const SizedBox(height: 40),

                        // Register Button
                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isSubmitting
                              ? const SpinKitThreeBounce(color: Colors.white, size: 24)
                              : Text(
                                  'Daftar Sekarang',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        label,
        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blueGrey[300]),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.blueGrey[500]),
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
      ),
      validator: validator,
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: '••••••••',
        hintStyle: TextStyle(color: Colors.blueGrey[500]),
        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF38BDF8)),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Colors.blueGrey[400],
          ),
          onPressed: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
        ),
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
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Password tidak boleh kosong';
        if (v.length < 6) return 'Password minimal 6 karakter';
        return null;
      },
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: const Color(0xFF1E293B),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
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
      ),
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item, style: GoogleFonts.outfit()),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildRTDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedRTId,
      dropdownColor: const Color(0xFF1E293B),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
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
      ),
      items: _rtList.map((rt) {
        final rwNum = rt['rw'] != null ? (rt['rw'] as Map)['nomor_rw'] : '';
        final rtText = 'RT ${rt['nomor_rt']} / RW $rwNum';
        return DropdownMenuItem<String>(
          value: rt['id'] as String,
          child: Text(rtText, style: GoogleFonts.outfit()),
        );
      }).toList(),
      onChanged: (val) {
        setState(() {
          _selectedRTId = val;
        });
      },
    );
  }
}
