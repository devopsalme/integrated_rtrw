# Sistem Informasi Terpadu RW & RT (Integrated RTRW)

Proyek ini adalah aplikasi mobile berbasis **Flutter** (Android Native & iOS PWA) dengan backend **Supabase** (PostgreSQL, Auth, Storage, Edge Functions). Aplikasi ini dirancang menggunakan arsitektur *multi-tenant* (1 RW mengelola beberapa RT) dengan pemisahan data yang ketat menggunakan **Row Level Security (RLS)**.

## Tech Stack
- **Frontend**: Flutter
- **Backend & Database**: Supabase (Postgres, Auth, Storage, Edge Functions)
- **Deployment**: Android Native & iOS PWA

## Struktur Repositori & Branching
- `main`: Branch stabil untuk rilis produksi.
- `dev`: Branch utama untuk integrasi fitur baru dan testing.
- `feature/*`: Branch fitur spesifik (di-merge ke `dev` via Pull Request).

## Skema Database & RLS
Seluruh skema database PostgreSQL dan aturan keamanan (Row Level Security) disimpan di folder `/supabase` atau dapat ditemukan di repositori ini untuk kemudahan replikasi.

### Cara Mulai (Local Development)
1. Pastikan Flutter SDK telah terinstal di perangkat Anda.
2. Clone repository:
   ```bash
   git clone https://github.com/devopsalme/integrated_rtrw.git
   ```
3. Pindah ke branch `dev`:
   ```bash
   git checkout dev
   ```
4. Jalankan perintah `flutter pub get` untuk mengunduh dependency.
