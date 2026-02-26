#!/bin/bash
# Web 平台重新编译脚本

echo "=== Web 平台重新编译开始 ==="
echo ""

echo "1. 清理构建缓存..."
flutter clean

echo ""
echo "2. 删除构建目录..."
rm -rf build/
rm -rf .dart_tool/

echo ""
echo "3. 重新获取依赖..."
flutter pub get

echo ""
echo "4. 编译 Web 版本..."
flutter build web --release

echo ""
echo "=== 编译完成 ==="
echo ""
echo "下一步："
echo "1. 清除浏览器缓存（Ctrl+Shift+Delete）"
echo "2. 或使用无痕模式测试（Ctrl+Shift+N）"
echo "3. 打开开发者工具（F12）查看控制台日志"
echo ""
