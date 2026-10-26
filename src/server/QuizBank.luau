--[[
	QuizBank (ModuleScript)
	Lokasi: ServerScriptService > QuizBank

	Bank soal semua tahap. Disimpan di ServerScriptService (BUKAN di
	ReplicatedStorage) supaya kunci jawaban tidak pernah terkirim ke
	komputer siswa dan tidak bisa diintip dengan program curang.

	Format satu soal:
		{
			Question = "Teks pertanyaan …",
			Correct = "Jawaban benar",
			Wrong = { "Jawaban salah 1", "Jawaban salah 2" }, -- minimal 2 (untuk 3 pintu)
			Explanation = "Penjelasan singkat yang muncul setelah menjawab.",
		}

	Tips menulis soal:
	  * Jawaban pendek (maksimal ±25 huruf) supaya terbaca jelas di papan pintu.
	  * Buat jawaban salah yang masuk akal dan panjangnya mirip jawaban benar.
	  * Urutan jawaban diacak otomatis untuk setiap siswa.
]]

local QuizBank = {}

--------------------------------------------------------------------------------
-- TAHAP 1 · ROUTING RUNNER — Dasar Jaringan & LAN/WAN
--------------------------------------------------------------------------------
QuizBank.Stage1 = {
	{
		Question = "Dua komputer atau lebih yang saling terhubung untuk berbagi data dan sumber daya disebut …",
		Correct = "Jaringan komputer",
		Wrong = { "Sistem operasi", "Perangkat lunak", "Basis data" },
		Explanation = "Jaringan komputer adalah kumpulan perangkat yang saling terhubung sehingga bisa bertukar data dan berbagi sumber daya.",
	},
	{
		Question = "Jaringan yang mencakup area kecil seperti rumah, lab komputer, atau satu gedung sekolah disebut …",
		Correct = "LAN",
		Wrong = { "WAN", "MAN" },
		Explanation = "LAN (Local Area Network) mencakup area terbatas, misalnya satu rumah, satu ruangan, atau satu gedung.",
	},
	{
		Question = "Jaringan yang mencakup wilayah sangat luas, antarnegara bahkan antarbenua, disebut …",
		Correct = "WAN",
		Wrong = { "LAN", "PAN" },
		Explanation = "WAN (Wide Area Network) menghubungkan perangkat di wilayah sangat luas: antarkota, antarnegara, hingga antarbenua.",
	},
	{
		Question = "Jaringan yang mencakup satu kota, misalnya jaringan antarkantor cabang bank dalam satu kota, disebut …",
		Correct = "MAN",
		Wrong = { "LAN", "PAN" },
		Explanation = "MAN (Metropolitan Area Network) cakupannya lebih luas dari LAN, kira-kira seluas satu kota.",
	},
	{
		Question = "Kepanjangan dari LAN adalah …",
		Correct = "Local Area Network",
		Wrong = { "Large Area Network", "Long Access Network" },
		Explanation = "LAN = Local Area Network. Kata 'local' berarti setempat, yaitu area yang kecil.",
	},
	{
		Question = "Kepanjangan dari WAN adalah …",
		Correct = "Wide Area Network",
		Wrong = { "Wireless Area Network", "World Access Network" },
		Explanation = "WAN = Wide Area Network. Kata 'wide' berarti luas.",
	},
	{
		Question = "Contoh jaringan WAN terbesar di dunia adalah …",
		Correct = "Internet",
		Wrong = { "Intranet sekolah", "Bluetooth" },
		Explanation = "Internet menghubungkan jutaan jaringan di seluruh dunia, sehingga menjadi WAN terbesar.",
	},
	{
		Question = "Ponsel yang terhubung ke earphone nirkabel di sekitar tubuh kita membentuk jaringan …",
		Correct = "PAN",
		Wrong = { "MAN", "WAN" },
		Explanation = "PAN (Personal Area Network) adalah jaringan pribadi berjarak sangat dekat, contohnya ponsel dengan earphone Bluetooth.",
	},
	{
		Question = "Jaringan komputer di laboratorium komputer sekolahmu paling tepat disebut …",
		Correct = "LAN",
		Wrong = { "WAN", "MAN" },
		Explanation = "Lab komputer berada dalam satu ruangan atau gedung, jadi termasuk LAN.",
	},
	{
		Question = "Perusahaan dengan kantor di Jakarta, Tokyo, dan London saling terhubung. Jaringan ini termasuk …",
		Correct = "WAN",
		Wrong = { "LAN", "PAN" },
		Explanation = "Jaringan antarnegara mencakup wilayah sangat luas, sehingga termasuk WAN.",
	},
	{
		Question = "Semua komputer di lab bisa mencetak memakai satu printer bersama. Ini contoh manfaat jaringan, yaitu …",
		Correct = "Berbagi sumber daya",
		Wrong = { "Menambah memori", "Mencegah virus" },
		Explanation = "Dengan jaringan, perangkat seperti printer bisa dipakai bersama (resource sharing), jadi lebih hemat.",
	},
	{
		Question = "Berikut ini yang BUKAN manfaat jaringan komputer adalah …",
		Correct = "Komputer kebal virus",
		Wrong = { "Berbagi file dan data", "Komunikasi jadi mudah" },
		Explanation = "Jaringan memudahkan berbagi file dan berkomunikasi, tetapi tidak membuat komputer kebal virus. Virus justru bisa menyebar lewat jaringan!",
	},
	{
		Question = "Perangkat yang bertugas menentukan jalur terbaik untuk mengirim data antarjaringan adalah …",
		Correct = "Router",
		Wrong = { "Printer", "Proyektor" },
		Explanation = "Router seperti 'polisi lalu lintas' data: ia memilih jalur agar data sampai ke jaringan tujuan.",
	},
	{
		Question = "Proses memilih jalur yang dilalui data dari pengirim ke penerima disebut …",
		Correct = "Routing",
		Wrong = { "Printing", "Scanning" },
		Explanation = "Routing adalah proses menentukan jalur data. Itulah tugasmu di tahap Routing Runner ini!",
	},
	{
		Question = "Perusahaan yang menyediakan layanan koneksi internet bagi pelanggan disebut …",
		Correct = "ISP",
		Wrong = { "CPU", "USB" },
		Explanation = "ISP (Internet Service Provider) adalah penyedia jasa internet yang menghubungkan rumah atau sekolah ke Internet.",
	},
	{
		Question = "Saat dikirim melalui jaringan, data dipecah menjadi bagian-bagian kecil yang disebut …",
		Correct = "Paket data",
		Wrong = { "Folder data", "Kabel data" },
		Explanation = "Data dipecah menjadi paket-paket kecil, dikirim lewat jaringan, lalu disusun kembali di komputer tujuan.",
	},
	{
		Question = "Laptop, komputer, dan smartphone yang dipakai pengguna di ujung jaringan disebut …",
		Correct = "Perangkat akhir",
		Wrong = { "Media transmisi", "Perangkat lunak" },
		Explanation = "Perangkat akhir (end device) dipakai langsung oleh pengguna untuk mengirim dan menerima data.",
	},
	{
		Question = "Kabel dan gelombang radio yang menjadi jalan lewatnya data disebut …",
		Correct = "Media transmisi",
		Wrong = { "Perangkat akhir", "Sistem operasi" },
		Explanation = "Media transmisi adalah 'jalan' tempat data mengalir, bisa berupa kabel (UTP, fiber optik) atau nirkabel (gelombang radio).",
	},
	{
		Question = "Wi-Fi dan Bluetooth adalah contoh koneksi jaringan …",
		Correct = "Nirkabel",
		Wrong = { "Kabel UTP", "Fiber optik" },
		Explanation = "Wi-Fi dan Bluetooth mengirim data lewat gelombang radio tanpa kabel, sehingga disebut nirkabel (wireless).",
	},
	{
		Question = "Kata Internet berasal dari 'interconnected network', yang artinya …",
		Correct = "Jaringan saling terhubung",
		Wrong = { "Jaringan milik pribadi", "Jaringan tanpa kabel" },
		Explanation = "Internet adalah jaringan dari banyak jaringan yang saling terhubung di seluruh dunia.",
	},
	{
		Question = "Komputer yang menyediakan layanan, misalnya menyimpan halaman website, untuk komputer lain disebut …",
		Correct = "Server",
		Wrong = { "Client", "Keyboard" },
		Explanation = "Server melayani permintaan dari komputer lain. Saat kamu membuka website, datanya diambil dari server.",
	},
	{
		Question = "Komputer yang meminta layanan atau data dari server disebut …",
		Correct = "Client",
		Wrong = { "Router", "Switch" },
		Explanation = "Client (klien) adalah komputer yang meminta data, misalnya laptopmu saat membuka website.",
	},
	{
		Question = "Urutan jenis jaringan dari cakupan PALING KECIL ke PALING LUAS adalah …",
		Correct = "PAN – LAN – MAN – WAN",
		Wrong = { "WAN – MAN – LAN – PAN", "LAN – PAN – WAN – MAN" },
		Explanation = "PAN (pribadi) < LAN (gedung) < MAN (kota) < WAN (antarnegara).",
	},
	{
		Question = "Jaringan Wi-Fi di rumah yang menghubungkan laptop, ponsel, dan smart TV termasuk jenis …",
		Correct = "LAN",
		Wrong = { "WAN", "MAN" },
		Explanation = "Jaringan di dalam satu rumah mencakup area kecil, jadi termasuk LAN (disebut juga WLAN jika tanpa kabel).",
	},
}

