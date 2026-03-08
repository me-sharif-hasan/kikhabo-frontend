import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../domain/providers/user_provider.dart';
import '../../widgets/glass_card.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _uploadingImage = false;

  Future<void> _pickAndUploadImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    setState(() => _uploadingImage = true);
    await ref.read(userProvider.notifier).uploadProfileImage(path);
    if (mounted) setState(() => _uploadingImage = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final userState = ref.watch(userProvider);
    final user = userState.user;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: userState.isLoading && user == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Avatar with upload button
                    Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryLight],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(color: AppColors.glassBorder, width: 2),
                          ),
                          child: ClipOval(
                            child: user?.profileImageUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: user!.profileImageUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                    errorWidget: (_, __, ___) => Center(
                                      child: Text(
                                        user.firstName?.substring(0, 1).toUpperCase() ?? 'U',
                                        style: const TextStyle(fontSize: 48, color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      user?.firstName?.substring(0, 1).toUpperCase() ?? 'U',
                                      style: const TextStyle(fontSize: 48, color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _uploadingImage ? null : _pickAndUploadImage,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: _uploadingImage
                                  ? const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    Text(
                      '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim(),
                      style: AppTextStyles.headlineSmall,
                    ),
                    Text(
                      user?.email ?? '',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                    ),

                    const SizedBox(height: 32),

                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.5,
                      children: [
                        _buildInfoCard('Country', user?.country ?? 'N/A', Icons.flag),
                        _buildInfoCard('Gender', user?.gender ?? 'N/A', Icons.person_outline),
                        _buildInfoCard('Religion', user?.religion ?? 'N/A', Icons.wb_sunny_outlined),
                        _buildInfoCard('Birth Date', user?.dateOfBirth ?? 'N/A', Icons.calendar_today),
                        _buildInfoCard(
                          'Weight',
                          user?.weightInKg != null
                              ? '${user!.weightInKg!.toStringAsFixed(1)} kg'
                              : 'N/A',
                          Icons.monitor_weight_outlined,
                        ),
                        _buildInfoCard(
                          'Height',
                          user?.heightInFt != null
                              ? '${user!.heightInFt!.toStringAsFixed(1)} ft'
                              : 'N/A',
                          Icons.height,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    GlassCard(
                      padding: const EdgeInsets.all(0),
                      child: InkWell(
                        onTap: () => context.push('/dashboard/profile/edit'),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryDark],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.edit, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'Edit Profile',
                                style: AppTextStyles.titleMedium
                                    .copyWith(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryLight, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
