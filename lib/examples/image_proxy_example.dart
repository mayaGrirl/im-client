/// 图片代理使用示例
/// 
/// 展示如何在不同场景下使用图片代理功能
library;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/image_proxy.dart';

/// 示例1：基础用法
class BasicImageProxyExample extends StatelessWidget {
  const BasicImageProxyExample({super.key});

  @override
  Widget build(BuildContext context) {
    const avatarUrl = 'https://randomuser.me/api/portraits/women/29.jpg';

    return Scaffold(
      appBar: AppBar(title: const Text('基础用法示例')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 方法1：使用扩展方法（推荐）
            Image.network(
              avatarUrl.proxied,
              width: 100,
              height: 100,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.error, size: 100);
              },
            ),
            const SizedBox(height: 20),
            Text('原始URL: $avatarUrl'),
            Text('代理URL: ${avatarUrl.proxied}'),
            Text('需要代理: ${avatarUrl.needsProxy}'),
          ],
        ),
      ),
    );
  }
}

/// 示例2：用户头像列表
class UserAvatarListExample extends StatelessWidget {
  const UserAvatarListExample({super.key});

  // 模拟用户数据
  static final List<Map<String, String>> users = [
    {
      'name': 'Alice',
      'avatar': 'https://randomuser.me/api/portraits/women/1.jpg',
    },
    {
      'name': 'Bob',
      'avatar': 'https://randomuser.me/api/portraits/men/2.jpg',
    },
    {
      'name': 'Carol',
      'avatar': 'https://xsgames.co/randomusers/avatar.php?g=female&seed=Carol',
    },
    {
      'name': 'David',
      'avatar': 'https://i.pravatar.cc/150?img=3',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('用户头像列表')),
      body: ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(user['avatar']!.proxied),
              onBackgroundImageError: (exception, stackTrace) {
                debugPrint('加载头像失败: $exception');
              },
            ),
            title: Text(user['name']!),
            subtitle: Text(user['avatar']!),
          );
        },
      ),
    );
  }
}

/// 示例3：使用CachedNetworkImage
class CachedImageExample extends StatelessWidget {
  const CachedImageExample({super.key});

  @override
  Widget build(BuildContext context) {
    const imageUrl = 'https://picsum.photos/400/300';

    return Scaffold(
      appBar: AppBar(title: const Text('缓存图片示例')),
      body: Center(
        child: CachedNetworkImage(
          imageUrl: imageUrl.proxied,
          placeholder: (context, url) => const CircularProgressIndicator(),
          errorWidget: (context, url, error) => const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 50, color: Colors.red),
              SizedBox(height: 10),
              Text('加载失败'),
            ],
          ),
          width: 400,
          height: 300,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

/// 示例4：图片网格
class ImageGridExample extends StatelessWidget {
  const ImageGridExample({super.key});

  // 模拟图片URL列表
  static final List<String> imageUrls = List.generate(
    20,
    (index) => 'https://picsum.photos/200/200?random=$index',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('图片网格示例')),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          return Image.network(
            imageUrls[index].proxied,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image),
              );
            },
          );
        },
      ),
    );
  }
}

/// 示例5：处理可空URL
class NullableUrlExample extends StatelessWidget {
  const NullableUrlExample({super.key});

  @override
  Widget build(BuildContext context) {
    // 模拟可能为空的URL
    String? avatarUrl;
    const defaultAvatar = 'https://ui-avatars.com/api/?name=Default&size=200';

    return Scaffold(
      appBar: AppBar(title: const Text('可空URL处理')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 方法1：使用 ?? 运算符
            CircleAvatar(
              backgroundImage: NetworkImage(
                avatarUrl?.proxied ?? defaultAvatar.proxied,
              ),
              radius: 50,
            ),
            const SizedBox(height: 20),
            // 方法2：使用条件表达式
            if (avatarUrl != null)
              Image.network(avatarUrl.proxied)
            else
              Image.network(defaultAvatar.proxied),
          ],
        ),
      ),
    );
  }
}

