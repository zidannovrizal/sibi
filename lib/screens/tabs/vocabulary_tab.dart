import 'package:flutter/material.dart';

import '../../widgets/sibi_vocabulary_widget.dart';

class VocabularyTab extends StatelessWidget {
  const VocabularyTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      top: false,
      bottom: true,
      child: SibiVocabularyWidget(),
    );
  }
}
