## VULFT


VULFT - Total Override Bot Script. Peran DotaBuff dan urutan pembuatan inventaris diperbarui pada: 19/03/23. Memerlukan instalasi manual ke folder vscripts/bots (sama seperti Phalanx Bot, dan bot terbaru lainnya, karena bug bengkel Dota). VUL-FT tidak berafiliasi dengan DotaBuff.



##  Terjemahan 

Terjemahan membutuhkan waktu lama bagi saya, sekitar 30 menit. Saya perlu kembali ke pemrograman, jadi file ini mungkin sudah ketinggalan zaman. Jika proses instalasi manual diperbaiki dan tidak lagi diperlukan, saya akan memperbarui dokumen ini. Lihat halaman lokakarya bahasa Inggris untuk tanggal pembuatan DotaBuff saat ini dan tanggal rilis perangkat lunak.



##  Menginstal secara manual 

VUL-FT saat ini tidak akan bekerja hanya dengan berlangganan. Ini akan kembali ke bot default, bot lain yang baru dirilis memiliki masalah yang sama. Untuk saat ini, Anda perlu menginstal bot secara manual.



Opsional: Sebelum mengatur VUL-FT sebagai skrip dev lokal, Mungkin juga ide yang baik untuk membuat cadangan folder 'vscript/bots' lama Anda jika Anda memiliki bot lain yang telah Anda simpan di sana:

Folder bot dev lokal terletak di

[drive]:/%Program Files%/Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots

0) Ganti nama folder bot menjadi bots.old.

1) buat folder baru bernama bots

2) salin file VUL-FT dari folder github atau workshop ke folder bot baru.



- Melalui file lokal lokakarya: (file lokakarya yang diverifikasi Valve)

Setelah baru saja mengunduh VULFT dalam game atau di lokakarya, temukan folder terbaru di

[drive]:/%Program Files%/Steam/steamapps/workshop/content/570/2872725543

dan salin konten folder itu ke folder bot di

[drive]:/%Program Files%/Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots/



- Melalui Github: (diperbarui oleh pembuatnya)

Jika Anda tahu cara menggunakan git, Anda dapat mengunduh bot secara manual dari [official VUL-FT Github](https://github.com/yewchi/vulft) dan memasukkannya ke dalam

[drive]:/%Program Files%/Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots/



-- Memulai pertandingan:

Setelah salah satu langkah di atas selesai, Anda dapat menjalankan bot dengan menavigasi dalam game ke Lobi Kustom -> Buat -> Edit:

Di bawah PENGATURAN BOT, ubah bot tim ke Skrip Dev Lokal (jika Anda masih ingin melawan bot Valve, perhatikan bahwa ada opsi untuk "Bot Default" di sini juga)

Ubah LOKASI SERVER menjadi HOST LOKAL (komputer Anda).

Pengaturan 'Mudah' atau 'Tidak Adil' belum berpengaruh, tetapi 'Tidak Adil' dapat meningkatkan emas pasif bot.

Tekan OK.

Bergabunglah dengan slot pertama Dire atau Radiant.

Tekan START GAME.



Atau, Anda dapat menggunakan opsi "Mainkan VS Bots" tetapi tidak semua pahlawan diterapkan.



## Fitur

- Pengambilan keputusan pertarungan dinamis.

- Lebih seperti pemain sungguhan.

- Bot mulai bergerak segera setelah bot melepaskan serangan, melangkah menuju mundurnya musuh.

- Manajemen persediaan tingkat lanjut.

- Lokasi bangsal pengamat yang dibuat secara otomatis, karena jika peta pernah berubah.

- Parser DotaBuff untuk rata-rata dari 5 build skill game, peran dan build item dari pemain Divine - Immortal minggu itu.

- Monster dasar berburu di waktu luang bot.

- Ketika mereka memiliki hit point rendah dan dalam bahaya, mereka dapat menyerang monster hutan.

- Retret dinamis, ke menara ramah (kecuali menara terlalu ramai), atau ke sekutu yang bersahabat ke arah air mancur sekutu.

- Alokasi tugas rune bounty berdasarkan kedekatan, keamanan, kabut, peringkat keserakahan - Alokasi menara pertahanan berdasarkan kesulitan bertarung.

- Penggunaan CPU yang lebih rendah daripada bot populer lainnya.

- Bug perangkat lunak!



Tetapi juga, saya berjanji kode proyek ini 100% fungsional offline dan saya tidak akan pernah memperkenalkan API jaringan di basis kode ini.



## Laporan Kesalahan

[ Lua Error Dump (tautan diskusi uap)](https://steamcommunity.com/workshop/filedetails/discussion/2872725543/3648503910213521285/) -- Gunakan ini jika Anda hanya ingin menyalin beberapa pesan kesalahan dari log konsol.

[ Kode sumber VUL-FT]( https://github.com / yewchi / vulft ) -- GitHub publik



## Masalah yang Diketahui

Bagian ini sangat sulit untuk diterjemahkan, maaf!



Semua entitas yang dapat diambil hadiah emas baru dan entitas sungai air yang diperkenalkan sekitar pukul 7.x saat ini tidak dapat diambil oleh skrip bot override total. Ini termasuk fitur yang lebih baru dari entitas bounty yang menumpuk di atas satu sama lain. Juga, hanya entitas bounty yang paling baru muncul yang dapat dikumpulkan. Solusi ada sebelum trombon perang pada pukul 0:00 untuk memungkinkan bot mengambilnya, namun, solusinya menyebabkan bot kehilangan kendali penuh atas inventaris mereka, sehingga dihapus setelah klakson sekitar pukul 0:30



## Status Proyek

Versi alpha. Tolong beri umpan balik.

Apakah proyek saat ini stabil: Stabil, tidak ada game crash atau skrip yang melanggar lebih dari 10 pertandingan pada 30/03/23 (30 Maret)

Pembaruan meta DotaBuff terakhir: Silakan periksa tanggal halaman lokakarya bahasa Inggris.



## Kontak dev

zyewchi@gmail.com

