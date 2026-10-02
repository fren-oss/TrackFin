# TrackFin

Pelacak pengeluaran harian dengan dompet manual dan sinkronisasi Google Sheets.
Berjalan sebagai Progressive Web App (PWA) di web.

![Flutter](https://img.shields.io/badge/Flutter-3.47-blue) ![Dart](https://img.shields.io/badge/Dart-3-blue)

## Fitur

- Catat pengeluaran dengan kategori, dompet, tanggal, dan catatan
- Kelola dompet manual dengan saldo yang bisa kamu tentukan sendiri
- Analisis pengeluaran per kategori dan per periode
- Sinkronisasi dua arah dengan Google Sheets tanpa OAuth
- Berjalan sebagai PWA, bisa dipasang ke layar utama

## Menjalankan secara lokal

Butuh Flutter 3.47 atau lebih baru.

```bash
flutter pub get
flutter run -d chrome
```

Untuk membuat build rilis dan menyajikannya lewat server lokal:

```bash
flutter build web --release
python3 tool/serve_web.py 8899
```

Buka `http://localhost:8899`. Script tersebut sengaja menonaktifkan cache
supaya perubahan kode langsung terlihat.

## Sinkronisasi Google Sheets

Sinkronisasi berjalan lewat Google Apps Script Web App. Tidak ada OAuth: URL
Web App itu sendiri adalah seluruh konfigurasinya.

1. Buat Google Sheet baru
2. Buka **Extensions → Apps Script**
3. Salin isi `tools/sheets/Code.gs` ke editor
4. **Deploy → New deployment → Web app**
   - *Execute as*: Me
   - *Who has access*: Anyone
5. Salin URL yang berakhiran `/exec`
6. Buka TrackFin → **Pengaturan**, tempel URL tersebut, lalu **Uji koneksi**

Setiap baris punya `id` yang stabil. Script melakukan *upsert* berdasarkan `id`,
sehingga mengirim ulang data yang sama memperbarui baris tersebut alih-alih
menggandakan.

### Kenapa sinkronisasi web memakai JSONP

Browser memblokir respons lintas origin yang tidak membawa header CORS, dan
Google Apps Script tidak pernah mengirim header itu. Posting langsung dari
browser karena itu mustahil. Aplikasi native tidak terpengaruh, karena bukan browser yang tunduk pada aturan
CORS.

Solusinya JSONP: memuat respons sebagai tag `<script>`, yang dikecualikan dari
CORS. Konsekuensinya payload ikut dibawa di URL, sehingga batch yang sangat
besar bisa melebihi batas panjang URL browser.

Berkas terkait:

- `lib/services/sheets_sync.dart` — klien, parsing respons, dan penanganan galat
- `lib/services/jsonp_transport_web.dart` — implementasi JSONP sisi browser
- `tool/fake_web_app.dart` — tiruan Web App untuk menguji JSONP di browser

## Struktur

```
lib/
  components/    komponen UI yang dipakai bersama
  design/        token warna, tipografi, tema
  models/        model data dan kategori bawaan
  screens/       satu berkas per tab
  services/      klien Google Sheets dan transport
  state/         state aplikasi dan persistensi
tools/sheets/    Code.gs, backend Google Apps Script
tool/            skrip pendukung untuk pengembangan
```

## Pengujian

```bash
flutter analyze
flutter test
```

Tes transport web berjalan di Chrome dan memerlukan tiruan Web App:

```bash
dart tool/fake_web_app.dart &
flutter test --platform chrome test/sheets_sync_web_test.dart
```