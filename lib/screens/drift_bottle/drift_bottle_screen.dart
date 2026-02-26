/// 漂流瓶主页面 - 美化版
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:im_client/api/api_client.dart';
import 'package:im_client/api/drift_bottle_api.dart';
import 'package:im_client/constants/app_constants.dart';
import 'package:im_client/l10n/app_localizations.dart';
import 'drift_bottle_throw_screen.dart';
import 'drift_bottle_pick_result_screen.dart';
import 'drift_bottle_my_screen.dart';
import 'drift_bottle_chat_list_screen.dart';

class DriftBottleScreen extends StatefulWidget {
  const DriftBottleScreen({super.key});

  @override
  State<DriftBottleScreen> createState() => _DriftBottleScreenState();
}

class _DriftBottleScreenState extends State<DriftBottleScreen>
    with TickerProviderStateMixin {
  final DriftBottleApi _api = DriftBottleApi(ApiClient());

  // 动画控制器
  late AnimationController _waveController;
  late AnimationController _cloudController;
  late AnimationController _seagullController;
  late AnimationController _fishController;
  late AnimationController _bottleController;
  late AnimationController _pickAnimController;

  BottleConfig? _config;
  bool _isLoading = true;
  bool _isPicking = false;
  int _targetGender = 0;

  // 海鸥位置
  final List<_SeagullData> _seagulls = [];
  // 鱼儿位置
  final List<_FishData> _fishes = [];
  // 云朵位置
  final List<_CloudData> _clouds = [];

  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _generateSeagulls();
    _generateFishes();
    _generateClouds();
    _loadConfig();
  }

  void _initAnimations() {
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _cloudController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();

    _seagullController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _fishController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _bottleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pickAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  void _generateSeagulls() {
    for (int i = 0; i < 5; i++) {
      _seagulls.add(_SeagullData(
        startX: _random.nextDouble() * 1.5 - 0.25,
        y: _random.nextDouble() * 0.15 + 0.05,
        speed: _random.nextDouble() * 0.3 + 0.2,
        size: _random.nextDouble() * 0.3 + 0.7,
        delay: _random.nextDouble(),
      ));
    }
  }

  void _generateFishes() {
    for (int i = 0; i < 8; i++) {
      _fishes.add(_FishData(
        startX: _random.nextDouble(),
        y: _random.nextDouble() * 0.3 + 0.6,
        speed: _random.nextDouble() * 0.2 + 0.1,
        size: _random.nextDouble() * 0.5 + 0.5,
        type: _random.nextInt(4), // 0-3 不同类型的鱼
        goingRight: _random.nextBool(),
      ));
    }
  }

  void _generateClouds() {
    for (int i = 0; i < 4; i++) {
      _clouds.add(_CloudData(
        startX: _random.nextDouble() * 1.2 - 0.1,
        y: _random.nextDouble() * 0.1 + 0.02,
        speed: _random.nextDouble() * 0.1 + 0.05,
        size: _random.nextDouble() * 0.5 + 0.8,
        opacity: _random.nextDouble() * 0.3 + 0.6,
      ));
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _cloudController.dispose();
    _seagullController.dispose();
    _fishController.dispose();
    _bottleController.dispose();
    _pickAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    try {
      final result = await _api.getConfig();
      if (result.success && result.data != null) {
        setState(() {
          _config = BottleConfig.fromJson(result.data);
        });
      }
    } catch (e) {
      // Config loading failed
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickBottle() async {
    if (_isPicking) return;
    final l10n = AppLocalizations.of(context)!;
    if (_config != null && _config!.remainingPicks <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('pick_limit_reached'))),
      );
      return;
    }

    setState(() => _isPicking = true);
    _pickAnimController.forward(from: 0);

    try {
      final result = await _api.pickBottle(targetGender: _targetGender);

      // 等待动画完成
      await Future.delayed(const Duration(milliseconds: 1200));

      if (result.success && result.data != null) {
        final bottle = DriftBottle.fromJson(result.data);
        _loadConfig();
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DriftBottlePickResultScreen(bottle: bottle),
            ),
          ).then((_) => _loadConfig());
        }
      } else {
        // 没有捞到瓶子，显示海产品
        if (mounted) {
          _showSeaCreature();
        }
      }
    } catch (e) {
      if (mounted) {
        _showSeaCreature();
      }
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  void _showSeaCreature() {
    final l10n = AppLocalizations.of(context)!;
    final creatures = [
      {'emoji': '🦀', 'name': l10n.translate('sea_creature_crab'), 'desc': l10n.translate('sea_creature_crab_desc')},
      {'emoji': '🦐', 'name': l10n.translate('sea_creature_shrimp'), 'desc': l10n.translate('sea_creature_shrimp_desc')},
      {'emoji': '🐟', 'name': l10n.translate('sea_creature_fish'), 'desc': l10n.translate('sea_creature_fish_desc')},
      {'emoji': '🦑', 'name': l10n.translate('sea_creature_squid'), 'desc': l10n.translate('sea_creature_squid_desc')},
      {'emoji': '🐚', 'name': l10n.translate('sea_creature_shell'), 'desc': l10n.translate('sea_creature_shell_desc')},
      {'emoji': '🦞', 'name': l10n.translate('sea_creature_lobster'), 'desc': l10n.translate('sea_creature_lobster_desc')},
      {'emoji': '🐡', 'name': l10n.translate('sea_creature_pufferfish'), 'desc': l10n.translate('sea_creature_pufferfish_desc')},
      {'emoji': '🦈', 'name': l10n.translate('sea_creature_shark'), 'desc': l10n.translate('sea_creature_shark_desc')},
      {'emoji': '🐙', 'name': l10n.translate('sea_creature_octopus'), 'desc': l10n.translate('sea_creature_octopus_desc')},
      {'emoji': '🪸', 'name': l10n.translate('sea_creature_coral'), 'desc': l10n.translate('sea_creature_coral_desc')},
      {'emoji': '🐠', 'name': l10n.translate('sea_creature_tropical_fish'), 'desc': l10n.translate('sea_creature_tropical_fish_desc')},
      {'emoji': '🦭', 'name': l10n.translate('sea_creature_seal'), 'desc': l10n.translate('sea_creature_seal_desc')},
    ];

    final creature = creatures[_random.nextInt(creatures.length)];

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white,
                Colors.blue.shade50,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 波浪装饰
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  creature['emoji']!,
                  style: const TextStyle(fontSize: 60),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.translate('caught_something').replaceAll('{name}', creature['name']!),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1565C0),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                creature['desc']!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.translate('no_bottle_try_again'),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.blue.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(l10n.translate('continue_picking')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGenderFilter() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.translate('select_bottle_gender'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildGenderOption(0, l10n.noLimit, Icons.people),
            _buildGenderOption(1, l10n.translate('boys_bottles'), Icons.male),
            _buildGenderOption(2, l10n.translate('girls_bottles'), Icons.female),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderOption(int gender, String label, IconData icon) {
    final isSelected = _targetGender == gender;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppColors.primary : Colors.grey,
      ),
      title: Text(label),
      trailing:
          isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
      onTap: () {
        setState(() => _targetGender = gender);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Stack(
        children: [
          // 背景渐变 - 天空
          _buildSkyBackground(),
          // 太阳
          _buildSun(),
          // 云朵
          _buildClouds(),
          // 海鸥
          _buildSeagulls(),
          // 海洋
          _buildOcean(),
          // 水下的鱼
          _buildFishes(),
          // 波浪
          _buildWaves(),
          // 漂浮的瓶子
          _buildFloatingBottle(),
          // 捞瓶子动画
          if (_isPicking) _buildPickingAnimation(),
          // UI内容
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                if (!_isLoading && _config != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: _buildRemainingInfo(),
                  ),
                const Spacer(),
                _buildActionButtons(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkyBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.3, 0.5, 0.7, 1.0],
          colors: [
            Color(0xFF87CEEB), // 浅蓝天空
            Color(0xFF98D8E8), // 淡蓝
            Color(0xFF5BB5E0), // 天蓝
            Color(0xFF1E90FF), // 道奇蓝 - 海面
            Color(0xFF0066AA), // 深海蓝
          ],
        ),
      ),
    );
  }

  Widget _buildSun() {
    return Positioned(
      top: 60,
      right: 40,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [
              Color(0xFFFFEB3B),
              Color(0xFFFFD54F),
              Color(0x00FFD54F),
            ],
            stops: [0.0, 0.4, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.yellow.withOpacity(0.5),
              blurRadius: 30,
              spreadRadius: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClouds() {
    return AnimatedBuilder(
      animation: _cloudController,
      builder: (context, child) {
        return Stack(
          children: _clouds.map((cloud) {
            double x = (cloud.startX + _cloudController.value * cloud.speed) %
                1.3 - 0.15;
            return Positioned(
              left: MediaQuery.of(context).size.width * x,
              top: MediaQuery.of(context).size.height * cloud.y,
              child: Opacity(
                opacity: cloud.opacity,
                child: Transform.scale(
                  scale: cloud.size,
                  child: _buildCloudShape(),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCloudShape() {
    return SizedBox(
      width: 120,
      height: 50,
      child: Stack(
        children: [
          Positioned(
            left: 10,
            top: 20,
            child: Container(
              width: 50,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            left: 30,
            top: 5,
            child: Container(
              width: 60,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
          Positioned(
            left: 60,
            top: 15,
            child: Container(
              width: 50,
              height: 35,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeagulls() {
    return AnimatedBuilder(
      animation: _seagullController,
      builder: (context, child) {
        return Stack(
          children: _seagulls.map((seagull) {
            double progress = (_seagullController.value + seagull.delay) % 1.0;
            double x = (seagull.startX + progress * seagull.speed * 3) % 1.4 - 0.2;
            double yOffset = sin(progress * 4 * pi) * 10;

            return Positioned(
              left: MediaQuery.of(context).size.width * x,
              top: MediaQuery.of(context).size.height * seagull.y + yOffset,
              child: Transform.scale(
                scale: seagull.size,
                child: _buildSeagull(progress),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSeagull(double progress) {
    double wingAngle = sin(progress * 20 * pi) * 0.3;
    return SizedBox(
      width: 40,
      height: 20,
      child: CustomPaint(
        painter: _SeagullPainter(wingAngle),
      ),
    );
  }

  Widget _buildOcean() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: MediaQuery.of(context).size.height * 0.45,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1E90FF).withOpacity(0.0),
              const Color(0xFF1E90FF),
              const Color(0xFF0066AA),
              const Color(0xFF004477),
            ],
            stops: const [0.0, 0.1, 0.5, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildFishes() {
    return AnimatedBuilder(
      animation: _fishController,
      builder: (context, child) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;

        return Stack(
          children: _fishes.map((fish) {
            double progress = (_fishController.value + fish.startX) % 1.0;
            double x = fish.goingRight
                ? progress * 1.2 - 0.1
                : 1.1 - progress * 1.2;
            double yOffset = sin(progress * 6 * pi) * 15;

            return Positioned(
              left: screenWidth * x,
              top: screenHeight * fish.y + yOffset,
              child: Transform(
                transform: Matrix4.identity()
                  ..scale(fish.goingRight ? 1.0 : -1.0, 1.0),
                alignment: Alignment.center,
                child: Transform.scale(
                  scale: fish.size * 0.6,
                  child: _buildFishIcon(fish.type),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildFishIcon(int type) {
    final fishEmojis = ['🐟', '🐠', '🐡', '🦈'];
    return Text(
      fishEmojis[type % fishEmojis.length],
      style: const TextStyle(fontSize: 30),
    );
  }

  Widget _buildWaves() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: 150,
      child: AnimatedBuilder(
        animation: _waveController,
        builder: (context, child) {
          return CustomPaint(
            painter: _WavePainter(_waveController.value),
            size: Size(MediaQuery.of(context).size.width, 150),
          );
        },
      ),
    );
  }

  Widget _buildFloatingBottle() {
    return AnimatedBuilder(
      animation: _bottleController,
      builder: (context, child) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        double yOffset = _bottleController.value * 15;
        double rotation = sin(_bottleController.value * 2 * pi) * 0.1;

        return Positioned(
          left: screenWidth * 0.5 - 30,
          top: screenHeight * 0.45 + yOffset,
          child: Transform.rotate(
            angle: rotation,
            child: Container(
              width: 60,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.brown.shade100.withOpacity(0.9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.brown.shade300,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 20,
                    height: 15,
                    decoration: BoxDecoration(
                      color: Colors.brown.shade400,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Icon(
                    Icons.mail,
                    color: Colors.brown.shade600,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPickingAnimation() {
    return AnimatedBuilder(
      animation: _pickAnimController,
      builder: (context, child) {
        return Center(
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.3 * (1 - _pickAnimController.value)),
            ),
            child: Center(
              child: Transform.scale(
                scale: 1 + _pickAnimController.value * 0.5,
                child: const Icon(
                  Icons.catching_pokemon,
                  size: 60,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              l10n.driftBottle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              switch (value) {
                case 'my':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DriftBottleMyScreen()),
                  ).then((_) => _loadConfig());
                  break;
                case 'chats':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DriftBottleChatListScreen()),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'my',
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined),
                    const SizedBox(width: 8),
                    Text(l10n.myBottles),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'chats',
                child: Row(
                  children: [
                    const Icon(Icons.chat_outlined),
                    const SizedBox(width: 8),
                    Text(l10n.driftConversations),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRemainingInfo() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white38),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCountItem(l10n.translate('throw_bottle'), _config!.remainingThrows, _config!.dailyThrowLimit),
          Container(
            width: 1,
            height: 35,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            color: Colors.white38,
          ),
          _buildCountItem(l10n.pickBottle, _config!.remainingPicks, _config!.dailyPickLimit),
        ],
      ),
    );
  }

  Widget _buildCountItem(String label, int remaining, int total) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Text(
          '$remaining/$total',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(1, 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${l10n.translate('can_action_today')}$label',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: Icons.send_rounded,
              label: l10n.throwBottle,
              gradient: const LinearGradient(
                colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const DriftBottleThrowScreen()),
                ).then((_) => _loadConfig());
              },
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: _buildActionButton(
              icon: Icons.catching_pokemon,
              label: _isPicking ? l10n.translate('picking_up') : l10n.pickBottle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFB74D), Color(0xFFF57C00)],
              ),
              onTap: _isPicking ? null : _pickBottle,
              onLongPress: _showGenderFilter,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Gradient gradient,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 36),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (onLongPress != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.translate('press_to_filter'),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// 数据类
class _SeagullData {
  final double startX;
  final double y;
  final double speed;
  final double size;
  final double delay;

  _SeagullData({
    required this.startX,
    required this.y,
    required this.speed,
    required this.size,
    required this.delay,
  });
}

class _FishData {
  final double startX;
  final double y;
  final double speed;
  final double size;
  final int type;
  final bool goingRight;

  _FishData({
    required this.startX,
    required this.y,
    required this.speed,
    required this.size,
    required this.type,
    required this.goingRight,
  });
}

class _CloudData {
  final double startX;
  final double y;
  final double speed;
  final double size;
  final double opacity;

  _CloudData({
    required this.startX,
    required this.y,
    required this.speed,
    required this.size,
    required this.opacity,
  });
}

// 海鸥绘制
class _SeagullPainter extends CustomPainter {
  final double wingAngle;

  _SeagullPainter(this.wingAngle);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // 左翅膀
    final leftWing = Path();
    leftWing.moveTo(centerX, centerY);
    leftWing.quadraticBezierTo(
      centerX - 12,
      centerY - 8 + wingAngle * 20,
      centerX - 18,
      centerY + wingAngle * 15,
    );
    canvas.drawPath(leftWing, paint);

    // 右翅膀
    final rightWing = Path();
    rightWing.moveTo(centerX, centerY);
    rightWing.quadraticBezierTo(
      centerX + 12,
      centerY - 8 + wingAngle * 20,
      centerX + 18,
      centerY + wingAngle * 15,
    );
    canvas.drawPath(rightWing, paint);
  }

  @override
  bool shouldRepaint(_SeagullPainter oldDelegate) =>
      wingAngle != oldDelegate.wingAngle;
}

// 波浪绘制
class _WavePainter extends CustomPainter {
  final double animationValue;

  _WavePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    // 第一层波浪 - 最前面，最亮
    _drawWave(
      canvas,
      size,
      Colors.white.withOpacity(0.4),
      0.3,
      25,
      animationValue,
      0,
    );

    // 第二层波浪
    _drawWave(
      canvas,
      size,
      Colors.white.withOpacity(0.3),
      0.45,
      20,
      animationValue,
      0.5,
    );

    // 第三层波浪 - 最后面
    _drawWave(
      canvas,
      size,
      Colors.white.withOpacity(0.2),
      0.6,
      15,
      animationValue,
      1.0,
    );
  }

  void _drawWave(
    Canvas canvas,
    Size size,
    Color color,
    double heightFactor,
    double amplitude,
    double animation,
    double phaseOffset,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);

    for (double i = 0; i <= size.width; i++) {
      final y = size.height * heightFactor +
          amplitude *
              sin((i / size.width * 2 * pi) +
                  (animation * 2 * pi) +
                  phaseOffset);
      path.lineTo(i, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) => true;
}
