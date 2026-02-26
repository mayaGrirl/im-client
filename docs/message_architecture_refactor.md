# 消息架构重构 - 客户端技术文档

## 概述

本次重构实现了"消息存储在客户端，服务端只做消息中转"的架构设计。客户端成为消息的唯一持久化存储位置。

### 存储架构

```
┌─────────────────────────────────────────────────────────┐
│                     ChatProvider                         │
│                    (状态管理层)                          │
├─────────────────────────────────────────────────────────┤
│                          │                               │
│          ┌───────────────┼───────────────┐              │
│          ▼               ▼               ▼              │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐    │
│  │LocalMessage  │ │LocalDatabase │ │  WebSocket   │    │
│  │  Service     │ │   Service    │ │   Service    │    │
│  │   (Hive)     │ │   (SQLite)   │ │              │    │
│  │  持久化存储   │ │  运行时缓存   │ │   消息中转   │    │
│  └──────────────┘ └──────────────┘ └──────────────┘    │
└─────────────────────────────────────────────────────────┘
```

| 组件 | 角色 | 特点 |
|------|------|------|
| **LocalMessageService (Hive)** | 主存储/持久化 | 跨会话保持、支持备份导出 |
| **LocalDatabaseService (SQLite)** | 运行时缓存 | 快速查询、会话内有效 |
| **WebSocketService** | 消息接收 | 实时推送 |

---

## 修改文件清单

### 1. `lib/services/local_message_service.dart`

#### 新增方法

##### searchMessages - 本地消息搜索

```dart
/// 搜索消息
/// 在本地存储中搜索包含关键词的消息
Future<List<Message>> searchMessages(
  String keyword,
  {String? conversId, int limit = 50}
) async
```

**参数**:
- `keyword`: 搜索关键词
- `conversId`: 可选，限定搜索的会话
- `limit`: 返回结果数量限制，默认50

**使用示例**:
```dart
final results = await localMessageService.searchMessages(
  '重要',
  conversId: 'p_1_2',
  limit: 20,
);
```

---

##### getLastSyncMsgId / setLastSyncMsgId - 同步位置记录

```dart
/// 获取最后同步的消息ID
Future<String?> getLastSyncMsgId(String conversId) async

/// 设置最后同步的消息ID
Future<void> setLastSyncMsgId(String conversId, String msgId) async
```

**用途**: 记录每个会话的同步进度，支持增量同步

**使用示例**:
```dart
// 获取上次同步位置
final lastMsgId = await localMessageService.getLastSyncMsgId('p_1_2');

// 更新同步位置
await localMessageService.setLastSyncMsgId('p_1_2', 'new-msg-id');
```

---

##### exportMessages / importMessages - 备份恢复

```dart
/// 导出消息（用于备份）
/// 返回包含所有消息和会话的JSON数据
Future<Map<String, dynamic>> exportMessages() async

/// 导入消息（用于恢复）
/// 从备份数据恢复消息和会话
Future<int> importMessages(Map<String, dynamic> exportData) async
```

**导出数据结构**:
```json
{
  "version": 1,
  "export_time": "2024-01-15T10:30:00.000Z",
  "messages": [
    {
      "msg_id": "uuid-xxx",
      "convers_id": "p_1_2",
      "from_user_id": 1,
      "content": "消息内容",
      ...
    }
  ],
  "conversations": [
    {
      "convers_id": "p_1_2",
      "type": 1,
      "target_id": 2,
      ...
    }
  ]
}
```

**使用示例**:
```dart
// 导出备份
final backupData = await localMessageService.exportMessages();
final jsonString = jsonEncode(backupData);
// 保存到文件...

// 导入备份
final importedCount = await localMessageService.importMessages(backupData);
print('导入了 $importedCount 条消息');
```

---

##### getMessageById - 按ID查找消息

```dart
/// 根据消息ID获取消息（不需要conversId）
Future<Message?> getMessageById(String msgId) async
```

**用途**: 当只有消息ID时查找消息（如通知跳转）

---

##### getMessageContext - 获取消息上下文

```dart
/// 获取消息上下文（前后N条消息）
Future<Map<String, List<Message>>> getMessageContext(
  String conversId,
  String msgId,
  {int before = 5, int after = 5}
) async
```

**返回结构**:
```dart
{
  'before': [Message, Message, ...], // 时间更早的消息
  'after': [Message, Message, ...]   // 时间更晚的消息
}
```

---

### 2. `lib/providers/chat_provider.dart`

