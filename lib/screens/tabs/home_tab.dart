import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/server_config_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/camera_widget.dart';

class HomeTab extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  const HomeTab({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final serverConfig = context.watch<ServerConfigProvider>();
    final hasServerUrl = serverConfig.hasServerUrl;
    final isOnline = serverConfig.useRemote;
    final cameraEnabled = !isOnline || hasServerUrl;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 240,
          collapsedHeight: 170,
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
                    AppColors.primarySoft
                  ],
                ),
              ),
              child: SafeArea(
                top: true,
                bottom: false,
                child: Stack(
                  children: [
                    Positioned(
                      right: -50,
                      top: -50,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(26),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      left: -30,
                      bottom: -30,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(13),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 135,
                            height: 135,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.primary.withAlpha(210),
                                  AppColors.primarySoft.withAlpha(190),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withAlpha(80),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(18),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/mascot-only.jpg',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Tangan Nusantara',
                            style: TextStyle(
                              fontFamily: AppColors.poppins,
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Belajar Bahasa Isyarat SIBI',
                            style: TextStyle(
                              fontFamily: AppColors.poppins,
                              color: Colors.white70,
                              fontSize: 16,
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
                _FeatureCard(
                  icon: Icons.camera_alt,
                  title: 'Pengenalan Bahasa Isyarat',
                  subtitle: null,
                  statusBadge: isOnline ? 'Online' : 'Offline',
                  statusColor: isOnline ? Colors.green : Colors.orange,
                  gradient: const [AppColors.primary, AppColors.primaryLight],
                  enabled: cameraEnabled,
                  onTap: cameraEnabled
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CameraWidget(),
                            ),
                          );
                        }
                      : null,
                ),
                const SizedBox(height: 16),
                _FeatureCard(
                  icon: Icons.school,
                  title: 'Belajar SIBI',
                  subtitle: 'Pelajari kosakata bahasa isyarat Indonesia',
                  gradient: const [
                    AppColors.primaryLight,
                    AppColors.primarySoft
                  ],
                  onTap: () => onNavigate(1),
                ),
                const SizedBox(height: 16),
                _FeatureCard(
                  icon: Icons.settings,
                  title: 'Pengaturan',
                  subtitle: 'Atur mode online/offline dan server',
                  gradient: const [AppColors.primarySoft, Color(0xFFFFC68A)],
                  onTap: () => onNavigate(2),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? statusBadge;
  final Color? statusColor;
  final List<Color> gradient;
  final VoidCallback? onTap;
  final bool enabled;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.statusBadge,
    this.statusColor,
    required this.gradient,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withAlpha(51),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: enabled
                    ? [Colors.white, Colors.white.withAlpha(230)]
                    : [Colors.grey.shade200, Colors.grey.shade100],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: enabled
                          ? gradient
                          : [Colors.grey.shade400, Colors.grey.shade300],
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: AppColors.poppins,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontFamily: AppColors.poppins,
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      if (statusBadge != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: (statusColor ?? AppColors.primary)
                                .withAlpha(28),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                statusBadge!.toLowerCase() == 'online'
                                    ? Icons.cloud_done_rounded
                                    : Icons.cloud_off_rounded,
                                size: 16,
                                color: statusColor ?? AppColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                statusBadge!,
                                style: TextStyle(
                                  fontFamily: AppColors.poppins,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor ?? AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (enabled && onTap != null)
                  const Icon(Icons.arrow_forward_ios_rounded,
                      color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
