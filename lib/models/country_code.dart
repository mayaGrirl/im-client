/// 国家区号模型

/// 国家区号信息
class CountryCode {
  final String code;        // 区号，如 "86", "1"
  final String country;     // 国家/地区英文名
  final String countryZh;   // 国家/地区中文名
  final String flag;        // 国旗emoji
  final List<int> phoneLength; // 允许的手机号长度
  final String pattern;     // 验证正则
  final String example;     // 示例号码

  const CountryCode({
    required this.code,
    required this.country,
    required this.countryZh,
    required this.flag,
    required this.phoneLength,
    required this.pattern,
    required this.example,
  });

  factory CountryCode.fromJson(Map<String, dynamic> json) {
    return CountryCode(
      code: json['code'] as String,
      country: json['country'] as String,
      countryZh: json['country_zh'] as String,
      flag: json['flag'] as String? ?? '',
      phoneLength: (json['phone_length'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList() ?? [],
      pattern: json['pattern'] as String? ?? '',
      example: json['example'] as String? ?? '',
    );
  }

  /// 显示文本 (国旗 + 中文名 + 区号)
  String get displayName => '$flag $countryZh (+$code)';

  /// 短显示 (国旗 + 区号)
  String get shortDisplay => '$flag +$code';

  /// 验证手机号格式
  bool validatePhone(String phone) {
    if (pattern.isEmpty) {
      // 没有正则时只验证长度
      return phoneLength.isEmpty || phoneLength.contains(phone.length);
    }
    return RegExp(pattern).hasMatch(phone);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CountryCode &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;
}

/// 常用国家区号列表（内置，用于离线时）
const List<CountryCode> defaultCountryCodes = [
  // 中国大陆及港澳台
  CountryCode(code: '86', country: 'China', countryZh: '中国大陆', flag: '🇨🇳', phoneLength: [11], pattern: r'^1[3-9]\d{9}$', example: '13800138000'),
  CountryCode(code: '852', country: 'Hong Kong', countryZh: '中国香港', flag: '🇭🇰', phoneLength: [8], pattern: r'^[5-9]\d{7}$', example: '51234567'),
  CountryCode(code: '853', country: 'Macau', countryZh: '中国澳门', flag: '🇲🇴', phoneLength: [8], pattern: r'^6\d{7}$', example: '61234567'),
  CountryCode(code: '886', country: 'Taiwan', countryZh: '中国台湾', flag: '🇹🇼', phoneLength: [9], pattern: r'^9\d{8}$', example: '912345678'),

  // 亚洲
  CountryCode(code: '81', country: 'Japan', countryZh: '日本', flag: '🇯🇵', phoneLength: [10, 11], pattern: r'^[0-9]\d{9,10}$', example: '9012345678'),
  CountryCode(code: '82', country: 'South Korea', countryZh: '韩国', flag: '🇰🇷', phoneLength: [9, 10, 11], pattern: r'^1[0-9]\d{7,9}$', example: '1012345678'),
  CountryCode(code: '65', country: 'Singapore', countryZh: '新加坡', flag: '🇸🇬', phoneLength: [8], pattern: r'^[89]\d{7}$', example: '81234567'),
  CountryCode(code: '60', country: 'Malaysia', countryZh: '马来西亚', flag: '🇲🇾', phoneLength: [9, 10], pattern: r'^1[0-9]\d{7,8}$', example: '123456789'),
  CountryCode(code: '66', country: 'Thailand', countryZh: '泰国', flag: '🇹🇭', phoneLength: [9], pattern: r'^[689]\d{8}$', example: '812345678'),
  CountryCode(code: '84', country: 'Vietnam', countryZh: '越南', flag: '🇻🇳', phoneLength: [9, 10], pattern: r'^[0-9]\d{8,9}$', example: '912345678'),
  CountryCode(code: '62', country: 'Indonesia', countryZh: '印度尼西亚', flag: '🇮🇩', phoneLength: [9, 10, 11, 12], pattern: r'^8[0-9]\d{7,10}$', example: '81234567890'),
  CountryCode(code: '63', country: 'Philippines', countryZh: '菲律宾', flag: '🇵🇭', phoneLength: [10], pattern: r'^9[0-9]\d{8}$', example: '9123456789'),
  CountryCode(code: '91', country: 'India', countryZh: '印度', flag: '🇮🇳', phoneLength: [10], pattern: r'^[6-9]\d{9}$', example: '9123456789'),

  // 北美
  CountryCode(code: '1', country: 'United States', countryZh: '美国', flag: '🇺🇸', phoneLength: [10], pattern: r'^[2-9]\d{9}$', example: '2025551234'),

  // 欧洲
  CountryCode(code: '44', country: 'United Kingdom', countryZh: '英国', flag: '🇬🇧', phoneLength: [10, 11], pattern: r'^7[0-9]\d{8,9}$', example: '7911123456'),
  CountryCode(code: '49', country: 'Germany', countryZh: '德国', flag: '🇩🇪', phoneLength: [10, 11], pattern: r'^1[5-7][0-9]\d{7,8}$', example: '15123456789'),
  CountryCode(code: '33', country: 'France', countryZh: '法国', flag: '🇫🇷', phoneLength: [9], pattern: r'^[67]\d{8}$', example: '612345678'),
  CountryCode(code: '39', country: 'Italy', countryZh: '意大利', flag: '🇮🇹', phoneLength: [9, 10], pattern: r'^3[0-9]\d{7,8}$', example: '3123456789'),
  CountryCode(code: '34', country: 'Spain', countryZh: '西班牙', flag: '🇪🇸', phoneLength: [9], pattern: r'^[67]\d{8}$', example: '612345678'),
  CountryCode(code: '7', country: 'Russia', countryZh: '俄罗斯', flag: '🇷🇺', phoneLength: [10], pattern: r'^9[0-9]\d{8}$', example: '9123456789'),

  // 大洋洲
  CountryCode(code: '61', country: 'Australia', countryZh: '澳大利亚', flag: '🇦🇺', phoneLength: [9], pattern: r'^4[0-9]\d{7}$', example: '412345678'),
  CountryCode(code: '64', country: 'New Zealand', countryZh: '新西兰', flag: '🇳🇿', phoneLength: [8, 9], pattern: r'^2[0-9]\d{6,7}$', example: '21234567'),

  // 南美
  CountryCode(code: '55', country: 'Brazil', countryZh: '巴西', flag: '🇧🇷', phoneLength: [10, 11], pattern: r'^[1-9]\d{9,10}$', example: '11912345678'),
];
