# 编译错误修复说明

## 问题

编译 Web 版本时出现错误：

```
Error: The getter 'readyState' isn't defined for the type 'MediaStreamTrack'.
```

## 原因

`MediaStreamTrack` 接口（来自 `webrtc_interface` 包）没有 `readyState` 属性。这个属性只在浏览器的原生 `MediaStreamTrack` API 中存在，但在 Flutter WebRTC 包的抽象层中不可用。

## 修复

移除了所有对 `readyState` 的引用：

### 修改的文件

1. **client/lib/modules/livestream/services/cohost_service.dart**
   - 移除了 `debugPrint` 中的 `readyState` 输出

2. **client/lib/modules/livestream/screens/widgets/cohost_view_tiktok.dart**
   - 移除了 `hasVideo` getter 中的 `readyState` 检查
   - 只保留 `enabled` 状态检查

## 现在可以编译

```bash
cd client
flutter clean
flutter pub get
flutter build web --release
```

## 功能影响

移除 `readyState` 检查不会影响功能，因为：

1. `enabled` 状态已经足够判断轨道是否可用
2. `subscribed` 状态确保远端轨道已订阅
3. `muted` 状态确保轨道未被静音

这些检查已经足够确保视频轨道正常工作。

## 测试

编译成功后，测试连麦功能：

1. 主播端开启连麦
2. 连麦用户加入
3. 检查视频是否正常显示
4. 查看浏览器控制台日志

如果视频仍不显示，参考 `cohost_video_troubleshooting.md` 进行排查。
