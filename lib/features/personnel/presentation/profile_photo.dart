import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/app_repository.dart';

class ProfilePhoto extends ConsumerWidget {
  const ProfilePhoto({
    super.key,
    required this.profile,
    this.radius = 28,
  });

  final UserProfile profile;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = profile.fotoPath;
    if (path == null || path.isEmpty) {
      return _initials(radius);
    }
    return FutureBuilder<String?>(
      future: ref.read(appRepositoryProvider).signedFileUrl(path),
      builder: (context, snap) {
        final url = snap.data;
        if (url == null || url.isEmpty) return _initials(radius);
        return CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.mint,
          backgroundImage: NetworkImage(url),
        );
      },
    );
  }

  Widget _initials(double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.forest,
      child: Text(
        profile.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.55,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
