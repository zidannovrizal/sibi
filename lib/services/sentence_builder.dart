import 'dart:async';

/// Menyusun kata menjadi kalimat singkat dengan batas kata dan timeout.
class SentenceBuilder {
  SentenceBuilder({
    this.maxWords = 3,
    this.timeout = const Duration(seconds: 3),
    this.minConfidence = 0.05,
  });

  final int maxWords;
  final Duration timeout;
  final double minConfidence;

  final List<String> _words = <String>[];
  DateTime? _lastAddedAt;

  /// Tambah kata jika confidence cukup dan belum timeout.
  /// Mengembalikan kalimat saat ini (gabungan kata).
  String addWord(String rawWord, double confidence) {
    final now = DateTime.now();

    // Reset jika sudah melewati timeout.
    if (_lastAddedAt != null && now.difference(_lastAddedAt!) > timeout) {
      _words.clear();
    }

    if (confidence < minConfidence) {
      return currentPhrase;
    }

    final word = rawWord.trim().toLowerCase();
    if (word.isEmpty) {
      return currentPhrase;
    }

    // Hindari duplikasi berturut-turut.
    if (_words.isNotEmpty && _words.last == word) {
      _lastAddedAt = now;
      return currentPhrase;
    }

    // Jika sudah penuh, buang kata paling awal (sliding window) agar urutan tetap logis.
    if (_words.length >= maxWords) {
      _words.removeAt(0);
    }

    // Jika kata sudah pernah muncul, pindahkan ke posisi paling akhir agar urutan terbaru lebih relevan.
    final existingIndex = _words.indexOf(word);
    if (existingIndex != -1) {
      _words.removeAt(existingIndex);
    }

    _words.add(word);
    _lastAddedAt = now;
    return currentPhrase;
  }

  /// Periksa timeout tanpa menambah kata; reset jika lewat.
  void tick() {
    if (_lastAddedAt == null) return;
    if (DateTime.now().difference(_lastAddedAt!) > timeout) {
      _words.clear();
      _lastAddedAt = null;
    }
  }

  /// Menghapus semua kata.
  void reset() {
    _words.clear();
    _lastAddedAt = null;
  }

  String get currentPhrase => _words.join(' ');
  int get wordCount => _words.length;
}
