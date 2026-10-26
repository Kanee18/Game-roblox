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

--------------------------------------------------------------------------------
-- TAHAP 3 · CABLE LABYRINTH — Perangkat Keras Jaringan
-- Mesin Pusat menjelaskan FUNGSI/CIRI perangkat; siswa harus tahu namanya,
-- lalu mencarinya di labirin. Correct = Id perangkat (lihat GameConfig.Stage3.Items).
-- Tidak perlu jawaban salah: semua perangkat lain di labirin adalah pengecohnya.
--------------------------------------------------------------------------------
QuizBank.Stage3 = {
	{
		Question = "Bawakan perangkat yang menghubungkan dua jaringan berbeda dan menentukan jalur terbaik untuk data!",
		Correct = "Router",
		Explanation = "Router bekerja seperti polisi lalu lintas data: menghubungkan jaringan yang berbeda dan memilih jalur terbaik.",
	},
	{
		Question = "Bawakan perangkat yang menghubungkan banyak komputer dalam satu LAN dan mengirim data HANYA ke komputer tujuan!",
		Correct = "Switch",
		Explanation = "Switch itu 'pintar': ia mengenali alamat tujuan sehingga data hanya dikirim ke port yang tepat.",
	},
	{
		Question = "Bawakan perangkat yang mengubah sinyal digital menjadi analog (dan sebaliknya) agar rumah bisa tersambung ke Internet!",
		Correct = "Modem",
		Explanation = "Modem = MOdulator-DEModulator. Ia mengubah sinyal agar data dari komputer bisa dikirim lewat jalur penyedia internet.",
	},
	{
		Question = "Bawakan perangkat yang memancarkan sinyal Wi-Fi agar laptop dan ponsel bisa terhubung tanpa kabel!",
		Correct = "AccessPoint",
		Explanation = "Access Point memancarkan sinyal nirkabel (Wi-Fi) sehingga perangkat bisa masuk ke jaringan tanpa kabel.",
	},
	{
		Question = "Bawakan kabel jaringan berisi 4 pasang kabel tembaga yang dipilin, yang paling sering dipakai di LAN!",
		Correct = "KabelUTP",
		Explanation = "UTP = Unshielded Twisted Pair: 8 kabel tembaga yang dipilin berpasangan untuk mengurangi gangguan sinyal.",
	},
	{
		Question = "Bawakan konektor kotak bening dengan 8 pin yang dipasang di ujung kabel UTP!",
		Correct = "RJ45",
		Explanation = "RJ-45 adalah konektor 8 pin di ujung kabel UTP. Ujung inilah yang dicolokkan ke komputer atau switch.",
	},
	{
		Question = "Bawakan kabel yang mengirim data menggunakan CAHAYA, sangat cepat, dan bisa menjangkau jarak sangat jauh!",
		Correct = "FiberOptik",
		Explanation = "Kabel fiber optik berisi serat kaca/plastik tipis yang mengalirkan cahaya. Sangat cepat dan tidak terganggu listrik.",
	},
	{
		Question = "Bawakan kartu yang dipasang di dalam komputer agar komputer punya port dan bisa terhubung ke jaringan!",
		Correct = "NIC",
		Explanation = "NIC (Network Interface Card) atau kartu jaringan adalah 'pintu' komputer menuju jaringan.",
	},
	{
		Question = "Bawakan kabel dengan inti tembaga di tengah dan pelindung logam, yang biasa dipakai untuk antena TV!",
		Correct = "Coaxial",
		Explanation = "Kabel coaxial punya inti tembaga, lapisan isolator, dan pelindung logam. Dulu juga dipakai pada jaringan komputer lama.",
	},
	{
		Question = "Bawakan komputer bertenaga besar yang menyediakan layanan, misalnya website atau penyimpanan file, untuk komputer lain!",
		Correct = "Server",
		Explanation = "Server melayani permintaan dari komputer lain (client), misalnya menyimpan dan mengirim halaman website.",
	},
	{
		Question = "Bawakan perangkat penghubung sederhana yang mengirim data ke SEMUA port sekaligus!",
		Correct = "Hub",
		Explanation = "Hub tidak bisa memilih tujuan, jadi data dikirim ke semua komputer. Karena itu jaringan dengan hub lebih lambat daripada switch.",
	},
	{
		Question = "Di rumah, perangkat ini biasanya dipasang oleh penyedia internet (ISP) untuk menyambungkan jaringan rumah ke Internet. Bawakan!",
		Correct = "Modem",
		Explanation = "Modem dipasang oleh ISP sebagai penghubung antara jaringan rumah dan jaringan Internet milik penyedia layanan.",
	},
	{
		Question = "Ujung kabel UTP harus dipasangi benda ini sebelum dicolokkan ke switch atau komputer. Bawakan benda itu!",
		Correct = "RJ45",
		Explanation = "Kabel UTP dipasangi konektor RJ-45 dengan alat crimping, lalu siap dicolokkan ke port LAN.",
	},
	{
		Question = "Kamu ingin menghubungkan 20 komputer lab dalam satu LAN berkabel. Bawakan perangkat pusat yang paling tepat!",
		Correct = "Switch",
		Explanation = "Switch punya banyak port dan mengirim data secara efisien, sehingga cocok sebagai pusat jaringan LAN di lab.",
	},
	{
		Question = "Jaringan antarpulau dan bawah laut memakai kabel ini karena sangat cepat dan tahan gangguan listrik. Bawakan!",
		Correct = "FiberOptik",
		Explanation = "Kabel serat optik bawah laut menghubungkan pulau dan negara, termasuk Indonesia, ke jaringan Internet dunia.",
	},
	{
		Question = "Tanpa perangkat ini, komputer tidak punya 'pintu' untuk masuk ke jaringan. Bawakan!",
		Correct = "NIC",
		Explanation = "Setiap perangkat yang terhubung ke jaringan butuh NIC, baik kartu jaringan berkabel maupun Wi-Fi.",
	},
	{
		Question = "Sekolah membagi koneksi internet ke jaringan lab dan jaringan kantor guru. Bawakan perangkat 'polisi lalu lintas' datanya!",
		Correct = "Router",
		Explanation = "Router menghubungkan beberapa jaringan sekaligus dan mengarahkan data ke jaringan yang benar.",
	},
	{
		Question = "Agar siswa bisa memakai Wi-Fi di perpustakaan yang jauh dari ruang server, sekolah memasang perangkat ini. Bawakan!",
		Correct = "AccessPoint",
		Explanation = "Access Point tambahan memperluas jangkauan Wi-Fi ke ruangan yang jauh.",
	},
	{
		Question = "Website sekolah disimpan dan dijalankan pada perangkat ini agar bisa diakses dari mana saja. Bawakan!",
		Correct = "Server",
		Explanation = "Website disimpan di server yang selalu menyala dan terhubung ke Internet.",
	},
	{
		Question = "Bawakan kabel yang memiliki pasangan warna oranye, hijau, biru, dan cokelat yang saling dipilin!",
		Correct = "KabelUTP",
		Explanation = "Di dalam kabel UTP ada 4 pasang kabel berwarna: oranye, hijau, biru, dan cokelat (masing-masing dengan pasangan putih).",
	},
	{
		Question = "Bawakan kabel bulat hitam dengan konektor logam berulir yang sering ditemukan di belakang televisi!",
		Correct = "Coaxial",
		Explanation = "Kabel antena TV adalah kabel coaxial. Konektornya biasanya logam yang diputar atau ditancapkan.",
	},
	{
		Question = "Bawakan perangkat lama yang mirip switch, tetapi membuat jaringan lebih lambat karena data dikirim ke semua komputer!",
		Correct = "Hub",
		Explanation = "Hub mengirim data ke semua port (broadcast), sehingga jalur cepat penuh. Kini hub sudah banyak digantikan switch.",
	},
}

