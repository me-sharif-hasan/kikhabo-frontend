import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Tappable country picker field that opens a searchable country list bottom sheet.
class CountryPickerField extends StatelessWidget {
  final String? selectedCountry;
  final ValueChanged<String> onChanged;

  const CountryPickerField({
    super.key,
    required this.selectedCountry,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: BorderSide(color: AppColors.glassBorder.withOpacity(0.3)),
    );

    return GestureDetector(
      onTap: () {
        showCountryPicker(
          context: context,
          showPhoneCode: false,
          countryListTheme: CountryListThemeData(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            backgroundColor: AppColors.surface,
            textStyle: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textPrimary),
            searchTextStyle: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textPrimary),
            inputDecoration: InputDecoration(
              hintText: 'Search country...',
              hintStyle: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              prefixIcon:
                  Icon(Icons.search, color: AppColors.primaryLight),
              filled: true,
              fillColor: AppColors.glass.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: AppColors.glassBorder.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: AppColors.glassBorder.withOpacity(0.3)),
              ),
            ),
          ),
          onSelect: (Country country) => onChanged(country.name),
        );
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Country',
          labelStyle: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary),
          prefixIcon:
              Icon(Icons.flag_outlined, color: AppColors.primaryLight),
          suffixIcon: Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.glass.withOpacity(0.05),
          border: border,
          enabledBorder: border,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        child: Text(
          selectedCountry ?? 'Select country',
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyMedium.copyWith(
            color: selectedCountry != null
                ? AppColors.textPrimary
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
