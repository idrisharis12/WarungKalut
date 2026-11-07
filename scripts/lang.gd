class_name Lang
extends RefCounted

# English text is the key. Bahasa Melayu replacements; anything missing falls back to English.
const MS := {
	"START": "MULA", "Training": "Latihan", "Settings": "Tetapan", "Quit": "Keluar", "Back": "Kembali",
	"Cookbook": "Buku Resipi", "Players: 1": "Pemain: 1", "Cook in chaos. Learn Malaysian food.": "Masak kelam-kabut. Kenali makanan Malaysia.",
	"New here? Try Training first!": "Baru? Cuba Latihan dahulu!", "Select Level": "Pilih Peringkat", "Play": "Main", "Locked": "Berkunci",
	"Level %d": "Peringkat %d", "BOSS": "BOS",
	"Paused": "Jeda", "Resume": "Sambung", "Recipe Book": "Buku Resipi", "Restart": "Mula Semula", "Quit to Menu": "Ke Menu",
	"Done": "Siap", "Reset to defaults": "Tetapan asal", "Player 1": "Pemain 1", "Player 2": "Pemain 2", "General": "Umum",
	"Controls": "Kawalan", "Display": "Paparan", "Audio and Look": "Rupa", "Language": "Bahasa", "UI size": "Saiz UI", "Text size": "Saiz teks",
	"Colour-blind mode": "Mod buta warna", "Always show help bar": "Sentiasa tunjuk bantuan", "Chef style": "Gaya chef", "Hat": "Topi",
	"Move": "Gerak", "Pick / put": "Ambil / letak", "Chop / mix / wash": "Potong / kacau / basuh", "Hold run / Tap dash": "Tahan lari / Tekan terjah",
	"Recipes": "Resipi", "Pause": "Jeda", "Help": "Bantuan",
	"Take": "Ambil", "Pick up": "Angkat", "Chop (tap)": "Potong (tekan)", "Mix (hold)": "Kacau (tahan)", "Wash (hold)": "Basuh (tahan)",
	"Pull (tap)": "Tarik (tekan)", "Put out (hold)": "Padam (tahan)", "Serve": "Hidang", "Throw away": "Buang", "Put in wok": "Letak dalam kuali",
	"Put in sink": "Letak dalam sinki", "Put on board": "Letak atas papan", "Put in mixer": "Letak dalam pengacau", "Put in pot": "Letak dalam periuk",
	"Put under kettle": "Letak bawah cerek", "Put down": "Letak", "Add to plate": "Tambah ke pinggan", "Shoo cat": "Halau kucing",
	"CHOP": "POTONG", "MIX": "KACAU", "FRY": "GORENG", "BOIL": "REBUS", "SERVE": "HIDANG", "WASH": "BASUH", "TRASH": "SAMPAH",
	"PULL TEA": "TARIK TEH", "PLATES": "PINGGAN", "DIRTY": "KOTOR", "BATTER": "ADUNAN", "CHICKEN": "AYAM", "SHALLOT": "BAWANG",
	"RICE": "NASI", "ANCHOVY": "IKAN BILIS", "CUCUMBER": "TIMUN", "SAMBAL": "SAMBAL", "GLASS": "GELAS", "NOODLES": "MEE", "PRAWN": "UDANG", "TOFU": "TAUHU",
	"Malaysia Meter": "Meter Malaysia", "Wrong dish": "Hidangan salah", "Too slow! Order expired": "Lambat! Tempahan tamat",
	"YOU WIN!": "ANDA MENANG!", "BUSTED!": "DITANGKAP!", "Next level": "Peringkat seterusnya", "Retry": "Cuba lagi", "Menu": "Menu",
	"New dish!": "Hidangan baru!", "Start  (E)": "Mula  (E)", "Score": "Skor", "Time": "Masa",
	"FIRE! Hold Q to put it out": "API! Tahan Q untuk padam", "Power cut!": "Elektrik terputus!", "Oil spill!": "Minyak tumpah!",
	"A cat is on the counter!": "Kucing atas kaunter!", "The food critic is here!": "Pengkritik makanan tiba!", "Rush hour!": "Waktu sibuk!",
	"Achievement unlocked": "Pencapaian dibuka", "Achievements": "Pencapaian", "Dishes learned": "Hidangan dipelajari", "Save share card": "Simpan kad kongsi",
	"Favourites": "Kegemaran", "All": "Semua", "Search ingredient or dish": "Cari bahan atau hidangan", "Press B to close": "Tekan B untuk tutup",
	"Skip": "Langkau", "Walk around": "Berjalan", "Run": "Lari", "Dash": "Terjah", "Grab batter": "Ambil adunan", "Mix it": "Kacau",
	"Take the batter": "Ambil adunan", "Set it down": "Letakkan", "Fry chicken": "Goreng ayam", "Plate it": "Letak atas pinggan",
	"Use these keys to move around the kitchen.": "Guna kekunci ini untuk bergerak di dapur.",
	"HOLD Shift while you move to run.": "TAHAN Shift semasa bergerak untuk berlari.",
	"TAP Shift once to dash and hop. It recharges fast.": "TEKAN Shift sekali untuk terjah dan melompat.",
	"Walk to the green BATTER crate and take some.": "Pergi ke peti ADUNAN hijau dan ambil sedikit.",
	"Put the batter in the MIXER, then HOLD the work key until the bar is full.": "Letak adunan dalam PENGACAU, kemudian TAHAN kekunci kerja sehingga bar penuh.",
	"Pick the mixed batter up from the mixer.": "Angkat adunan yang siap dari pengacau.",
	"Put the batter on any counter for now.": "Letak adunan di atas mana-mana kaunter.",
	"Take chicken from its crate and put it in the WOK. Take it out when it is golden, before it burns.": "Ambil ayam dan letak dalam KUALI. Angkat bila keemasan, sebelum hangus.",
	"Take a clean plate. Then stand next to the food and press the pick key to add each item to the plate.": "Ambil pinggan bersih. Berdiri di sebelah makanan dan tekan kekunci ambil untuk menambah ke pinggan.",
	"Carry the finished Roti Jala to the SERVE hatch on the right wall. The order is on the ticket.": "Bawa Roti Jala ke tingkap HIDANG di dinding kanan. Tempahan ada pada tiket.",
	"Siap!": "Siap!",
}

const SHOUTS := {
	"served": ["Siap!", "Done!"],
	"fire": ["Panas!", "Hot!"],
	"bad": ["Aiyo!", "Oh no!"],
	"combo": ["Mantap!", "Awesome!"],
}


static func t(s: String) -> String:
	if Prefs.lang == "ms" and MS.has(s):
		return MS[s]
	return s
