/// 国家区号选择器组件

import 'package:flutter/material.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'package:im_client/models/country_code.dart';

/// 国家区号选择器
class CountryCodePicker extends StatefulWidget {
  final CountryCode selectedCountry;
  final ValueChanged<CountryCode> onChanged;
  final bool showFullName; // 是否显示完整名称

  const CountryCodePicker({
    super.key,
    required this.selectedCountry,
    required this.onChanged,
    this.showFullName = false,
  });

  @override
  State<CountryCodePicker> createState() => _CountryCodePickerState();
}

class _CountryCodePickerState extends State<CountryCodePicker> {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showCountryPicker(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.showFullName
                  ? widget.selectedCountry.displayName
                  : widget.selectedCountry.shortDisplay,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }

  void _showCountryPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CountryCodePickerSheet(
        selectedCountry: widget.selectedCountry,
        onSelect: widget.onChanged,
      ),
    );
  }
}

/// 国家区号选择底部弹窗
class CountryCodePickerSheet extends StatefulWidget {
  final CountryCode selectedCountry;
  final ValueChanged<CountryCode> onSelect;

  const CountryCodePickerSheet({
    super.key,
    required this.selectedCountry,
    required this.onSelect,
  });

  @override
  State<CountryCodePickerSheet> createState() => _CountryCodePickerSheetState();
}

class _CountryCodePickerSheetState extends State<CountryCodePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<CountryCode> _countries = [];
  List<CountryCode> _filteredCountries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    try {
      // 尝试从服务器获取
      final response = await ApiClient().get('/country-codes');
      if (response.success && response.data != null) {
        final List<dynamic> data = response.data as List<dynamic>;
        _countries = data.map((e) => CountryCode.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      // 使用默认列表
      debugPrint('Failed to load country codes from server: $e');
    }

    // 如果服务器没有返回数据，使用默认列表
    if (_countries.isEmpty) {
      _countries = defaultCountryCodes.toList();
    }

    setState(() {
      _filteredCountries = _countries;
      _isLoading = false;
    });
  }

  void _filterCountries(String query) {
    if (query.isEmpty) {
      setState(() => _filteredCountries = _countries);
      return;
    }

    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredCountries = _countries.where((c) {
        return c.code.contains(query) ||
            c.country.toLowerCase().contains(lowerQuery) ||
            c.countryZh.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 拖拽条
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 标题栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 16),
                Text(
                  l10n.translate('selectCountryRegion'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // 搜索框
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterCountries,
              decoration: InputDecoration(
                hintText: l10n.translate('searchCountryOrCode'),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 国家列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _filteredCountries.length,
                    itemBuilder: (context, index) {
                      final country = _filteredCountries[index];
                      final isSelected = country.code == widget.selectedCountry.code;
                      return ListTile(
                        leading: Text(
                          country.flag,
                          style: const TextStyle(fontSize: 24),
                        ),
                        title: Text(country.countryZh),
                        subtitle: Text(country.country),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '+${country.code}',
                              style: TextStyle(
                                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.check, color: AppColors.primary, size: 20),
                            ],
                          ],
                        ),
                        selected: isSelected,
                        onTap: () {
                          widget.onSelect(country);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 带国家区号的手机号输入组件
class PhoneInputField extends StatelessWidget {
  final TextEditingController phoneController;
  final CountryCode selectedCountry;
  final ValueChanged<CountryCode> onCountryChanged;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final FormFieldValidator<String>? validator;

  const PhoneInputField({
    super.key,
    required this.phoneController,
    required this.selectedCountry,
    required this.onCountryChanged,
    this.labelText,
    this.hintText,
    this.helperText,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 国家选择器
        CountryCodePicker(
          selectedCountry: selectedCountry,
          onChanged: onCountryChanged,
        ),
        const SizedBox(width: 12),
        // 手机号输入框
        Expanded(
          child: TextFormField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: labelText ?? (l10n?.translate('phoneNumber') ?? 'Phone Number'),
              hintText: hintText ?? selectedCountry.example,
              helperText: helperText,
              prefixIcon: const Icon(Icons.phone),
            ),
            validator: validator ?? (value) {
              if (value == null || value.isEmpty) {
                return l10n?.translate('pleaseEnterPhone') ?? 'Please enter phone number';
              }
              if (!selectedCountry.validatePhone(value)) {
                return l10n?.translate('phoneFormatIncorrect') ?? 'Invalid phone number format';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }
}
