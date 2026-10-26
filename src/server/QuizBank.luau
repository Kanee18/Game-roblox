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

-- QuizBank.Stage2 = { ... } -- Firewall Defender (langkah berikutnya)
-- QuizBank.Stage3 = { ... } -- Cable Labyrinth
-- QuizBank.Stage4 = { ... } -- Bandwidth Glider

return QuizBank
