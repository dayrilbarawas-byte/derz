# DERIL SOCIAL

Fondasi aplikasi jejaring sosial full-stack berbasis React + TypeScript + Supabase.

## Yang sudah ada pada starter ini
- React/Vite mobile-first layout, dark/light mode, sidebar desktop dan bottom navigation mobile.
- Registrasi, login, logout menggunakan Supabase Auth.
- Trigger pembuatan profil otomatis saat signup.
- Feed mengambil postingan dari PostgreSQL.
- Upload foto/video ke Supabase Storage dan membuat post.
- Like/unlike tersimpan di database.
- SQL awal untuk profil, postingan, media, likes, komentar, follow, permintaan follow, stories, DM, notifikasi, calls, blocks, reports, hashtags, saved posts.
- RLS dasar dan kebijakan Storage.

## Belum diimplementasikan
DM realtime UI, komentar/replies UI, follow request approval UI, private-feed enforcement, story viewer/highlights, Explore search/trending, Reels recommendation, notifications UI, voice notes, group chat, WebRTC signaling/call UI, moderation console, rate limiting server-side, seed katalog media 100 foto + 100 video, dan automated end-to-end tests. Navigasi modul yang belum tersedia menampilkan status, bukan tombol palsu.

SQL ini adalah fondasi awal, bukan audit keamanan production. Sebelum membuka pendaftaran publik, lengkapi RLS untuk akun privat/blocking, validasi username, batas ukuran/rate upload, moderasi, dan uji kebijakan dengan dua akun berbeda.

## Menjalankan lokal
1. Install Node.js 20+.
2. Buat project di https://supabase.com.
3. Buka SQL Editor dan jalankan `supabase/schema.sql`.
4. Salin `.env.example` menjadi `.env`, isi `VITE_SUPABASE_URL` dan `VITE_SUPABASE_ANON_KEY` dari Project Settings > API.
5. Jalankan:
   ```bash
   npm install
   npm run dev
   ```
6. Untuk production: `npm run build`, lalu deploy folder `dist` ke Vercel/Netlify. Tambahkan dua environment variable yang sama pada dashboard hosting.

## Konfigurasi Supabase yang perlu diperiksa
- Auth > URL Configuration: set Site URL dan redirect URL domain production.
- Auth > Providers: aktifkan Email; atur SMTP production agar email verifikasi/reset dapat terkirim.
- Storage: bucket `post-media` dibuat oleh SQL.
- Database > Replication: aktifkan Realtime untuk `messages` dan `notifications` setelah kebijakan aksesnya diuji.
- Jangan pernah menaruh `service_role` key pada frontend. Anon/publishable key memang digunakan di browser bersama RLS.

## Media seed
Gunakan hanya media yang lisensinya mengizinkan redistribusi dan hotlinking. Jangan scrape Instagram atau mengambil konten berhak cipta tanpa izin. Seed katalog 100 foto + 100 video belum disertakan karena sumber media legal harus diverifikasi satu per satu; starter tidak mengisi feed dengan konten palsu.

## Panggilan WebRTC
WebRTC memerlukan signaling realtime, ICE/STUN/TURN (TURN biasanya diperlukan untuk koneksi lintas jaringan), izin kamera/mikrofon, dan lifecycle panggilan. Tabel `calls` saja bukan implementasi panggilan. Jangan mengaktifkan tombol panggilan sebelum signaling dan pengujian dua perangkat selesai.