#### saveMessage - 统一存储

**修改前**: 只写入SQLite缓存
**修改后**: 同时写入Hive持久化存储和SQLite缓存

```dart
/// 保存消息到本地
/// 统一存储策略：同时写入持久化存储(Hive)和运行时缓存(SQLite)
Future<void> saveMessage(Message message) async {
  // 1. 写入持久化存储 (LocalMessageService - Hive)
  await _localMessageService.saveMessage(message);
  // 2. 写入运行时缓存 (LocalDatabaseService - SQLite)
  await _localDb.saveMessage(message);
}
```

---

#### getMessages - 优先缓存策略

**修改前**: 只从SQLite获取
**修改后**: 优先从缓存获取，不足时从持久化存储补充

```dart
/// 获取会话消息
/// 统一存储策略：优先从运行时缓存获取，缓存不足时从持久化存储补充
Future<List<Message>> getMessages({
  required String conversId,
  int limit = 20,
  DateTime? beforeTime,
}) async {
  // 1. 先从运行时缓存获取
  var messages = await _localDb.getMessages(...);

  // 2. 如果缓存数据不足，从持久化存储获取
  if (messages.length < limit) {
    final persistedMessages = await _localMessageService.getMessages(...);
    // 合并去重并同步到缓存
    ...
  }

  return messages;
}
```

---

#### 新增方法

```dart
/// 从持久化存储同步数据到运行时缓存
/// 用于应用启动时预热缓存
Future<void> _syncCacheFromPersistence(String conversId, {int limit = 50}) async

/// 搜索本地消息
Future<List<Message>> searchLocalMessages(String keyword, {String? conversId, int limit = 50}) async

/// 导出消息备份
Future<Map<String, dynamic>> exportMessages() async

/// 导入消息备份
Future<int> importMessages(Map<String, dynamic> exportData) async

/// 获取消息上下文
Future<Map<String, List<Message>>> getMessageContext(String conversId, String msgId, {int before = 5, int after = 5}) async
```

---

#### getOrCreateConversation - 缓存预热

**新增**: 打开会话时自动预热缓存

```dart
Future<Conversation> getOrCreateConversation({...}) async {
  ...
  if (conversation != null) {
    // 预热缓存：从持久化存储同步最近消息到运行时缓存
    await _syncCacheFromPersistence(conversId, limit: 50);
    return conversation;
  }
  ...
}
```

---

### 3. `lib/utils/conversation_utils.dart` (新建)

#### 会话ID工具类

```dart
class ConversationUtils {
  /// 生成会话ID
  /// 私聊格式: p_小ID_大ID
  /// 群聊格式: g_群ID
  static String generateConversId({
    int? userId1,
    int? userId2,
    int? groupId,
  })

  /// 解析会话ID
  /// 返回: {type, userId1, userId2, groupId}
  static Map<String, dynamic> parseConversId(String conversId)

  /// 获取私聊对方的用户ID
  static int? getTargetUserId(String conversId, int currentUserId)

  /// 判断是否是群聊会话
  static bool isGroupConversation(String conversId)

  /// 判断是否是私聊会话
  static bool isPrivateConversation(String conversId)

  /// 从群聊会话ID获取群组ID
  static int? getGroupId(String conversId)

  /// 判断用户是否是会话参与者
  static bool isParticipant(String conversId, int userId)
}
```

**使用示例**:
```dart
// 生成私聊会话ID
final conversId = ConversationUtils.generateConversId(
  userId1: 1,
  userId2: 5,
); // 返回: "p_1_5"

// 生成群聊会话ID
final groupConversId = ConversationUtils.generateConversId(
  groupId: 100,
); // 返回: "g_100"

// 解析会话ID
final info = ConversationUtils.parseConversId('p_1_5');
// info = {type: 1, userId1: 1, userId2: 5, groupId: null}

// 获取私聊对方ID
final targetId = ConversationUtils.getTargetUserId('p_1_5', 1);
// targetId = 5
```

---

### 4. `lib/models/message.dart` - 类型安全修复

#### Message.fromJson

**问题**: JSON解码产生的`LinkedMap<dynamic, dynamic>`无法直接作为`Map<String, dynamic>`使用

**修复**: 添加安全类型转换

