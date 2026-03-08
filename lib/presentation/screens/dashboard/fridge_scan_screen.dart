import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/api_constants.dart';
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

class _FridgeScanScreenState extends ConsumerState<FridgeScanScreen>
    with SingleTickerProviderStateMixin {
  File? _imageFile;
  _ScanState _scanState = _ScanState.idle;
  List<_DetectedItem> _items = [];
  Set<int> _selectedIndices = {};
  String? _errorMessage;
  final _picker = ImagePicker();
  late final AnimationController _chipAnim;

  // Predefined overlay chip positions as fractions of image (left, top).
  static const _overlayPositions = [
    Offset(0.05, 0.07),
    Offset(0.55, 0.04),
    Offset(0.62, 0.38),
    Offset(0.04, 0.52),
    Offset(0.28, 0.68),
    Offset(0.62, 0.70),
    Offset(0.34, 0.26),
  ];

  @override
  void initState() {
    super.initState();
    _chipAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _chipAnim.dispose();
    super.dispose();
  }

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
      _chipAnim.forward(from: 0);
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

    Navigator.of(context).pop();
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
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _errorMessage!,
                      style:
                          TextStyle(color: Colors.red.shade300, fontSize: 12),
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
    return Stack(
      children: [
        if (_imageFile != null)
          Positioned.fill(child: Image.file(_imageFile!, fit: BoxFit.cover)),
        Container(
          color: Colors.black.withValues(alpha: 0.55),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 20),
                Text(
                  'Identifying ingredients...',
                  style:
                      AppTextStyles.bodyLarge.copyWith(color: Colors.white),
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
        // Annotated image
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _buildAnnotatedImage(),
            ),
          ),
        ),

        const SizedBox(height: 10),

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

          // Scrollable filter chips
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final item = _items[i];
                final selected = _selectedIndices.contains(i);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      item.quantity.isNotEmpty
                          ? '${item.name}  ·  ${item.quantity}'
                          : item.name,
                      style: TextStyle(
                        color: selected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    selected: selected,
                    onSelected: (val) => setState(() {
                      if (val) {
                        _selectedIndices.add(i);
                      } else {
                        _selectedIndices.remove(i);
                      }
                    }),
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    checkmarkColor: AppColors.primary,
                    backgroundColor: AppColors.glass,
                    side: BorderSide(
                      color: selected
                          ? AppColors.primary
                          : AppColors.glassBorder,
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

  Widget _buildAnnotatedImage() {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final overlayCount = min(_items.length, _overlayPositions.length);

      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(_imageFile!, fit: BoxFit.cover),

          // Bottom scrim
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: h * 0.28,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
          ),

          // Animated label chips on image
          ...List.generate(overlayCount, (i) {
            final pos = _overlayPositions[i];
            final item = _items[i];
            final selected = _selectedIndices.contains(i);

            return Positioned(
              left: pos.dx * w,
              top: pos.dy * h,
              child: _AnimatedChip(
                controller: _chipAnim,
                delay: i * 0.09,
                child: GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _selectedIndices.remove(i);
                    } else {
                      _selectedIndices.add(i);
                    }
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.88)
                          : Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? AppColors.primaryLight
                            : Colors.white30,
                        width: 1.2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selected)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.check_circle,
                                size: 12, color: Colors.white),
                          ),
                        Text(
                          item.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (item.quantity.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Text(
                            item.quantity,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      );
    });
  }
}

// ── Animated chip ─────────────────────────────────────────────────────────────

class _AnimatedChip extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final Widget child;

  const _AnimatedChip({
    required this.controller,
    required this.delay,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final start = delay.clamp(0.0, 0.9);
    final end = (delay + 0.3).clamp(0.0, 1.0);
    final anim = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (_, child) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, (1 - anim.value) * 14),
          child: child,
        ),
      ),
      child: child,
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
