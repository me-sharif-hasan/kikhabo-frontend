import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Horizontal ruler-style height picker.
/// Range: 1 ft (12 in) to 8 ft (96 in) — 85 ticks total.
/// Outputs value as decimal feet (e.g., 5.583 for 5 ft 7 in).
class HeightScalePicker extends StatefulWidget {
  final double? initialHeightInFt;
  final ValueChanged<double> onChanged;

  const HeightScalePicker({
    super.key,
    this.initialHeightInFt,
    required this.onChanged,
  });

  @override
  State<HeightScalePicker> createState() => _HeightScalePickerState();
}

class _HeightScalePickerState extends State<HeightScalePicker> {
  static const int _minInches = 12; // 1 ft
  static const int _maxInches = 96; // 8 ft
  static const double _tickSpacing = 10.0;
  static const double _rulerHeight = 74.0;

  late int _selectedInches;
  final ScrollController _scrollController = ScrollController();
  bool _suppressScrollListener = false;
  bool _initialScrollDone = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialHeightInFt;
    if (initial != null && initial > 0) {
      _selectedInches = (initial * 12).round().clamp(_minInches, _maxInches);
    } else {
      _selectedInches = 67; // default 5 ft 7 in
    }
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_suppressScrollListener) return;
    final offset = _scrollController.offset;
    final inches =
        (offset / _tickSpacing + _minInches).round().clamp(_minInches, _maxInches);
    if (inches != _selectedInches) {
      setState(() => _selectedInches = inches);
      widget.onChanged(inches / 12.0);
    }
  }

  double _offsetFor(int inches) => (inches - _minInches) * _tickSpacing;

  void _adjustBy(int delta) {
    final newInches = (_selectedInches + delta).clamp(_minInches, _maxInches);
    if (newInches == _selectedInches) return;
    _suppressScrollListener = true;
    setState(() => _selectedInches = newInches);
    widget.onChanged(newInches / 12.0);
    _scrollController
        .animateTo(
          _offsetFor(newInches),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        )
        .then((_) => _suppressScrollListener = false);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ft = _selectedInches ~/ 12;
    final inRem = _selectedInches % 12;
    final cm = (_selectedInches * 2.54).round();
    final ftLabel = inRem == 0 ? '$ft ft' : '$ft ft $inRem in';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Height', style: AppTextStyles.labelLarge),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.glass.withOpacity(0.05),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.glassBorder.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              // ── Selected height display ──────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.height, color: AppColors.primaryLight, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    ftLabel,
                    style: AppTextStyles.titleLarge
                        .copyWith(color: AppColors.primaryLight),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 1,
                    height: 18,
                    color: AppColors.glassBorder.withOpacity(0.5),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$cm cm',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // ── Ruler row ────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _ScaleButton(
                    icon: Icons.remove,
                    onTap: () => _adjustBy(-1),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        if (!_initialScrollDone) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_scrollController.hasClients) {
                              _scrollController.jumpTo(_offsetFor(_selectedInches));
                              _initialScrollDone = true;
                            }
                          });
                        }
                        return _buildRuler(constraints.maxWidth);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ScaleButton(
                    icon: Icons.add,
                    onTap: () => _adjustBy(1),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRuler(double vpWidth) {
    final totalTicks = _maxInches - _minInches + 1; // 85
    final contentWidth = totalTicks * _tickSpacing;

    return ClipRect(
      child: SizedBox(
        height: _rulerHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Scrollable ruler ──────────────────────────────────────
            NotificationListener<ScrollEndNotification>(
              onNotification: (notification) {
                final offset = _scrollController.offset;
                final exact = offset / _tickSpacing + _minInches;
                final snapped = exact.round().clamp(_minInches, _maxInches);
                if (snapped != _selectedInches) {
                  setState(() => _selectedInches = snapped);
                  widget.onChanged(snapped / 12.0);
                }
                final snapOffset = _offsetFor(snapped);
                if ((snapOffset - offset).abs() > 0.5) {
                  _suppressScrollListener = true;
                  _scrollController
                      .animateTo(
                        snapOffset,
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOut,
                      )
                      .then((_) => _suppressScrollListener = false);
                }
                return true;
              },
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: vpWidth / 2),
                  child: SizedBox(
                    width: contentWidth,
                    height: _rulerHeight,
                    child: CustomPaint(
                      painter: _RulerPainter(
                        totalTicks: totalTicks,
                        minInches: _minInches,
                        tickSpacing: _tickSpacing,
                        activeInches: _selectedInches,
                        rulerHeight: _rulerHeight,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // ── Fixed centre indicator ────────────────────────────────
            IgnorePointer(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 2,
                    height: _rulerHeight - 12,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.accent.withOpacity(0.0),
                          AppColors.accent,
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// + / − button
// ─────────────────────────────────────────────────────────────────────────────
class _ScaleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ScaleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          gradient: AppColors.bgGradient2,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ruler painter — draws tick marks and ft labels
// TextPainters are cached across repaints to avoid re-layout on every scroll.
// ─────────────────────────────────────────────────────────────────────────────
class _RulerPainter extends CustomPainter {
  final int totalTicks;
  final int minInches;
  final double tickSpacing;
  final int activeInches;
  final double rulerHeight;

  // Cached painters: key = inches value (only ft marks: 12,24,...,96)
  final Map<int, TextPainter> _ftPainters;

  _RulerPainter({
    required this.totalTicks,
    required this.minInches,
    required this.tickSpacing,
    required this.activeInches,
    required this.rulerHeight,
  }) : _ftPainters = _buildFtPainters(minInches, totalTicks, activeInches);

  static Map<int, TextPainter> _buildFtPainters(
      int minInches, int totalTicks, int activeInches) {
    final map = <int, TextPainter>{};
    for (int i = 0; i < totalTicks; i++) {
      final inches = i + minInches;
      if (inches % 12 == 0) {
        final ft = inches ~/ 12;
        final isActive = inches == activeInches;
        final tp = TextPainter(
          text: TextSpan(
            text: '$ft ft',
            style: TextStyle(
              color: isActive
                  ? AppColors.accent
                  : AppColors.primaryLight.withValues(alpha: 0.8),
              fontSize: isActive ? 11 : 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        map[inches] = tp;
      }
    }
    return map;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final defaultPaint = Paint()
      ..color = AppColors.glassBorder.withValues(alpha: 0.8)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final ftPaint = Paint()
      ..color = AppColors.primaryLight.withValues(alpha: 0.8)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < totalTicks; i++) {
      final inches = i + minInches;
      final x = i * tickSpacing + tickSpacing / 2;
      final isActive = inches == activeInches;
      final isFt = inches % 12 == 0;
      final isHalfFt = inches % 6 == 0 && !isFt;
      final isQuarter = inches % 3 == 0 && !isHalfFt && !isFt;

      double tickH;
      if (isFt) {
        tickH = 46;
      } else if (isHalfFt) {
        tickH = 28;
      } else if (isQuarter) {
        tickH = 18;
      } else {
        tickH = 11;
      }

      final paint = isActive ? activePaint : (isFt ? ftPaint : defaultPaint);
      canvas.drawLine(
        Offset(x, size.height - tickH),
        Offset(x, size.height),
        paint,
      );

      if (isFt) {
        final tp = _ftPainters[inches]!;
        tp.paint(
          canvas,
          Offset(x - tp.width / 2, size.height - tickH - tp.height - 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RulerPainter old) => old.activeInches != activeInches;
}
