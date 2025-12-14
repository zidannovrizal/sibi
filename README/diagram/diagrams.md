# Diagram yang Disarankan (bentuk, panah, dan instruksi gambar)

Legenda bentuk (pakai draw.io / diagrams.net):
- **Oval/pill** : Start / End.
- **Kotak** : Proses atau komponen.
- **Paralelogram** : Data / aset / model.
- **Belah ketupat (diamond)** : Keputusan / kondisi.
- **Swimlane** : Memisahkan dua versi pipeline.
- Panah **solid** : alur utama. Panah **putus-putus** : opsional / umpan balik / versi lain.

Tambahkan teks kecil di dalam kotak: contoh “threshold 0.10”, “buffer 24 frame @60 ms”, “bahu 5/6”.

---

## 1) High-Level Architecture (kiri → kanan)
Alur baca: mulai dari kotak Camera di kiri, ikuti panah solid ke kanan sampai UI. Paralelogram “Assets” di bawah memberi model/label ke plugin atau inference.
Susun kotak horizontal dengan panah solid ke kanan:
1) [Kotak] Camera (CameraController)  
→ 2) [Kotak] Plugin native `movenet_hands_bridge`  
→ 3) [Kotak] Feature Builder (CompactFeatureBuilder, 104 dim)  
→ 4) [Kotak] Inference (TfliteInferenceService, threshold 0.10)  
→ 5) [Kotak] UI (CameraWidget: status tangan, label, persen, kalimat)

Di bawah deretan ini, letakkan paralelogram “Assets”, lalu panah naik ke komponen yang memakai:
- MoveNet Thunder, Hand Landmarker → ke Plugin.
- Compact MLP, Labels, Scaler → ke Feature Builder / Inference.

## 2) Pipeline Landmark & Fitur (atas → bawah)
Alur baca: dari CameraImage (YUV) turun ke Plugin (YUV→Bitmap→MoveNet+Hands), lanjut ke Feature Builder (poin di dalam kotak), keluar vektor 104 dim, lalu Softmax 12 kelas, dan terakhir UI.
Urut vertikal dengan panah solid turun:
1) [Kotak] CameraImage (YUV420)  
2) [Kotak] Plugin: “YUV → Bitmap → MoveNet (17) + Hands (21×2) → LandmarkPacket”  
3) [Kotak] Feature Builder (isi teks poin):
   - Normalisasi bahu (idx 5/6)
   - Flat XY 10 titik tangan
   - Tip distances, thumb ratios
   - Posisi bahu, confidence tangan
   - Statistik temporal (active threshold 0.12)
   - Scaling mean/std (compact_scaler.json)
4) [Kotak] Output vektor 104 dim → [Kotak] Softmax 12 kelas (threshold 0.10)  
5) [Kotak] UI: label + persen + status tangan

## 3) Flow Inference & UI State (dengan keputusan)
Alur baca: oval Start → init → frame masuk → diamond “ada LandmarkPacket?” → kalau “No” kembali menunggu; kalau “Yes” lanjut build fitur → diamond fitur lengkap → jika tidak, “mengumpulkan data” lalu loop; jika ya, Softmax → diamond skor ≥ threshold → jika tidak, “confidence rendah” dan loop; jika ya, diamond label == idle → jika idle, reset kalimat dan loop; jika bukan, tambah token dan tampilkan hasil → loop ke frame berikutnya.
Gunakan oval untuk start, diamond untuk kondisi, kotak untuk proses, panah solid. Alur atas → bawah (boleh kiri → kanan).
- [Oval] Start → [Kotak] Init camera + bridge → [Kotak] Frame masuk
- [Diamond] Ada LandmarkPacket?  
  • No → [Kotak] “Menunggu deteksi tangan” → panah balik ke “Frame masuk”  
  • Yes → lanjut
- [Kotak] Build fitur 104 dim
- [Diamond] Fitur lengkap (len == expected)?  
  • No → [Kotak] “Mengumpulkan data” → balik  
  • Yes → lanjut
- [Kotak] Softmax
- [Diamond] Skor ≥ 0.10?  
  • No → [Kotak] “Confidence rendah / tampil label mentah” → balik  
  • Yes → lanjut
- [Diamond] Label == “idle”?  
  • Yes → [Kotak] Reset kalimat & history → panah balik ke “Frame masuk”  
  • No → [Kotak] Tambah token ke kalimat → [Kotak] Tampilkan label + persen + kalimat → panah balik ke “Frame masuk”

## 4) Integrasi Aset & Build (klaster)
Alur baca: mulai dari paralelogram aset `assets/currently_use/`, panah ke masing-masing komponen (Plugin atau Feature/Inference). Pubspec menunjuk ke aset. Build di bagian bawah sebagai catatan rilis.
Letakkan klaster aset di kiri, panah ke komponen pemakai di kanan:
- [Paralelogram] `assets/currently_use/`
  - movenet_thunder.tflite, hand_landmarker.task → panah ke Plugin
  - sibi_compact_mlp.tflite, sibi_compact_labels.json, compact_scaler.json → panah ke Feature Builder / Inference
- [Kotak kecil] pubspec.yaml (deklarasi assets) → panah ke klaster aset
- [Kotak] Build (debug / release split-per-ABI) di bawah sebagai catatan opsional

## 5) Perbandingan Pipeline (swimlane dua kolom)
Alur baca: baca swimlane A (aktif) dari atas ke bawah, lalu swimlane B (arsip) dari atas ke bawah. Panah putus-putus di tengah menunjukkan perbedaan/evolusi antara keduanya (fitur, model, threshold, aset).
Buat dua swimlane berdampingan, panah solid vertikal dalam tiap swimlane, panah putus-putus di antara lane untuk menunjukkan evolusi.
- Swimlane A (aktif): compact 104 dim, 12 kelas, threshold 0.10, assets `currently_use/`.
  - Kotak berurutan: Backbone → Fitur → Scaler → Inference → Labels (12) → Threshold (0.10).
- Swimlane B (arsip): pipeline lama (38 kelas / sequence lama).
  - Kotak berurutan: Backbone → Fitur → Scaler → Inference → Labels (38) → Threshold (0.10 atau 0.03 sesuai arsip).
- Panah putus-putus dari A ke B untuk tunjukkan perbedaan kelas, aset, threshold.

---

Tips menggambar cepat:
- Gunakan panah satu arah (kiri → kanan atau atas → bawah).  
- Loop/reset (idle) gunakan panah kembali ke node “Frame masuk” atau “Kalimat”.  
- Jika bingung bentuk: Start/End = oval, Proses = kotak, Data = paralelogram, Keputusan = diamond.  
- Untuk versi ringkas, diagram 1 dan 3 sudah cukup; diagram 2 dipakai jika perlu detail feature-engineering. 
