import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/ad_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../domain/providers/ingredient_scan_provider.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/glass_card.dart';

class FridgeScanScreen extends ConsumerStatefulWidget {
  const FridgeScanScreen({super.key});

  @override
  ConsumerState<FridgeScanScreen> createState() => _FridgeScanScreenState();
}

enum _ScanState { idle, analyzing, results }

class _FridgeScanScreenState extends ConsumerState<FridgeScanScreen> {
  File? _imageFile;
  _ScanState _scanState = _ScanState.idle;
  List<_DetectedItem> _items = [];
  Set<int> _selectedIndices = {};
  String? _errorMessage;
  final _picker = ImagePicker();

  // ── Image picking ──────────────────────────────────────────────────────────

  Future<void> _pick(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() {
      _imageFile = File(picked.path);
      _items = [];
      _selectedIndices = {};
      _errorMessage = null;
    });

    await _detect(File(picked.path));
  }

  // ── API call ───────────────────────────────────────────────────────────────

  Future<void> _detect(File file) async {
    setState(() => _scanState = _ScanState.analyzing);

    try {
      final dio = ref.read(dioClientProvider).dio;

      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          file.path,
          filename: 'image.jpg',
          contentType: DioMediaType('image', 'jpeg'),
        ),
      });

      final response = await dio.post(
        ApiConstants.ingredientsDetect,
        data: formData,
      );

      final raw = response.data['data'] as List<dynamic>;
      final items = raw
          .map((e) => _DetectedItem(
                name: e['name'] as String,
                quantity: (e['estimatedQuantity'] as String?) ?? '',
                confidence: (e['confidence'] as num).toDouble(),
              ))
          .toList();

      if (!mounted) return;
      setState(() {
        _items = items;
        _selectedIndices = Set.from(List.generate(items.length, (i) => i));
        _scanState = _ScanState.results;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _scanState = _ScanState.idle;
        _errorMessage = e.response?.data?['message']?.toString() ??
            'Detection failed (${e.response?.statusCode ?? 'no response'})';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanState = _ScanState.idle;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ── Delete item ────────────────────────────────────────────────────────────

  void _deleteItem(int index) {
    setState(() {
      _items.removeAt(index);
      // Rebuild selected indices from scratch to keep them contiguous
      _selectedIndices = _selectedIndices
          .where((i) => i != index)
          .map((i) => i > index ? i - 1 : i)
          .toSet();
    });
  }

  // ── Include in suggestions ─────────────────────────────────────────────────

  void _includeInSuggestions() {
    final selected = _selectedIndices
        .map((i) => ScannedIngredient(
              name: _items[i].name,
              quantity: _items[i].quantity,
            ))
        .toList();
    ref.read(scannedIngredientsProvider.notifier).setIngredients(selected);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${selected.length} ingredient(s) added to suggestions'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Show interstitial then dismiss the scan screen
    AdService.instance.show(onDone: () => Navigator.of(context).pop());
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.bgGradient2),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          Text('Fridge Scanner', style: AppTextStyles.headlineSmall),
          const Spacer(),
          if (_scanState == _ScanState.results)
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
              tooltip: 'New scan',
              onPressed: () => setState(() {
                _imageFile = null;
                _items = [];
                _selectedIndices = {};
                _scanState = _ScanState.idle;
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_scanState) {
      case _ScanState.idle:
        return _buildEmptyState();
      case _ScanState.analyzing:
        return _buildAnalyzing();
      case _ScanState.results:
        return _buildResults();
    }
  }

  // ── Empty state ─────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GlassCard(
            blur: 12,
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.camera_alt_rounded,
                    size: 72, color: AppColors.primary),
                const SizedBox(height: 20),
                Text(
                  'Scan Your Fridge',
                  style: AppTextStyles.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Take or upload a photo of your fridge or vegetable cart. '
                  'AI will identify specific ingredients and quantities.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                GlassButton(
                  text: '📷  Take Photo',
                  onPressed: () => _pick(ImageSource.camera),
                  gradient: AppColors.bgGradient1,
                ),
                const SizedBox(height: 12),
                GlassButton(
                  text: '🖼️  Choose from Gallery',
                  onPressed: () => _pick(ImageSource.gallery),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Analyzing ───────────────────────────────────────────────────────────────

  Widget _buildAnalyzing() {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        if (_imageFile != null)
          Positioned.fill(child: Image.file(_imageFile!, fit: BoxFit.cover)),
        Container(
          color: cs.scrim.withValues(alpha: 0.55),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 20),
                Text(
                  'Identifying ingredients...',
                  style: AppTextStyles.bodyLarge
                      .copyWith(color: cs.onInverseSurface),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Results ─────────────────────────────────────────────────────────────────

  Widget _buildResults() {
    final hasItems = _items.isNotEmpty;

    return Column(
      children: [
        // Photo preview — no overlays
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.file(_imageFile!, fit: BoxFit.cover),
            ),
          ),
        ),

        const SizedBox(height: 12),

        if (!hasItems)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'No ingredients detected. Try a clearer or closer photo.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          )
        else ...[
          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('Detected Ingredients', style: AppTextStyles.bodyLarge),
                const Spacer(),
                Text(
                  '${_selectedIndices.length}/${_items.length} selected',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Scrollable ingredient list with toggle + delete
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final item = _items[i];
                final selected = _selectedIndices.contains(i);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() {
                        if (selected) {
                          _selectedIndices.remove(i);
                        } else {
                          _selectedIndices.add(i);
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primaryDark
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? AppColors.primaryLight
                                : AppColors.glassBorder,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 20,
                              color: selected
                                  ? AppColors.onPrimary
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: selected
                                          ? AppColors.onPrimary
                                          : AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (item.quantity.isNotEmpty)
                                    Text(
                                      item.quantity,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: selected
                                            ? AppColors.primaryLight
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded,
                                  size: 18,
                                  color: selected
                                      ? AppColors.onPrimary
                                      : AppColors.textSecondary),
                              onPressed: () => _deleteItem(i),
                              tooltip: 'Remove',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassButton(
              text:
                  '✓  Include ${_selectedIndices.length} Item(s) in Suggestions',
              onPressed:
                  _selectedIndices.isEmpty ? null : _includeInSuggestions,
              gradient: AppColors.bgGradient1,
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Data ───────────────────────────────────────────────────────────────────────

class _DetectedItem {
  final String name;
  final String quantity;
  final double confidence;
  const _DetectedItem(
      {required this.name, required this.quantity, required this.confidence});
}
