import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../domain/providers/user_provider.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/glass_text_field.dart';
import '../../widgets/height_scale_picker.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _countryController;
  late TextEditingController _weightController;
  int _selectedHeightInches = 67; // default 5 ft 7 in

  String? _selectedGender;
  String? _selectedReligion;
  DateTime? _selectedDateOfBirth;

  bool _initialized = false;

  static const _genders = ['Male', 'Female', 'Other'];
  static const _religions = ['Islam', 'Hindu', 'Christian', 'Buddhist', 'Jewish', 'Other'];

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _emailController = TextEditingController();
    _countryController = TextEditingController();
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
        _emailController.text = user.email;
        _countryController.text = user.country ?? '';
        _weightController.text = user.weightInKg?.toString() ?? '';
        if (user.heightInFt != null && user.heightInFt! > 0) {
          _selectedHeightInches = (user.heightInFt! * 12).round().clamp(12, 96);
        }
        _selectedGender = _genders.contains(user.gender) ? user.gender : null;
        _selectedReligion = _religions.contains(user.religion) ? user.religion : null;
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
    _emailController.dispose();
    _countryController.dispose();
    _weightController.dispose();
    super.dispose();
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
    if (picked != null) {
      setState(() => _selectedDateOfBirth = picked);
    }
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
    if (_emailController.text.isNotEmpty) {
      data['email'] = _emailController.text.trim();
    }
    if (_countryController.text.isNotEmpty) {
      data['country'] = _countryController.text.trim();
    }
    if (_selectedGender != null) {
      data['gender'] = _selectedGender;
    }
    if (_selectedReligion != null) {
      data['religion'] = _selectedReligion;
    }
    if (_selectedDateOfBirth != null) {
      data['dateOfBirth'] = DateFormat('d MMM, yyyy').format(_selectedDateOfBirth!);
    }
    final weight = double.tryParse(_weightController.text);
    if (weight != null) {
      data['weightInKg'] = weight;
    }
    data['heightInFt'] = _selectedHeightInches / 12.0;

    final success = await ref.read(userProvider.notifier).updateUser(data);

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
      context.pop();
    } else {
      final error = ref.read(userProvider).error ?? 'Update failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final isLoading = ref.watch(userProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text('Edit Profile', style: AppTextStyles.headlineSmall),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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

                GlassTextField(
                  controller: _emailController,
                  labelText: 'Email',
                  hintText: 'Enter your email',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                GlassTextField(
                  controller: _countryController,
                  labelText: 'Country',
                  hintText: 'e.g. Bangladesh',
                  prefixIcon: Icons.flag_outlined,
                ),
                const SizedBox(height: 16),

                _buildDropdown(
                  label: 'Gender',
                  value: _selectedGender,
                  items: _genders,
                  icon: Icons.wc,
                  onChanged: (v) => setState(() => _selectedGender = v),
                ),
                const SizedBox(height: 16),

                _buildDropdown(
                  label: 'Religion',
                  value: _selectedReligion,
                  items: _religions,
                  icon: Icons.wb_sunny_outlined,
                  onChanged: (v) => setState(() => _selectedReligion = v),
                ),
                const SizedBox(height: 16),

                // Date of Birth picker
                GestureDetector(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date of Birth',
                      labelStyle: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                      prefixIcon: Icon(Icons.calendar_today,
                          color: AppColors.primaryLight),
                      suffixIcon: Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.glass.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                            color: AppColors.glassBorder.withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                            color: AppColors.glassBorder.withOpacity(0.3)),
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
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v != null && v.isNotEmpty && double.tryParse(v) == null) {
                      return 'Enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                HeightScalePicker(
                  initialHeightInFt: _selectedHeightInches / 12.0,
                  onChanged: (ft) {
                    setState(() => _selectedHeightInches = (ft * 12).round().clamp(12, 96));
                  },
                ),
                const SizedBox(height: 32),

                GlassButton(
                  text: 'Save Changes',
                  onPressed: isLoading ? null : _save,
                  isLoading: isLoading,
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                ),
              ],
            ),
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
      borderSide: BorderSide(color: AppColors.glassBorder.withOpacity(0.3)),
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