-- Penjelasan singkat setiap perangkat, ditampilkan saat siswa membawa perangkat yang SALAH.
QuizBank.Stage3Info = {
	Router = "Router menghubungkan jaringan yang berbeda dan memilih jalur terbaik untuk data.",
	Switch = "Switch menghubungkan banyak perangkat dalam satu LAN dan mengirim data hanya ke tujuannya.",
	Hub = "Hub menghubungkan beberapa perangkat, tetapi mengirim data ke semua port sekaligus.",
	Modem = "Modem mengubah sinyal digital ↔ analog untuk tersambung ke penyedia internet (ISP).",
	AccessPoint = "Access Point memancarkan sinyal Wi-Fi agar perangkat bisa terhubung tanpa kabel.",
	KabelUTP = "Kabel UTP berisi 4 pasang kabel tembaga terpilin, umum dipakai di jaringan LAN.",
	RJ45 = "RJ-45 adalah konektor 8 pin di ujung kabel UTP.",
	FiberOptik = "Fiber optik mengirim data dengan cahaya: sangat cepat dan bisa sangat jauh.",
	NIC = "NIC (kartu jaringan) membuat komputer bisa terhubung ke jaringan.",
	Coaxial = "Kabel coaxial punya inti tembaga dan pelindung logam, sering dipakai untuk antena TV.",
	Server = "Server adalah komputer yang menyediakan layanan atau data untuk komputer lain.",
}
--------------------------------------------------------------------------------
-- TAHAP 4 · BANDWIDTH GLIDER — Kecepatan Internet & Koneksi
-- Dibaca sambil terbang: buat soal sesingkat mungkin.
-- Hanya ada 2 cincin (A/B), jadi cukup 1 jawaban salah. Jika lebih, dipilih acak.
--------------------------------------------------------------------------------
QuizBank.Stage4 = {
	{
		Question = "Satuan kecepatan internet adalah …",
		Correct = "bps (bit per detik)",
		Wrong = { "km/jam", "Volt", "Celsius" },
		Explanation = "Kecepatan internet diukur dalam bit per detik (bps), misalnya Mbps = megabit per detik.",
	},
	{
		Question = "Mana yang lebih CEPAT?",
		Correct = "100 Mbps",
		Wrong = { "10 Mbps", "1 Mbps", "512 Kbps" },
		Explanation = "Semakin besar angka Mbps, semakin banyak data yang mengalir setiap detik.",
	},
	{
		Question = "Kapasitas maksimal data yang bisa dikirim per detik disebut …",
		Correct = "Bandwidth",
		Wrong = { "Password", "Hardware", "Browser" },
		Explanation = "Bandwidth itu seperti lebar jalan: makin lebar, makin banyak data yang bisa lewat sekaligus.",
	},
	{
		Question = "Video berhenti sebentar untuk memuat data disebut …",
		Correct = "Buffering",
		Wrong = { "Booting", "Typing", "Printing" },
		Explanation = "Buffering terjadi saat data datang lebih lambat daripada kecepatan video diputar.",
	},
	{
		Question = "Waktu tunda data pergi-pulang (dalam ms) disebut …",
		Correct = "Ping / latensi",
		Wrong = { "Bandwidth", "Resolusi", "Megapiksel" },
		Explanation = "Ping (latensi) adalah waktu tempuh data pergi-pulang. Makin kecil, makin responsif.",
	},
	{
		Question = "Untuk game online, ping yang lebih baik adalah …",
		Correct = "20 ms",
		Wrong = { "500 ms", "900 ms" },
		Explanation = "Ping kecil berarti jeda kecil. 20 ms jauh lebih responsif daripada 500 ms.",
	},
	{
		Question = "Jaringan seluler yang paling cepat adalah …",
		Correct = "5G",
		Wrong = { "3G", "2G", "EDGE" },
		Explanation = "Makin baru generasinya, makin cepat: 2G < 3G < 4G < 5G.",
	},
	{
		Question = "Media kabel yang paling cepat untuk internet adalah …",
		Correct = "Fiber optik",
		Wrong = { "Kabel telepon", "Kabel listrik" },
		Explanation = "Fiber optik mengirim data dengan cahaya, jauh lebih cepat daripada kabel tembaga.",
	},
	{
		Question = "Jika banyak orang memakai satu Wi-Fi bersamaan, internet jadi …",
		Correct = "Lebih lambat",
		Wrong = { "Lebih cepat", "Tidak berubah" },
		Explanation = "Bandwidth dibagi ke semua pengguna, jadi bagian tiap orang makin kecil.",
	},
	{
		Question = "1 Byte sama dengan …",
		Correct = "8 bit",
		Wrong = { "10 bit", "2 bit", "1000 bit" },
		Explanation = "1 byte = 8 bit. Ingat: B besar = Byte, b kecil = bit.",
	},
	{
		Question = "File 100 MB diunduh dengan internet 8 Mbps. Lamanya sekitar …",
		Correct = "100 detik",
		Wrong = { "1 detik", "1 jam" },
		Explanation = "100 MB = 800 Mb (1 byte = 8 bit). 800 Mb ÷ 8 Mbps = 100 detik.",
	},
	{
		Question = "Mengambil file dari internet ke perangkat kita disebut …",
		Correct = "Download",
		Wrong = { "Upload", "Restart" },
		Explanation = "Download (unduh): internet → perangkat. Upload (unggah): perangkat → internet.",
	},
	{
		Question = "Mengirim video dari ponsel ke media sosial disebut …",
		Correct = "Upload",
		Wrong = { "Download", "Format" },
		Explanation = "Upload berarti mengirim data dari perangkat kita ke internet.",
	},
	{
		Question = "Sinyal Wi-Fi paling kuat jika kita berada …",
		Correct = "Dekat router",
		Wrong = { "Di balik tembok tebal", "Di ruang bawah tanah" },
		Explanation = "Jarak dan penghalang seperti tembok melemahkan sinyal Wi-Fi.",
	},
	{
		Question = "Satuan yang lebih BESAR dari Mbps adalah …",
		Correct = "Gbps",
		Wrong = { "Kbps", "bps" },
		Explanation = "Urutannya bps < Kbps < Mbps < Gbps, dan setiap tingkat ×1000.",
	},
	{
		Question = "Kuota internet dihitung dalam satuan …",
		Correct = "GB (gigabyte)",
		Wrong = { "Mbps", "Volt", "Meter" },
		Explanation = "Kuota = jumlah data (GB). Kecepatan = laju data (Mbps). Keduanya berbeda!",
	},
	{
		Question = "Internet satelit paling cocok untuk daerah …",
		Correct = "Terpencil",
		Wrong = { "Pusat kota", "Gedung server" },
		Explanation = "Satelit menjangkau daerah terpencil yang belum terjangkau kabel atau menara seluler.",
	},
	{
		Question = "Aplikasi untuk mengukur kecepatan internet disebut …",
		Correct = "Speed test",
		Wrong = { "Antivirus", "Kalkulator" },
		Explanation = "Speed test mengukur kecepatan download, upload, dan ping.",
	},
	{
		Question = "Video kualitas 4K butuh bandwidth yang …",
		Correct = "Lebih besar",
		Wrong = { "Lebih kecil", "Nol" },
		Explanation = "Video beresolusi tinggi berisi lebih banyak data per detik, jadi butuh bandwidth lebih besar.",
	},
	{
		Question = "Bluetooth cocok untuk perangkat yang …",
		Correct = "Berjarak dekat",
		Wrong = { "Beda negara", "Beda kota" },
		Explanation = "Bluetooth adalah koneksi nirkabel jarak pendek (sekitar 10 meter).",
	},
}

return QuizBank
