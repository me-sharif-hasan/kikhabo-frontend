import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/providers/user_provider.dart';
import '../../widgets/country_picker_field.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/glass_text_field.dart';
import '../../widgets/height_scale_picker.dart';

class GoogleProfileCompletionScreen extends ConsumerStatefulWidget {
  const GoogleProfileCompletionScreen({super.key});

  @override
  ConsumerState<GoogleProfileCompletionScreen> createState() =>
      _GoogleProfileCompletionScreenState();
}

class _GoogleProfileCompletionScreenState
    extends ConsumerState<GoogleProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _weightController;

  String? _selectedGender;
  String? _selectedReligion;
  String? _selectedCountry;
  int _selectedHeightInches = 67; // default 5 ft 7 in
  DateTime? _selectedDateOfBirth;
  bool _initialized = false;

  static const _genders = ['Male', 'Female', 'Other'];
  static const _religions = [
    'Islam',
    'Hindu',
    'Christian',
    'Buddhist',
    'Jewish',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _weightController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final user = ref.read(userProvider).user;
      if (user != null) {
        _firstNameController.text = user.firstName ?? '';
        _lastNameController.text = user.lastName ?? '';
        _selectedCountry = user.country?.isNotEmpty == true ? user.country : null;
        _weightController.text = user.weightInKg?.toString() ?? '';
        if (user.heightInFt != null && user.heightInFt! > 0) {
          _selectedHeightInches =
              (user.heightInFt! * 12).round().clamp(12, 96);
        }
        _selectedGender =
            _genders.contains(user.gender) ? user.gender : null;
        _selectedReligion =
            _religions.contains(user.religion) ? user.religion : null;
        if (user.dateOfBirth != null) {
          try {
            _selectedDateOfBirth =
                DateFormat('d MMM, yyyy').parse(user.dateOfBirth!);
          } catch (_) {}
        }
        _initialized = true;
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _markDoneAndGo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.googleProfileCompletionShownKey, true);
    if (mounted) context.go('/dashboard/home');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final data = <String, dynamic>{};

    if (_firstNameController.text.isNotEmpty) {
      data['firstName'] = _firstNameController.text.trim();
    }
    if (_lastNameController.text.isNotEmpty) {
      data['lastName'] = _lastNameController.text.trim();
    }
    if (_selectedCountry != null) data['country'] = _selectedCountry;
    if (_selectedGender != null) data['gender'] = _selectedGender;
    if (_selectedReligion != null) data['religion'] = _selectedReligion;
    if (_selectedDateOfBirth != null) {
      data['dateOfBirth'] =
          DateFormat('d MMM, yyyy').format(_selectedDateOfBirth!);
    }
    final weight = double.tryParse(_weightController.text);
    if (weight != null) data['weightInKg'] = weight;
    data['heightInFt'] = _selectedHeightInches / 12.0;

    final success = await ref.read(userProvider.notifier).updateUser(data);

    if (!mounted) return;
    if (success) {
      await _markDoneAndGo();
    } else {
      final error = ref.read(userProvider).error ?? 'Update failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime(1990),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDateOfBirth = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(userProvider).isLoading;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.bgGradient1),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Complete Your Profile',
                            style: AppTextStyles.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Fill in the details so AI can personalise your meals',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: isLoading ? null : _markDoneAndGo,
                      child: Text(
                        'Skip',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Form
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GlassTextField(
                          controller: _firstNameController,
                          labelText: 'First Name',
                          hintText: 'Enter your first name',
                          prefixIcon: Icons.person,
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),

                        GlassTextField(
                          controller: _lastNameController,
                          labelText: 'Last Name',
                          hintText: 'Enter your last name',
                          prefixIcon: Icons.person_outline,
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),

                        _buildDropdown(
                          label: 'Gender',
                          value: _selectedGender,
                          items: _genders,
                          icon: Icons.wc,
                          onChanged: (v) =>
                              setState(() => _selectedGender = v),
                        ),
                        const SizedBox(height: 16),

                        _buildDropdown(
                          label: 'Religion',
                          value: _selectedReligion,
                          items: _religions,
                          icon: Icons.wb_sunny_outlined,
                          onChanged: (v) =>
                              setState(() => _selectedReligion = v),
                        ),
                        const SizedBox(height: 16),

                        CountryPickerField(
                          selectedCountry: _selectedCountry,
                          onChanged: (v) =>
                              setState(() => _selectedCountry = v),
                        ),
                        const SizedBox(height: 16),

                        GestureDetector(
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Date of Birth',
                              labelStyle: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSecondary),
                              prefixIcon: Icon(Icons.calendar_today,
                                  color: AppColors.primaryLight),
                              suffixIcon: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: AppColors.textSecondary),
                              filled: true,
                              fillColor: AppColors.glass.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(
                                    color: AppColors.glassBorder
                                        .withOpacity(0.3)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(
                                    color: AppColors.glassBorder
                                        .withOpacity(0.3)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                            ),
                            child: Text(
                              _selectedDateOfBirth != null
                                  ? DateFormat('d MMM, yyyy')
                                      .format(_selectedDateOfBirth!)
                                  : 'Tap to select',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: _selectedDateOfBirth != null
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        GlassTextField(
                          controller: _weightController,
                          labelText: 'Weight (kg)',
                          hintText: 'e.g. 65.5',
                          prefixIcon: Icons.monitor_weight_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: (v) {
                            if (v != null &&
                                v.isNotEmpty &&
                                double.tryParse(v) == null) {
                              return 'Enter a valid number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        HeightScalePicker(
                          initialHeightInFt: _selectedHeightInches / 12.0,
                          onChanged: (ft) {
                            setState(() => _selectedHeightInches =
                                (ft * 12).round().clamp(12, 96));
                          },
                        ),
                        const SizedBox(height: 32),

                        GlassButton(
                          text: 'Save & Continue',
                          onPressed: isLoading ? null : _save,
                          isLoading: isLoading,
                          gradient: AppColors.bgGradient2,
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

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide:
          BorderSide(color: AppColors.glassBorder.withOpacity(0.3)),
    );
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.primaryLight),
        filled: true,
        fillColor: AppColors.glass.withOpacity(0.05),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: AppColors.primaryLight),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      dropdownColor: AppColors.surface,
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
      icon: Icon(Icons.keyboard_arrow_down_rounded,
          color: AppColors.textSecondary),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
