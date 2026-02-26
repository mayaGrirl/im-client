# 直播功能调试指南

## 目录
1. [直播拉流 404 问题](#直播拉流-404-问题)
2. [直播播放器显示问题](#直播播放器显示问题)
3. [Web 平台特殊问题](#web-平台特殊问题)
4. [调试工具和命令](#调试工具和命令)

---

## 直播拉流 404 问题

### 问题描述
拉流地址返回正确，但访问时报错 404。

### 常见原因

#### 1. 主播还没有开始推流（80%）
HLS 流是动态生成的，只有在主播开始推流后，Nginx/SRS 才会生成 `.m3u8` 文件。

**解决方案**：
1. 确保主播已经点击"开始直播"
2. 确保主播端成功推流到服务器
3. 等待 3-5 秒让 HLS 文件生成

**验证方法**：
```bash
curl -I https://ws.kaixin28.com/live/stream_id.m3u8
# 返回 200: 推流成功
# 返回 404: 主播未推流
```

#### 2. HLS 文件还没有生成（15%）
推流刚开始时，HLS 文件可能还在生成中。

**解决方案**：等待 3-5 秒后再次尝试

**验证方法**：
```bash
# 检查 HLS 文件是否生成
ls -la /tmp/hls/live/ | grep stream_id
# 应该看到 .m3u8 和 .ts 文件
```

#### 3. Nginx/SRS 配置错误（5%）

**检查 Nginx 配置**：
```nginx
rtmp {
    server {
        listen 1935;
        application live {
            live on;
            hls on;
            hls_path /tmp/hls;
            hls_fragment 3s;
            hls_playlist_length 60s;
        }
    }
}

http {
    server {
        listen 80;
        location /live {
            types {
                application/vnd.apple.mpegurl m3u8;
                video/mp2t ts;
            }
            root /tmp/hls;  # 必须与 hls_path 一致
            add_header Cache-Control no-cache;
            add_header Access-Control-Allow-Origin *;
        }
    }
}
```

**检查 SRS 配置**：
```conf
vhost __defaultVhost__ {
    hls {
        enabled         on;
        hls_path        ./objs/nginx/html/live;
        hls_fragment    3;
        hls_window      60;
    }
}
```

### 诊断步骤

#### 步骤 1：检查主播是否推流
```
客户端日志：
[直播] 主播开始推流
[WebRTC推流] ✅ 推流成功

服务端日志：
[Livestream] 收到推流: stream_id=xxx
[Livestream] 直播间状态更新: pending -> live

Nginx/SRS 日志：
[rtmp] publish: live/stream_id
[hls] create playlist: /tmp/hls/live/stream_id.m3u8
```

#### 步骤 2：检查 HLS 文件
```bash
ls -la /tmp/hls/live/ | grep stream_id
# 应该看到：
# stream_id.m3u8  (播放列表)
# stream_id-0.ts  (视频片段)
# stream_id-1.ts
```

#### 步骤 3：测试拉流地址
```bash
curl -I https://ws.kaixin28.com/live/stream_id.m3u8
# 预期返回：HTTP/1.1 200 OK
```

#### 步骤 4：检查直播间状态
```sql
SELECT id, status, stream_id, push_url, pull_url, started_at
FROM livestreams 
WHERE stream_id = 'stream_id';

-- status 应该是 1 (live)
-- started_at 不为空
```

---

## 直播播放器显示问题

### 症状
主播开始直播推流，拉流链接正常，但观众端无法正常显示（黑屏或显示占位图）。

### 调试步骤

#### 步骤 1：检查拉流地址
查看浏览器控制台日志：
```
[直播] pullUrl: https://pull.example.com/live/stream123.m3u8
[直播] 观众端开始拉流
```

**验证**：
- [ ] pullUrl 不为空
- [ ] pullUrl 不包含 "example.com"（占位符）
- [ ] pullUrl 是有效的 HLS 地址（.m3u8）

#### 步骤 2：检查视频播放器初始化
```
[直播] ========== _initVideoPlayer 开始 ==========
[直播] ✅ 拉流地址验证通过，开始初始化播放器
[直播] ✅ 视频播放器初始化成功
[直播] ✅ Chewie控制器创建成功
```

**验证**：
- [ ] 拉流地址验证通过
- [ ] 视频播放器初始化成功
- [ ] Chewie控制器创建成功

#### 步骤 3：检查渲染条件
添加调试日志：
```dart
debugPrint('[直播-渲染] widget.isAnchor: ${widget.isAnchor}');
debugPrint('[直播-渲染] _chewieController: ${_chewieController != null}');
debugPrint('[直播-渲染] _isCoHosting: $_isCoHosting');
```

对于观众端（RTMP模式），应该满足：
- [ ] `widget.isAnchor = false`
- [ ] `_chewieController != null`
- [ ] `_isCoHosting = false`（如果未连麦）

#### 步骤 4：检查视频播放器状态
```dart
_videoController?.addListener(() {
  debugPrint('[直播-播放器] isInitialized: ${_videoController!.value.isInitialized}');
  debugPrint('[直播-播放器] isPlaying: ${_videoController!.value.isPlaying}');
  debugPrint('[直播-播放器] hasError: ${_videoController!.value.hasError}');
});
```

**验证**：
- [ ] `isInitialized = true`
- [ ] `isPlaying = true`
- [ ] `hasError = false`

### 常见问题和解决方案

#### 问题 1：拉流地址是占位符
**症状**：
```
[直播] pullUrl: https://example.com/live/stream123.m3u8
[直播] ❌ 拉流地址为占位符，跳过播放器初始化
```

**解决方案**：
检查服务端配置：
```go
// server/internal/config/config.go
PullDomain: "pull.yourdomain.com",  // 不要使用 example.com
PullScheme: "https",
```

#### 问题 2：视频播放器初始化失败
**症状**：
```
[直播] ❌ 视频播放器初始化失败: PlatformException(...)
```

**解决方案**：
1. 在浏览器中直接打开拉流地址，检查是否可访问
2. 检查网络连接是否正常
3. 检查 SRS 服务器是否正常运行

#### 问题 3：视频播放器被连麦视图覆盖
**症状**：
```
[直播-渲染] _isCoHosting: true  // ❌ 普通观众不应该是 true
```

**解决方案**：
确保普通观众的 `service.isCoHosting = false` 和 `_coHostInfos = []`

#### 问题 4：视频显示黑屏
**解决方案**：
1. 检查视频流是否有数据
2. 检查视频播放器的 aspectRatio
3. 等待 HLS 延迟（3-10 秒）
4. 检查主播推流质量

---

## Web 平台特殊问题

### 问题：Web 平台拉流失败（404）

#### 根本原因
在 `_initWebVideoPlayer()` 方法中，设置了 `_webVideoViewId` 但**没有调用 `setState()`**，导致 UI 不会重新构建，HTML video 元素永远不会被渲染。

#### 修复方案
```dart
void _initWebVideoPlayer(String pullUrl) {
  try {
    final viewId = 'video-player-${DateTime.now().millisecondsSinceEpoch}';
    registerWebVideoView(viewId, pullUrl);
    
    // ✅ 更新状态以触发UI重建
    if (mounted) {
      setState(() {
        _webVideoViewId = viewId;
      });
    }
  } catch (e) {
    debugPrint('[直播] ❌ Web视频初始化失败: $e');
  }
}
```

### Web 平台其他问题

#### CORS 配置
SRS 服务器需要配置 CORS：
```nginx
add_header Access-Control-Allow-Origin *;
add_header Access-Control-Allow-Methods 'GET, POST, OPTIONS';
```

#### 浏览器自动播放策略
某些浏览器阻止自动播放，需要用户交互：
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('如果没有声音，请点击屏幕开始播放')),
);
```

---

## 调试工具和命令

### Chrome DevTools
1. **Console**：查看日志输出
2. **Network**：查看网络请求
   - 检查 m3u8 文件是否正确加载
   - 检查 ts 分片是否正确加载
3. **Elements**：查看 DOM 结构
   - 检查 video 元素是否存在

### Flutter DevTools
1. **Logging**：查看 Flutter 日志
2. **Widget Inspector**：查看 Widget 树

### 命令行工具

#### 测试推流
```bash
# 使用 FFmpeg 测试推流
ffmpeg -re -i test.mp4 \
  -c:v libx264 -c:a aac \
  -f flv rtmp://ws.kaixin28.com/live/test_stream
```

#### 测试拉流
```bash
# 使用 curl 测试
curl -I https://ws.kaixin28.com/live/stream_id.m3u8

# 使用 FFplay 测试
ffplay https://ws.kaixin28.com/live/stream_id.m3u8

# 使用 VLC 测试
vlc https://ws.kaixin28.com/live/stream_id.m3u8
```

#### 查看日志
```bash
# Nginx 日志
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log

# SRS 日志
tail -f ./objs/srs.log
```

#### 检查防火墙
```bash
# 检查端口是否开放
sudo firewall-cmd --list-ports

# 开放端口
sudo firewall-cmd --permanent --add-port=1935/tcp  # RTMP
sudo firewall-cmd --permanent --add-port=80/tcp    # HTTP
sudo firewall-cmd --permanent --add-port=443/tcp   # HTTPS
sudo firewall-cmd --reload
```

### 测试清单
- [ ] 拉流地址正确且可访问
- [ ] 视频播放器初始化成功
- [ ] 视频播放器渲染条件满足
- [ ] 视频播放器不被其他UI覆盖
- [ ] 视频播放器状态正常（isPlaying = true）
- [ ] 普通观众不显示连麦浮窗
- [ ] 视频画面正常显示（不是黑屏）
- [ ] 视频播放流畅（无卡顿）

---

## 快速诊断流程

```
1. 检查拉流地址
   ├─ 是否为空？ → 检查服务端配置
   ├─ 是否为占位符？ → 检查服务端配置
   └─ 是否可访问？ → curl 测试

2. 检查主播推流
   ├─ 主播是否点击"开始直播"？
   ├─ 推流是否成功？ → 查看客户端日志
   └─ HLS 文件是否生成？ → ls /tmp/hls/live/

3. 检查播放器初始化
   ├─ 是否初始化成功？ → 查看日志
   ├─ 是否有错误？ → 查看错误信息
   └─ 是否调用 setState()？ → Web 平台特殊检查

4. 检查播放器渲染
   ├─ 渲染条件是否满足？ → 查看状态变量
   ├─ 是否被其他UI覆盖？ → 检查连麦视图
   └─ 是否正常播放？ → 查看播放器状态

5. 检查网络和服务器
   ├─ 网络是否正常？
   ├─ SRS 是否运行？
   └─ 防火墙是否开放？
```

---

## 相关文档
- [连麦功能指南](./COHOST_GUIDE.md)
- [连麦观众播放调试](./COHOST_VIEWER_PLAYBACK_DEBUG.md)
- [构建修复](./BUILD_FIX.md)