--------------------------------------------------------------------------------
-- TAHAP 2 · FIREWALL DEFENDER — Keamanan Data & Virus
-- Setiap soal butuh minimal 3 jawaban salah (4 virus per gelombang).
-- Jawaban dibawa virus di atas kepalanya, jadi buat sependek mungkin.
--------------------------------------------------------------------------------
QuizBank.Stage2 = {
	{
		Question = "Program jahat yang dapat menggandakan diri dan merusak file di komputer disebut …",
		Correct = "Virus komputer",
		Wrong = { "Antivirus", "Firewall", "Browser" },
		Explanation = "Virus komputer adalah salah satu jenis malware (program jahat) yang menyebar dan bisa merusak atau mencuri data.",
	},
	{
		Question = "Aplikasi yang berfungsi mendeteksi dan menghapus virus disebut …",
		Correct = "Antivirus",
		Wrong = { "Malware", "Spam", "Trojan" },
		Explanation = "Antivirus memindai file untuk menemukan dan membersihkan program jahat. Selalu perbarui antivirusmu!",
	},
	{
		Question = "Sistem keamanan yang menyaring lalu lintas data masuk dan keluar jaringan disebut …",
		Correct = "Firewall",
		Wrong = { "Hotspot", "Spyware", "Bluetooth" },
		Explanation = "Firewall seperti satpam jaringan: memeriksa data yang lewat dan memblokir yang mencurigakan.",
	},
	{
		Question = "Manakah kata sandi (password) yang paling KUAT?",
		Correct = "B3l@jar!Jarkom7",
		Wrong = { "12345678", "password", "budi2012" },
		Explanation = "Password kuat itu panjang dan memadukan huruf besar, huruf kecil, angka, dan simbol.",
	},
	{
		Question = "Pesan atau situs palsu yang menyamar sebagai pihak resmi untuk mencuri password disebut …",
		Correct = "Phishing",
		Wrong = { "Streaming", "Browsing", "Upload" },
		Explanation = "Phishing memancing korban memasukkan data pribadi di situs atau pesan palsu. Periksa alamatnya dan jangan asal klik tautan!",
	},
	{
		Question = "Program jahat yang menyamar sebagai aplikasi berguna, padahal diam-diam merusak, disebut …",
		Correct = "Trojan",
		Wrong = { "Antivirus", "Firewall", "Driver" },
		Explanation = "Trojan (Kuda Troya) berpura-pura menjadi program baik agar dipasang sendiri oleh korbannya.",
	},
	{
		Question = "Malware yang mengunci file lalu meminta uang tebusan agar file bisa dibuka lagi disebut …",
		Correct = "Ransomware",
		Wrong = { "Freeware", "Shareware", "Firmware" },
		Explanation = "Ransomware menyandera data. Membuat backup secara rutin adalah pertahanan terbaik.",
	},
	{
		Question = "Program yang diam-diam memata-matai dan mengumpulkan informasi pengguna disebut …",
		Correct = "Spyware",
		Wrong = { "Hardware", "Brainware", "Firmware" },
		Explanation = "Spyware mengintip aktivitas dan data pribadi tanpa izin pemiliknya.",
	},
	{
		Question = "Mengubah data menjadi kode rahasia agar tidak bisa dibaca orang yang tidak berhak disebut …",
		Correct = "Enkripsi",
		Wrong = { "Kompresi", "Formatting", "Defragmentasi" },
		Explanation = "Enkripsi mengacak data menjadi sandi. Hanya pemilik kunci yang bisa membukanya kembali (dekripsi).",
	},
	{
		Question = "Membuat salinan data penting di tempat lain agar aman jika data asli rusak disebut …",
		Correct = "Backup",
		Wrong = { "Delete", "Format", "Restart" },
		Explanation = "Backup (cadangan) menjaga data tetap aman walaupun komputer rusak atau terkena virus.",
	},
	{
		Question = "Kode OTP yang dikirim ke ponsel saat login adalah contoh pengamanan …",
		Correct = "Verifikasi dua langkah",
		Wrong = { "Mode pesawat", "Mode gelap", "Hemat baterai" },
		Explanation = "Verifikasi dua langkah menambah lapisan keamanan: selain password, dibutuhkan kode dari ponselmu.",
	},
	{
		Question = "Seseorang meminta kode OTP yang masuk ke ponselmu. Apa yang harus kamu lakukan?",
		Correct = "Jangan berikan",
		Wrong = { "Berikan saja", "Kirim lewat chat", "Unggah ke medsos" },
		Explanation = "Kode OTP bersifat rahasia. Siapa pun yang memintanya patut dicurigai sebagai penipu.",
	},
	{
		Question = "Dari mana sebaiknya kita mengunduh aplikasi agar aman?",
		Correct = "Toko aplikasi resmi",
		Wrong = { "Tautan tak dikenal", "Iklan pop-up", "Pesan berantai" },
		Explanation = "Unduh aplikasi dari sumber resmi agar terhindar dari malware yang disisipkan.",
	},
	{
		Question = "Malware yang menyebar sendiri ke komputer lain melalui jaringan disebut …",
		Correct = "Worm",
		Wrong = { "Mouse", "Cookie", "Patch" },
		Explanation = "Worm (cacing) dapat menggandakan diri dan menyebar lewat jaringan dengan sangat cepat.",
	},
	{
		Question = "Manakah yang bisa menjadi tanda komputer terkena virus?",
		Correct = "Iklan aneh terus muncul",
		Wrong = { "Layar makin jernih", "Baterai makin awet", "Internet makin cepat" },
		Explanation = "Komputer melambat, iklan aneh bermunculan, atau file hilang bisa menjadi tanda infeksi malware.",
	},
	{
		Question = "Memperbarui (update) sistem operasi dan aplikasi secara rutin bertujuan untuk …",
		Correct = "Menutup celah keamanan",
		Wrong = { "Menghapus semua file", "Mengurangi memori", "Mematikan internet" },
		Explanation = "Update berisi perbaikan keamanan (patch) yang menutup celah yang bisa dimanfaatkan peretas.",
	},
	{
		Question = "Manakah data pribadi yang TIDAK boleh disebarkan sembarangan?",
		Correct = "NIK & alamat rumah",
		Wrong = { "Judul lagu favorit", "Warna kesukaan", "Nama tokoh kartun" },
		Explanation = "Data pribadi seperti NIK, alamat, dan nomor telepon bisa disalahgunakan jika disebarkan.",
	},
	{
		Question = "Setelah selesai memakai komputer di lab sekolah, sebaiknya kamu …",
		Correct = "Log out dari akunmu",
		Wrong = { "Biarkan akun terbuka", "Tulis password di meja", "Bagikan password" },
		Explanation = "Selalu keluar (log out) dari akun di komputer umum agar akunmu tidak dipakai orang lain.",
	},
	{
		Question = "Alamat situs yang lebih aman untuk memasukkan data biasanya diawali dengan …",
		Correct = "https://",
		Wrong = { "http://", "ftp://", "file://" },
		Explanation = "HTTPS (ditandai ikon gembok) berarti data yang dikirim ke situs tersebut dienkripsi.",
	},
	{
		Question = "Pesan massal yang tidak diinginkan, sering berisi iklan atau tautan berbahaya, disebut …",
		Correct = "Spam",
		Wrong = { "Spreadsheet", "Stiker", "Server" },
		Explanation = "Spam adalah pesan sampah yang dikirim massal. Jangan klik tautan di dalamnya!",
	},
	{
		Question = "Orang yang membobol sistem komputer orang lain tanpa izin untuk berbuat jahat disebut …",
		Correct = "Cracker",
		Wrong = { "Admin jaringan", "Teknisi resmi", "Operator sekolah" },
		Explanation = "Cracker (peretas jahat) membobol sistem tanpa izin. Perbuatan ini melanggar hukum (UU ITE).",
	},
	{
		Question = "Cara menjaga password yang BENAR adalah …",
		Correct = "Rahasiakan & ganti berkala",
		Wrong = { "Tulis di papan kelas", "Sama untuk semua akun", "Bagikan ke teman" },
		Explanation = "Jaga kerahasiaan password, gunakan password berbeda untuk tiap akun, dan ganti secara berkala.",
	},
}

-- QuizBank.Stage3 = { ... } -- Cable Labyrinth
-- QuizBank.Stage4 = { ... } -- Bandwidth Glider

return QuizBank
