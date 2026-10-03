import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DioClient {
  late final Dio dio;

  DioClient() {
    dio = Dio(
      BaseOptions(
        // Ganti dengan IP lokal komputermu jika pakai emulator Android (10.0.2.2:8000)
        // atau localhost:8000 jika pakai iOS simulator / Web.
        // GANTI BAGIAN INI:
        baseUrl:
            'http://localhost:8000', // Gunakan localhost karena jalan di Chrome
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Pasang Interceptor untuk menyisipkan Token JWT Supabase secara otomatis
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Ambil session aktif dari Supabase
          final session = Supabase.instance.client.auth.currentSession;
          final accessToken = session?.accessToken;

          if (accessToken != null) {
            // Sisipkan ke header Authorization
            options.headers['Authorization'] = 'Bearer $accessToken';
          }

          return handler.next(options);
        },
        onError: (DioException e, handler) {
          // Kamu bisa tangani error global di sini (misal: token habis -> logout)
          return handler.next(e);
        },
      ),
    );
  }
}