```dart
factory Message.fromJson(Map<String, dynamic> json) {
  // 辅助函数：安全地转换为Map<String, dynamic>
  Map<String, dynamic>? toMap(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  // 安全解析嵌套的from_user对象
  User? fromUser;
  final fromUserMap = toMap(json['from_user']);
  if (fromUserMap != null) {
    fromUser = User.fromJson(fromUserMap);
  }

  // 安全解析嵌套的reply_message对象
  ReplyMessageInfo? replyMessage;
  final replyMessageMap = toMap(json['reply_message']);
  if (replyMessageMap != null) {
    replyMessage = ReplyMessageInfo.fromJson(replyMessageMap);
  }

  return Message(...);
}
```

---

#### Conversation.fromJson

```dart
factory Conversation.fromJson(Map<String, dynamic> json) {
  // 安全解析targetInfo，确保是Map<String, dynamic>类型
  dynamic targetInfo = json['target_info'];
  if (targetInfo != null && targetInfo is Map && targetInfo is! Map<String, dynamic>) {
    targetInfo = Map<String, dynamic>.from(targetInfo);
  }
  ...
}
```

---

### 5. `lib/models/user.dart` - 类型安全修复

#### Friend.fromJson

```dart
factory Friend.fromJson(Map<String, dynamic> json) {
  final friendData = json['friend'];
  if (friendData != null) {
    if (friendData is Map<String, dynamic>) {
      friendUser = User.fromJson(friendData);
    } else if (friendData is Map) {
      friendUser = User.fromJson(Map<String, dynamic>.from(friendData));
    }
  }
  ...
}
```

#### FriendRequest.fromJson

```dart
factory FriendRequest.fromJson(Map<String, dynamic> json) {
  User? fromUser;
  final fromUserData = json['from_user'];
  if (fromUserData != null) {
    if (fromUserData is Map<String, dynamic>) {
      fromUser = User.fromJson(fromUserData);
    } else if (fromUserData is Map) {
      fromUser = User.fromJson(Map<String, dynamic>.from(fromUserData));
    }
  }
  ...
}
```

---

## WebSocket消息处理

### 需要监听的新消息类型

| 类型 | 说明 | 处理方式 |
|------|------|----------|
| `delete_messages` | 删除消息 | 从本地删除指定消息 |
| `clear_conversation` | 清空会话 | 清空本地会话消息 |
| `burn_message` | 阅后即焚销毁 | 从本地删除并销毁 |

### 处理示例

```dart
void _handleWebSocketMessage(Map<String, dynamic> data) async {
  final type = data['type'] as String?;

  switch (type) {
    case 'delete_messages':
      final msgIds = List<String>.from(data['data']['msg_ids']);
      for (final msgId in msgIds) {
        await _localMessageService.deleteMessage(conversId, msgId);
      }
      break;

    case 'clear_conversation':
      final conversId = data['data']['convers_id'];
      await _localMessageService.clearConversationMessages(conversId);
      break;

    case 'burn_message':
      final messageId = data['data']['message_id'];
      // 找到消息并删除
      final msg = await _localMessageService.getMessageById(messageId);
      if (msg != null) {
        await _localMessageService.deleteMessage(msg.conversId!, messageId);
      }
      break;
  }
}
```

---

## 迁移指南

### 1. 升级依赖

确保 `pubspec.yaml` 包含:
```yaml
dependencies:
  hive_flutter: ^1.1.0
```

### 2. 初始化顺序

```dart
// 在 main.dart 或应用初始化时
await LocalMessageService().init();
```

### 3. API调用变更

#### 收藏消息

**旧调用**:
```dart
await api.addFavorite(messageId: msg.msgId);
```

**新调用**:
```dart
await api.addFavorite(
  messageId: msg.msgId,
  contentType: msg.type,
  content: msg.content,
  fromUserId: msg.fromUserId,
);
```

---

## 验证方案

| 测试场景 | 验证点 |
|----------|--------|
| 发送消息 | 消息保存到Hive和SQLite |
| 接收消息 | WebSocket消息正确存储到本地 |
| 加载历史 | 从本地获取，不请求服务器 |
| 搜索消息 | searchLocalMessages返回正确结果 |
| 备份导出 | exportMessages生成完整数据 |
| 备份导入 | importMessages正确恢复数据 |
| 清空会话 | 收到通知后本地数据清除 |

---

## 注意事项

1. **消息历史API变更**: `GetMessageHistory` 现在返回空数组，历史消息必须从本地获取
2. **消息搜索**: 搜索功能现在在本地执行，不再依赖服务器
3. **收藏功能**: 需要传递完整消息内容，服务端不再存储消息
4. **类型安全**: 所有JSON解析都需要处理`LinkedMap`类型转换
