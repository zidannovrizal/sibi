import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/camera_provider.dart';

class SibiVocabularyWidget extends StatefulWidget {
  const SibiVocabularyWidget({super.key});

  @override
  State<SibiVocabularyWidget> createState() => _SibiVocabularyWidgetState();
}

class _SibiVocabularyWidgetState extends State<SibiVocabularyWidget> {
  Map<String, dynamic> _learningProgress = {};
  Map<String, List<String>> _vocabularyCategories = {};
  List<Map<String, dynamic>> _recentWords = [];
  Map<String, bool> _expandedCategories = {};
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    final cameraProvider = context.read<CameraProvider>();

    _recentWords = _generateRecentWords();
    setState(() {});
  }

  List<Map<String, dynamic>> _generateRecentWords() {
    final words = [
      {
        'word': 'Halo',
        'meaning': 'Hello',
        'category': 'Sapaan',
        'difficulty': 'Mudah',
        'progress': 0.9,
      },
      {
        'word': 'Terima Kasih',
        'meaning': 'Thank You',
        'category': 'Ucapan',
        'difficulty': 'Mudah',
        'progress': 0.85,
      },
      {
        'word': 'Selamat Pagi',
        'meaning': 'Good Morning',
        'category': 'Sapaan',
        'difficulty': 'Sedang',
        'progress': 0.7,
      },
      {
        'word': 'Apa Kabar?',
        'meaning': 'How Are You?',
        'category': 'Pertanyaan',
        'difficulty': 'Sedang',
        'progress': 0.6,
      },
      {
        'word': 'Sampai Jumpa',
        'meaning': 'Goodbye',
        'category': 'Perpisahan',
        'difficulty': 'Mudah',
        'progress': 0.8,
      },
      {
        'word': 'Tolong',
        'meaning': 'Please/Help',
        'category': 'Permintaan',
        'difficulty': 'Mudah',
        'progress': 0.75,
      },
    ];
    return words;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8F9FF),
      child: CustomScrollView(
        slivers: [
          // Modern header with gradient
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFFFF6B35), // Changed to orange
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFF6B35),
                      Color(0xFFFF8A65),
                      Color(0xFFFFA585),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Background pattern
                    Positioned(
                      right: -40,
                      top: -40,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      left: -20,
                      bottom: -20,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    // Content
                    const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.school, size: 40, color: Colors.white),
                          SizedBox(height: 12),
                          Text(
                            'Kosakata SIBI',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Pelajari bahasa isyarat Indonesia',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Learning progress section
                  _buildLearningProgress(),

                  const SizedBox(height: 24),

                  // Category section
                  const Text(
                    'Kategori Pembelajaran',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Cari kategori atau kata...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFFFF6B35), // Changed to orange
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                                icon: const Icon(
                                  Icons.clear,
                                  color: Colors.grey,
                                ),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category expandable list
                  _buildExpandableCategoryList(),

                  const SizedBox(height: 24),

                  // Recent words section
                  _buildRecentWords(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningProgress() {
    final progress = _learningProgress['progressPercentage'] ?? 0;
    final learnedWords = _learningProgress['learnedWords'] ?? 0;
    final practicingWords = _learningProgress['practicingWords'] ?? 0;
    final newWords = _learningProgress['newWords'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00C851), Color(0xFF00E676)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C851).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.trending_up,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progress Pembelajaran',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Terus tingkatkan kemampuan Anda',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Progress stats
          Row(
            children: [
              Expanded(
                child: _buildProgressStat(
                  icon: Icons.check_circle,
                  value: learnedWords.toString(),
                  label: 'Sudah Dipelajari',
                  color: Colors.white,
                ),
              ),
              Expanded(
                child: _buildProgressStat(
                  icon: Icons.school,
                  value: practicingWords.toString(),
                  label: 'Sedang Dipelajari',
                  color: Colors.white,
                ),
              ),
              Expanded(
                child: _buildProgressStat(
                  icon: Icons.add_circle,
                  value: newWords.toString(),
                  label: 'Belum Dipelajari',
                  color: Colors.white,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Progress bar
          Container(
            width: double.infinity,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$progress% Selesai',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.8),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildExpandableCategoryList() {
    final categories = [
      {
        'name': 'Sapaan',
        'icon': Icons.waving_hand,
        'color': const Color(0xFFFF6B35), // Changed to orange
        'words': _vocabularyCategories['Sapaan'] ?? [],
      },
      {
        'name': 'Ucapan',
        'icon': Icons.favorite,
        'color': const Color(0xFF00C851),
        'words': _vocabularyCategories['Ucapan'] ?? [],
      },
      {
        'name': 'Pertanyaan',
        'icon': Icons.help,
        'color': const Color(0xFFFF8C00),
        'words': _vocabularyCategories['Pertanyaan'] ?? [],
      },
      {
        'name': 'Perpisahan',
        'icon': Icons.waving_hand,
        'color': const Color(0xFFE91E63),
        'words': _vocabularyCategories['Perpisahan'] ?? [],
      },
      {
        'name': 'Permintaan',
        'icon': Icons.pan_tool,
        'color': const Color(0xFF9C27B0),
        'words': _vocabularyCategories['Permintaan'] ?? [],
      },
      {
        'name': 'Jawaban',
        'icon': Icons.check_circle,
        'color': const Color(0xFF795548),
        'words': _vocabularyCategories['Jawaban'] ?? [],
      },
    ];

    // Filter categories based on search query
    final filteredCategories = categories.where((category) {
      final categoryName = category['name'] as String;
      final words = category['words'] as List<String>;

      if (_searchQuery.isEmpty) return true;

      // Search in category name or words
      return categoryName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          words.any(
            (word) => word.toLowerCase().contains(_searchQuery.toLowerCase()),
          );
    }).toList();

    // If search is active, auto-expand categories that contain matching words
    if (_searchQuery.isNotEmpty) {
      for (final category in filteredCategories) {
        final categoryName = category['name'] as String;
        if (!_expandedCategories.containsKey(categoryName)) {
          _expandedCategories[categoryName] = true;
        }
      }
    }

    return Column(
      children: filteredCategories.map((category) {
        final categoryName = category['name'] as String;
        final words = category['words'] as List<String>;
        final isExpanded = _expandedCategories[categoryName] ?? false;

        // Filter words based on search query
        final filteredWords = _searchQuery.isEmpty
            ? words
            : words
                .where(
                  (word) =>
                      word.toLowerCase().contains(_searchQuery.toLowerCase()),
                )
                .toList();

        return _buildExpandableCategoryCard(
          name: categoryName,
          icon: category['icon'] as IconData,
          color: category['color'] as Color,
          words: filteredWords,
          isExpanded: isExpanded,
          onTap: () {
            setState(() {
              _expandedCategories[categoryName] = !isExpanded;
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildExpandableCategoryCard({
    required String name,
    required IconData icon,
    required Color color,
    required List<String> words,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              // Category header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          Text(
                            '${words.length} kata tersedia',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: color,
                      size: 24,
                    ),
                  ],
                ),
              ),

              // Expandable content
              if (isExpanded)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      const Divider(),
                      const SizedBox(height: 8),
                      if (words.isEmpty)
                        Text(
                          'Belum ada kata dalam kategori ini',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else
                        ...words.map((word) => _buildWordItem(word, color)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWordItem(String word, Color color) {
    final cameraProvider = context.read<CameraProvider>();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.handshake, color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  word,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),
            ],
          ),
         
        ],
      ),
    );
  }

  Widget _buildRecentWords() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kata Terbaru Dipelajari',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 16),

        // Recent words list
        ..._recentWords.map(
          (word) => _buildRecentWordItem(
            word: word['word'] as String,
            meaning: word['meaning'] as String,
            category: word['category'] as String,
            difficulty: word['difficulty'] as String,
            progress: word['progress'] as double,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentWordItem({
    required String word,
    required String meaning,
    required String category,
    required String difficulty,
    required double progress,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 45, // Reduced width
            height: 45, // Reduced height
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _getDifficultyGradient(difficulty),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10), // Reduced radius
            ),
            child: const Icon(
              Icons.handshake,
              color: Colors.white,
              size: 20, // Reduced icon size
            ),
          ),
          const SizedBox(width: 12), // Reduced spacing
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  word,
                  style: const TextStyle(
                    fontSize: 16, // Reduced font size
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                Text(
                  meaning,
                  style: TextStyle(
                    fontSize: 13, // Reduced font size
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 6), // Reduced spacing
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6, // Reduced padding
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B35)
                            .withOpacity(0.1), // Changed to orange
                        borderRadius: BorderRadius.circular(
                          6,
                        ), // Reduced radius
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          fontSize: 10, // Reduced font size
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF6B35), // Changed to orange
                        ),
                      ),
                    ),
                    const SizedBox(width: 6), // Reduced spacing
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6, // Reduced padding
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _getDifficultyColor(difficulty).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(
                          6,
                        ), // Reduced radius
                      ),
                      child: Text(
                        difficulty,
                        style: TextStyle(
                          fontSize: 10, // Reduced font size
                          fontWeight: FontWeight.w600,
                          color: _getDifficultyColor(difficulty),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  fontSize: 14, // Reduced font size
                  fontWeight: FontWeight.bold,
                  color: _getDifficultyColor(difficulty),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 35, // Reduced width
                height: 3, // Reduced height
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _getDifficultyColor(difficulty),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Color> _getDifficultyGradient(String difficulty) {
    switch (difficulty) {
      case 'Mudah':
        return [const Color(0xFF00C851), const Color(0xFF00E676)];
      case 'Sedang':
        return [const Color(0xFFFF8C00), const Color(0xFFFFB74D)];
      case 'Sulit':
        return [const Color(0xFFFF4444), const Color(0xFFFF6B6B)];
      default:
        return [
          const Color(0xFFFF6B35),
          const Color(0xFFFF8A65)
        ]; // Changed to orange gradient
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'Mudah':
        return const Color(0xFF00C851);
      case 'Sedang':
        return const Color(0xFFFF8C00);
      case 'Sulit':
        return const Color(0xFFFF4444);
      default:
        return const Color(0xFFFF6B35); // Changed to orange
    }
  }
}