/// 示例6：批量URL转换
class BatchUrlConversionExample extends StatelessWidget {
  const BatchUrlConversionExample({super.key});

  @override
  Widget build(BuildContext context) {
    final originalUrls = [
      'https://randomuser.me/api/portraits/women/1.jpg',
      'https://randomuser.me/api/portraits/women/2.jpg',
      'https://randomuser.me/api/portraits/women/3.jpg',
    ];

    // 方法1：使用map
    final proxiedUrls1 = originalUrls.map((url) => url.proxied).toList();

    // 方法2：使用工具类
    final proxiedUrls2 = ImageProxy.getProxiedUrls(originalUrls);

    return Scaffold(
      appBar: AppBar(title: const Text('批量转换示例')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('原始URLs:', style: TextStyle(fontWeight: FontWeight.bold)),
          ...originalUrls.map((url) => Text(url)),
          const SizedBox(height: 20),
          const Text('代理URLs:', style: TextStyle(fontWeight: FontWeight.bold)),
          ...proxiedUrls1.map((url) => Text(url, style: const TextStyle(fontSize: 10))),
          const SizedBox(height: 20),
          const Text('预览:', style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: proxiedUrls2
                .map((url) => Image.network(url, width: 100, height: 100))
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// 示例7：检查是否需要代理
class ProxyCheckExample extends StatelessWidget {
  const ProxyCheckExample({super.key});

  @override
  Widget build(BuildContext context) {
    final testUrls = [
      'https://randomuser.me/api/portraits/women/1.jpg', // 需要代理
      'https://yourdomain.com/uploads/avatar.jpg', // 不需要代理
      'https://xsgames.co/randomusers/avatar.php', // 需要代理
      '/uploads/local-image.jpg', // 本地路径，不需要代理
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('代理检查示例')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: testUrls.length,
        itemBuilder: (context, index) {
          final url = testUrls[index];
          final needsProxy = url.needsProxy;

          return Card(
            child: ListTile(
              leading: Icon(
                needsProxy ? Icons.vpn_lock : Icons.link,
                color: needsProxy ? Colors.orange : Colors.green,
              ),
              title: Text(url),
              subtitle: Text(needsProxy ? '需要代理' : '不需要代理'),
              trailing: needsProxy
                  ? const Chip(
                      label: Text('代理'),
                      backgroundColor: Colors.orange,
                    )
                  : const Chip(
                      label: Text('直连'),
                      backgroundColor: Colors.green,
                    ),
            ),
          );
        },
      ),
    );
  }
}

/// 主示例页面
class ImageProxyExamplesPage extends StatelessWidget {
  const ImageProxyExamplesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('图片代理示例')),
      body: ListView(
        children: [
          _buildExampleTile(
            context,
            '基础用法',
            '展示如何使用扩展方法',
            () => const BasicImageProxyExample(),
          ),
          _buildExampleTile(
            context,
            '用户头像列表',
            '在列表中显示多个用户头像',
            () => const UserAvatarListExample(),
          ),
          _buildExampleTile(
            context,
            '缓存图片',
            '使用CachedNetworkImage',
            () => const CachedImageExample(),
          ),
          _buildExampleTile(
            context,
            '图片网格',
            '在网格中显示多张图片',
            () => const ImageGridExample(),
          ),
          _buildExampleTile(
            context,
            '可空URL处理',
            '处理可能为空的图片URL',
            () => const NullableUrlExample(),
          ),
          _buildExampleTile(
            context,
            '批量转换',
            '批量转换多个URL',
            () => const BatchUrlConversionExample(),
          ),
          _buildExampleTile(
            context,
            '代理检查',
            '检查URL是否需要代理',
            () => const ProxyCheckExample(),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleTile(
    BuildContext context,
    String title,
    String subtitle,
    Widget Function() builder,
  ) {
    return ListTile(
      leading: const Icon(Icons.image),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => builder()),
        );
      },
    );
  }
}
