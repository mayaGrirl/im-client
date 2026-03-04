# 图片裁剪功能修复说明

## 问题描述
朋友圈封面图片裁剪功能在 Web 和 Android 平台无法正常工作。

## 已完成的修复

### 1. Web 平台配置
- ✅ 在 `client/web/index.html` 中添加了 cropperjs CDN 引用
- ✅ 使用 unpkg CDN 源以提高加载稳定性

### 2. Android 平台配置
- ✅ 在 `AndroidManifest.xml` 中添加了 UCropActivity 配置
- ✅ 添加了 FileProvider 配置
- ✅ 创建了 `res/xml/file_paths.xml` 文件

### 3. 代码优化
- ✅ 优化了 `ImageCropHelper` 的 WebUiSettings 配置
- ✅ 确保裁剪功能在所有平台正常调用

## 当前状态

### Web 平台
cropperjs 库已正确引入，但可能存在以下问题：

1. **CDN 加载问题**：如果网络环境无法访问 unpkg.com，需要：
   - 使用国内 CDN 镜像
   - 或将 cropperjs 文件下载到本地

2. **初始化时序问题**：cropperjs 需要在 Flutter 应用启动前完全加载

### Android 平台
配置已完成，需要重新编译 APK 测试。

## 测试步骤

### Web 平台测试
1. 清除浏览器缓存
2. 重新部署 Web 应用
3. 打开浏览器开发者工具，检查：
   - Network 标签：确认 cropper.css 和 cropper.js 已成功加载
   - Console 标签：检查是否有 JavaScript 错误
4. 长按朋友圈封面，选择图片后测试裁剪功能

### Android 平台测试
1. 重新编译 APK：`flutter build apk --dart-define=ENV=test`
2. 安装到设备
3. 测试朋友圈封面更换功能

## 备用方案

如果 Web 平台仍然无法使用裁剪功能，可以考虑：

### 方案 1：本地化 cropperjs
将 cropperjs 文件下载到 `client/web/assets/` 目录：

```html
<link rel="stylesheet" href="assets/cropperjs/cropper.css" />
<script src="assets/cropperjs/cropper.js"></script>
```

### 方案 2：使用国内 CDN
```html
<link rel="stylesheet" href="https://cdn.bootcdn.net/ajax/libs/cropperjs/1.6.2/cropper.css" />
<script src="https://cdn.bootcdn.net/ajax/libs/cropperjs/1.6.2/cropper.js"></script>
```

### 方案 3：替换裁剪库
考虑使用纯 Flutter 实现的裁剪库，如 `crop_image` 或 `croppy`。

## 相关文件

- `client/web/index.html` - Web 平台 cropperjs 引用
- `client/android/app/src/main/AndroidManifest.xml` - Android 配置
- `client/android/app/src/main/res/xml/file_paths.xml` - FileProvider 路径配置
- `client/lib/utils/image_crop_helper.dart` - 裁剪工具类
- `client/lib/screens/moment/moment_list_screen.dart` - 朋友圈封面更换功能

## 调试建议

### Web 平台调试
在浏览器控制台执行以下命令检查 cropperjs 是否加载：
```javascript
console.log(typeof Cropper); // 应该输出 "function"
```

如果输出 "undefined"，说明 cropperjs 未加载成功，需要检查：
1. CDN 是否可访问
2. 是否有网络代理或防火墙阻止
3. 浏览器是否阻止了第三方脚本

### Android 平台调试
使用 `adb logcat` 查看日志：
```bash
adb logcat | grep -i "ucrop\|crop\|image"
```

## 更新日志

- 2026-03-04: 初始修复，添加 Web 和 Android 平台配置
- 2026-03-04: 更换 CDN 源为 unpkg.com
- 2026-03-04: 添加 Android FileProvider 配置
