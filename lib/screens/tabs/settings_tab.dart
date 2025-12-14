// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/server_config_provider.dart';
import '../../theme/app_colors.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final server = context.watch<ServerConfigProvider>();
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final onSurface = theme.colorScheme.onSurface;

    Future<bool> confirmToggle(BuildContext ctx, bool nextValue) async {
      final modeLabel = nextValue ? 'Online' : 'Offline';
      return await showDialog<bool>(
            context: ctx,
            builder: (context) => AlertDialog(
              title: Text('Ganti ke Mode $modeLabel?'),
              content: Text(
                nextValue
                    ? 'Mode Online akan memproses di server dan memakai koneksi internet.'
                    : 'Mode Offline akan memproses di perangkat. Pastikan model lokal siap.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Ya, ganti'),
                ),
              ],
            ),
          ) ??
          false;
    }

    return SafeArea(
      top: false,
      bottom: true,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: _Header(),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SettingItem(
                    icon: Icons.cloud_done_rounded,
                    title: server.useRemote ? 'Mode Online' : 'Mode Offline',
                    subtitle: server.useRemote
                        ? 'Diproses server.'
                        : 'Diproses built-in aplikasi.',
                    trailing: Switch(
                      value: server.useRemote,
                      thumbColor:
                          WidgetStatePropertyAll<Color>(AppColors.primary),
                      onChanged: (val) async {
                        final ok = await confirmToggle(context, val);
                        if (ok) {
                          await server.setUseRemote(val);
                        }
                      },
                    ),
                    cardColor: cardColor,
                    onSurface: onSurface,
                  ),
                  const SizedBox(height: 12),
                  _InfoCard(
                    cardColor: cardColor,
                    onSurface: onSurface,
                    title: 'Panduan Cepat',
                    lines: const [
                      '1) Pencahayaan cukup, tangan penuh di kamera.',
                      '2) Mode Online kirim ke server; Offline pakai model lokal.',
                      '3) Pastikan koneksi stabil bila Online.',
                    ],
                  ),
                  const SizedBox(height: 12),
                  _InfoCard(
                    cardColor: cardColor,
                    onSurface: onSurface,
                    title: 'Versi Aplikasi',
                    lines: const [
                      'Tangan Nusantara v1.0.0',
                    ],
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

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primaryLight,
            AppColors.primarySoft,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(89), // ~35% opacity
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -20,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(26), // ~10% opacity
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -10,
            child: Transform.rotate(
              angle: -0.25,
              child: Container(
                width: 200,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(20), // ~8% opacity
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 0, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SizedBox(height: 48),
                Text(
                  'Pengaturan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
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

class _SettingItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Color cardColor;
  final Color onSurface;

  const _SettingItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.cardColor,
    required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10), // ~4% opacity
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(26), // ~10% opacity
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: onSurface.withAlpha(150),
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Color cardColor;
  final Color onSurface;
  final String title;
  final List<String> lines;
  const _InfoCard({
    required this.cardColor,
    required this.onSurface,
    required this.title,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(24),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.info_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                line,
                style: TextStyle(
                  fontSize: 13,
                  color: onSurface.withAlpha(150),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
