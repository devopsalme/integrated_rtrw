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

  /// Mengambil profil user yang sedang login
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
      return null;
    }
  }

  /// Mengambil daftar anggota keluarga dalam satu household
  Future<List<Map<String, dynamic>>> getHouseholdMembers(String householdId) async {
    final response = await _client
        .from('profiles')
        .select('*')
        .eq('household_id', householdId)
        .order('is_head_of_household', descending: true);
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
}
