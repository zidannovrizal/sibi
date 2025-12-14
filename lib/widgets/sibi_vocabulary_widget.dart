import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// Widget kosakata dengan tampilan sama (header gradasi),
/// namun kontennya memakai data real dari assets/currently_use/sibi_compact_labels.json.
class SibiVocabularyWidget extends StatefulWidget {
  const SibiVocabularyWidget({super.key});

  @override
  State<SibiVocabularyWidget> createState() => _SibiVocabularyWidgetState();
}

class _SibiVocabularyWidgetState extends State<SibiVocabularyWidget> {
  List<String> _labels = [];
  List<String> _allLabels = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLabels();
  }

  Future<void> _loadLabels() async {
    try {
      final jsonStr = await rootBundle
          .loadString('assets/currently_use/sibi_compact_labels.json');
      final List<dynamic> data = json.decode(jsonStr) as List<dynamic>;
      final formatted = data
          .map((e) => e.toString())
          .where((w) => w.toLowerCase() != 'idle')
          .map(_capitalize)
          .toList();
      setState(() {
        _allLabels = formatted;
        _labels = formatted;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Text('Gagal memuat kosakata\n$_error'),
      );
    }

    return Container(
      color: AppColors.background,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 210,
            collapsedHeight: 150,
            toolbarHeight: 0,
            floating: false,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primaryLight,
                      AppColors.primarySoft,
                    ],
                  ),
                ),
                child: SafeArea(
                  top: true,
                  bottom: false,
                  child: Stack(
                    children: [
                      Positioned(
                        right: -40,
                        top: -40,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
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
                            color: Colors.white.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
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
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SearchField(
                    onChanged: (query) {
                      setState(() {
                        final q = query.toLowerCase();
                        _labels = q.isEmpty
                            ? _allLabels
                            : _allLabels
                                .where((w) => w.toLowerCase().contains(q))
                                .toList();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  ..._labels.asMap().entries.map(
                        (entry) => _WordCard(
                          word: entry.value,
                          index: entry.key + 1,
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Cari kosakata...',
          hintStyle: const TextStyle(fontFamily: AppColors.poppins),
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        style: const TextStyle(fontFamily: AppColors.poppins),
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  final String word;
  final int index;

  const _WordCard({required this.word, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              index.toString().padLeft(2, '0'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  word,
                  style: const TextStyle(
                    fontFamily: AppColors.poppins,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _capitalize(String input) {
  if (input.isEmpty) return input;
  return input[0].toUpperCase() + input.substring(1);
}
