# 连麦功能完整指南

## 目录
1. [架构设计](#架构设计)
2. [实现总结](#实现总结)
3. [快速参考](#快速参考)
4. [测试场景](#测试场景)
5. [检查清单](#检查清单)
6. [调试指南](#调试指南)

---

## 架构设计

### 双流架构

连麦功能采用双流架构，同时使用两种不同的流媒体技术：

#### 1. RTMP + SRS（普通直播推流）
- **用途**：主播的主画面推流
- **延迟**：3-10秒
- **特点**：支持大规模观众，稳定可靠
- **观众**：所有人都能看到

#### 2. WebRTC + LiveKit（连麦功能）
- **用途**：连麦用户的实时音视频通信
- **延迟**：<500ms
- **特点**：实时互动，支持少量用户（1-10人）
- **观众**：只有连麦用户能看到

### 视图层级

```
┌─────────────────────────────────────────────────────────┐
│  第1层（底层）：RTMP/SRS 视频播放器                      │
│  ├─ 主播的视频推流（全屏显示）                           │
│  └─ 所有用户都能看到                                    │
│                                                         │
│  第2层（中层）：其他UI组件                               │
│  ├─ 弹幕、礼物动画、聊天面板、控制按钮                   │
│                                                         │
│  第3层（上层）：连麦浮窗                                 │
│  ├─ 透明背景，只渲染浮窗部分                            │
│  ├─ 连麦用户的 WebRTC 视频                              │
│  └─ 不覆盖底层的主播视频                                │
└─────────────────────────────────────────────────────────┘
```

---

## 实现总结

### 已实现的核心功能

#### 1. 普通观众不加入LiveKit房间
- 在 `CoHostService._handleToken()` 中检查 `role`
- 只有 `role == 'host'` 或 `role == 'cohost'` 才连接
- 普通观众（`role == 'viewer'`）跳过连接

#### 2. 连麦放大视图功能
- 默认：主屏显示主播（RTMP/SRS），浮窗只显示连麦用户
- 主播点击放大连麦用户：主屏显示该用户，浮窗显示主播+其他用户
- 只有主播可以操作放大/退出
- 所有观众看到的画面跟随主播的操作

#### 3. LiveKit 事件模型优化
- 维护 `Map<String, VideoTrack> _subscribedVideoTracks` 映射表
- 监听 `TrackSubscribedEvent`、`TrackUnsubscribedEvent`、`ParticipantDisconnectedEvent`
- 使用 `ValueKey(track.sid)` 管理 Widget 生命周期

#### 4. 控制按钮优化
- 麦克风按钮：`Icons.mic` / `Icons.mic_off`
- 踢出按钮：`Icons.close`（红色背景）
- 垂直布局，同时显示两个按钮

---

## 快速参考

### 关键文件

#### 客户端
| 文件 | 说明 |
|------|------|
| `cohost_service.dart` | 连麦服务，管理 LiveKit 连接 |
| `cohost_view_tiktok.dart` | 连麦视图，抖音风格UI |
| `livestream_viewer_screen.dart` | 直播观看页面，处理视频播放和连麦 |

#### 服务端
| 文件 | 说明 |
|------|------|
| `service.go` | 连麦业务逻辑，处理连麦请求和接受 |
| `mixer.go` | 混流服务，管理 LiveKit Egress |
| `routes.go` | 连麦API路由 |

### 关键代码片段

#### 连麦视图不渲染主播视频
```dart
// CoHostViewTikTok.build()
final anchor = widget.isAnchor ? widget.localUserId : widget.anchorUserId;
final coHosts = widget.coHostInfos.where((info) => info.userId != anchor).toList();

// 只渲染连麦用户，不渲染主播
return Stack(
  children: [
    // 右侧浮窗显示 coHosts
    _buildCoHostList(coHosts)
  ]
);
```

#### 角色过滤
```dart
// CoHostService._handleToken()
Future<void> _handleToken(Map<String, dynamic> data) async {
  final role = data['role'] as String? ?? '';
  _myRole = role;
  
  // 普通观众不连接LiveKit
  if (role == 'viewer') {
    debugPrint('CoHost: viewer role, skip LiveKit connection');
    return;
  }
  
  // 只有 host 和 cohost 连接
  await connectToRoom(url, token);
}
```

---

## 测试场景

### 场景1：默认状态（无放大）

#### 主播端（张三）
- **LiveKit状态**：已连接（role=host）
- **显示效果**：
  - 主屏：张三的视频（RTMP/SRS推流）
  - 右侧浮窗：test（LiveKit视频）
  - 浮窗可点击：是

#### 连麦用户端（test）
- **LiveKit状态**：已连接（role=cohost）
- **显示效果**：
  - 主屏：张三的视频（通过混流或LiveKit）
  - 右侧浮窗：test自己（LiveKit视频）
  - 浮窗可点击：否

#### 普通观众端（李四）
- **LiveKit状态**：未连接（role=viewer）
- **显示效果**：
  - 主屏：混流视频（LiveKit Egress → SRS）
  - 右侧浮窗：无

### 场景2：主播放大连麦用户

#### 主播端（张三）
- **操作**：点击test浮窗
- **显示效果**：
  - 主屏：test的视频（LiveKit）
  - 右侧浮窗：张三 + 其他连麦用户
  - 浮窗可点击：是（可以退出放大）

#### 连麦用户端（test）
- **显示效果**：
  - 主屏：test的视频（通过混流）
  - 右侧浮窗：张三 + 其他连麦用户
  - 浮窗可点击：否

---

## 检查清单

### 已完成的优化 ✅
- [x] LiveKit 事件模型（媒体事件思维）
- [x] 角色与画面来源分离
- [x] 禁用自适应流
- [x] 主播立即发布轨道
- [x] UI 从映射表获取 VideoTrack
- [x] Track 生命周期管理
- [x] UI 优化（使用 Column 而不是 ListView）

### 需要验证的功能
- [ ] 主播开始连麦，连麦用户能看到主播视频
- [ ] 连麦用户加入，主播能看到连麦用户视频
- [ ] 主播关闭摄像头，所有人同时看到头像
- [ ] 主播重新开启摄像头，所有人同时看到视频
- [ ] 网络断开重连，视频正常恢复
- [ ] 弱网环境下，视频不黑屏
- [ ] 移动端切后台再回来，视频不黑屏
- [ ] 多人连麦，视频流畅
- [ ] 滚动连麦列表，视频不闪烁

---

## 调试指南

### 常见问题

#### 1. 视频黑屏
**可能原因**：
- VideoTrack 未正确订阅
- 浏览器摄像头权限问题
- Widget key 不正确导致纹理销毁

**解决方案**：
- 检查 `_subscribedVideoTracks` 映射表
- 确认 `ValueKey(track.sid)` 正确使用
- 查看浏览器控制台权限提示

#### 2. 观众看到自己的浮窗
**原因**：普通观众错误地连接了LiveKit房间

**解决方案**：
- 检查 `CoHostService._handleToken()` 中的角色过滤
- 确认服务端正确返回 `role=viewer`

#### 3. 主播视频被遮挡
**原因**：连麦视图使用 `Positioned.fill` 覆盖了整个屏幕

**解决方案**：
- 确认连麦视图只渲染浮窗部分
- 不要在连麦视图中渲染主播的 LiveKit 视频

### 调试日志

启用详细日志：
```dart
debugPrint('[CoHost] participant connected: ${event.participant.identity}');
debugPrint('[CoHost] track subscribed: ${event.track.sid}');
debugPrint('[CoHost] video track count: ${_subscribedVideoTracks.length}');
```

---

## 相关文档

- [直播播放修复](./LIVESTREAM_PLAYBACK_FIX.md)
- [直播404诊断](./LIVESTREAM_404_DIAGNOSIS.md)
- [视频播放器调试](./VIDEO_PLAYER_DEBUG_GUIDE.md)
- [连麦观众播放调试](./COHOST_VIEWER_PLAYBACK_DEBUG.md)
