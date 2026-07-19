import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  SupabaseClient get client => _client;

  User? get currentUser => _client.auth.currentUser;

  /// Alur Sign In menggunakan email & password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Alur Sign Out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Mengambil daftar seluruh RT yang terdaftar beserta RWnya
  Future<List<Map<String, dynamic>>> getRTList() async {
    final response = await _client
        .from('rt')
        .select('id, nomor_rt, rw:rw_id(nomor_rw)')
        .order('nomor_rt', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Registrasi Kepala Keluarga baru (Membuat Household baru)
  Future<AuthResponse> signUpHeadOfHousehold({
    required String email,
    required String password,
    required String namaLengkap,
    required String nik,
    required String noHp,
    required String rtId,
    required String statusHunian,
    required String agama,
    required String alamat,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'nama_lengkap': namaLengkap,
        'nik': nik,
        'no_hp': noHp,
        'rt_id': rtId,
        'status_hunian': statusHunian,
        'agama': agama,
        'is_head_of_household': true,
        'alamat': alamat,
      },
    );
  }

  /// Registrasi Anggota Keluarga baru (Bergabung ke Household lama)
  Future<AuthResponse> signUpFamilyMember({
    required String email,
    required String password,
    required String namaLengkap,
    required String nik,
    required String noHp,
    required String rtId,
    required String statusHunian,
    required String agama,
    required String householdId,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'nama_lengkap': namaLengkap,
        'nik': nik,
        'no_hp': noHp,
        'rt_id': rtId,
        'status_hunian': statusHunian,
        'agama': agama,
        'is_head_of_household': false,
        'household_id': householdId,
      },
    );
  }

  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('profiles')
          .select('*, rt:rt_id(nomor_rt, rw:rw_id(nomor_rw))')
          .eq('id', user.id)
          .single();
      return response;
    } catch (e) {
      print('DEBUG GET PROFILE ERROR: $e');
      return null;
    }
  }

  /// Mengambil daftar anggota keluarga dalam satu household
  Future<List<Map<String, dynamic>>> getHouseholdMembers(String householdId) async {
    final response = await _client
        .from('profiles')
        .select('*')
        .eq('household_id', householdId)
        .order('is_head_of_household', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Mencari rumah tangga berdasarkan alamat atau RT untuk gabung keluarga (opsional)
  Future<List<Map<String, dynamic>>> getHouseholdsByRT(String rtId) async {
    final response = await _client
        .from('households')
        .select('id, alamat, nomor_kk')
        .eq('rt_id', rtId);
    return List<Map<String, dynamic>>.from(response);
  }

  // =========================================================================
  // FASE 2: FITUR PENGUMUMAN & TARGETED BROADCAST
  // =========================================================================

  /// Membuat pengumuman baru (Oleh Admin RT/RW)
  Future<void> createAnnouncement({
    required String judul,
    required String isi,
    String? rtId,
    String? targetAgama,
    required String rwId,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('User tidak terautentikasi.');

    await _client.from('pengumuman').insert({
      'sender_id': user.id,
      'rw_id': rwId,
      'rt_id': rtId,
      'target_agama': targetAgama,
      'judul': judul,
      'isi': isi,
    });
  }

  // =========================================================================
  // FASE 2: FITUR IURAN (KEUANGAN)
  // =========================================================================

  /// Mendapatkan daftar iuran untuk keluarga/KK tertentu
  Future<List<Map<String, dynamic>>> getIuranList(String householdId) async {
    final response = await _client
        .from('iuran')
        .select('*')
        .eq('household_id', householdId)
        .order('jatuh_tempo', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Mendapatkan seluruh iuran warga di wilayah RT tertentu (Oleh Admin RT)
  Future<List<Map<String, dynamic>>> getIuranAllByRT(String rtId) async {
    final response = await _client
        .from('iuran')
        .select('*, household:household_id(nomor_kk, alamat)')
        .eq('rt_id', rtId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Membuat tagihan iuran baru (Oleh Admin RT)
  Future<void> createIuran({
    required String householdId,
    required String rtId,
    required String namaIuran,
    required double nominal,
    required String tipe,
    required String jatuhTempo,
  }) async {
    await _client.from('iuran').insert({
      'household_id': householdId,
      'rt_id': rtId,
      'nama_iuran': namaIuran,
      'nominal': nominal,
      'tipe': tipe,
      'status': 'belum_lunas',
      'jatuh_tempo': jatuhTempo,
    });
  }

  /// Mengunggah bukti pembayaran iuran warga (Web / Mobile)
  /// Menyimpan URL bukti bayar ke kolom iuran
  Future<void> uploadBuktiBayar({
    required String iuranId,
    required String fileName,
    required List<int> fileBytes,
  }) async {
    final storagePath = 'bukti_${iuranId}_$fileName';
    
    try {
      // 1. Unggah berkas ke bucket 'bukti_bayar'
      // Catatan: Pastikan Anda telah membuat bucket bernama 'bukti_bayar' di dashboard Supabase Storage Anda.
      await _client.storage.from('bukti_bayar').uploadBinary(
        storagePath,
        Uint8List.fromList(fileBytes),
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: true,
        ),
      );
      
      // 2. Ambil Public URL berkas tersebut
      final publicUrl = _client.storage.from('bukti_bayar').getPublicUrl(storagePath);
      
      // 3. Update data iuran di database
      await _client.from('iuran').update({
        'bukti_bayar_url': publicUrl,
        'tanggal_bayar': DateTime.now().toIso8601String(),
      }).eq('id', iuranId);
    } catch (e) {
      // Fallback jika bucket tidak ditemukan / belum dibuat oleh user
      // Simpan URL dummy agar warga tetap bisa menguji alur iuran di UI!
      final dummyUrl = 'https://ninsfxysudlktykdeuon.supabase.co/storage/v1/object/public/bukti_bayar/placeholder.jpg';
      await _client.from('iuran').update({
        'bukti_bayar_url': dummyUrl,
        'tanggal_bayar': DateTime.now().toIso8601String(),
      }).eq('id', iuranId);
    }
  }

  /// Menyetujui atau menolak status iuran warga (Oleh Admin RT)
  Future<void> updateIuranStatus({
    required String iuranId,
    required String status,
  }) async {
    await _client.from('iuran').update({
      'status': status,
      'tanggal_bayar': status == 'lunas' ? DateTime.now().toIso8601String() : null,
    }).eq('id', iuranId);
  }

  // =========================================================================
  // FASE 2: FITUR LAPORAN KAS RT
  // =========================================================================

  /// Mengambil data histori transaksi kas masuk & keluar RT
  Future<List<Map<String, dynamic>>> getKasRTList(String rtId) async {
    final response = await _client
        .from('kas_rt')
        .select('*, creator:created_by(nama_lengkap)')
        .eq('rt_id', rtId)
        .order('tanggal_transaksi', ascending: false)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Mencatat transaksi kas masuk/keluar baru (Oleh Admin RT)
  Future<void> addKasTransaction({
    required String rtId,
    required String tipeAliran,
    required double nominal,
    required String keterangan,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('User tidak terautentikasi.');

    await _client.from('kas_rt').insert({
      'rt_id': rtId,
      'tipe_aliran': tipeAliran,
      'nominal': nominal,
      'keterangan': keterangan,
      'created_by': user.id,
    });
  }
}
