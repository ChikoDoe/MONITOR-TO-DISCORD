**🟢 Cara Pakai**
1. Simpan script
nano /root/monitor.sh


Paste semua isi script → save.

2. Bikin executable
chmod +x /root/monitor.sh

3. Tambah cronjob (jalan tiap menit)
* * * * * /root/monitor.sh

**🟢 Cara kerja**
🔹 Tiap menit:

Hitung selisih RX/TX → akumulasi

Hitung CPU max & average

Simpan ke file JSON

🔹 Tepat jam 00:00:

Ambil total inbound/outbound 24 jam

Kirim laporan ke Discord

Reset data → hari baru
