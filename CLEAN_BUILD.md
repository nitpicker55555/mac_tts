# 清理 Xcode 构建文件

## 方法一：使用 Xcode 菜单（推荐）

1. **清理构建文件夹**
   - 打开 Xcode
   - 菜单栏：Product → Clean Build Folder
   - 或使用快捷键：⇧⌘K (Shift + Command + K)

2. **清理普通构建**
   - 菜单栏：Product → Clean
   - 或使用快捷键：⌘K (Command + K)

## 方法二：手动删除 DerivedData

DerivedData 包含所有构建产物、索引和中间文件。

1. **通过 Xcode 打开文件夹**
   - Xcode → Preferences (或 Settings)
   - Locations 标签
   - 点击 DerivedData 路径旁的箭头图标
   - 删除对应项目的文件夹

2. **使用终端命令**
   ```bash
   # 删除所有 DerivedData
   rm -rf ~/Library/Developer/Xcode/DerivedData/*
   
   # 或只删除特定项目（项目名称包含 toast_talk）
   rm -rf ~/Library/Developer/Xcode/DerivedData/*toast_talk*
   ```

## 方法三：清理特定内容

```bash
# 清理模拟器缓存
rm -rf ~/Library/Developer/CoreSimulator/Caches/

# 清理 Archives（发布版本）
rm -rf ~/Library/Developer/Xcode/Archives/

# 清理设备支持文件
rm -rf ~/Library/Developer/Xcode/iOS\ DeviceSupport/
```

## 方法四：使用脚本自动清理

创建清理脚本 `clean_xcode.sh`：

```bash
#!/bin/bash

echo "🧹 开始清理 Xcode 缓存..."

# 清理 DerivedData
echo "清理 DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# 清理模拟器缓存
echo "清理模拟器缓存..."
rm -rf ~/Library/Developer/CoreSimulator/Caches/dyld/

# 显示清理前后的空间
echo "✅ 清理完成！"
```

使用方法：
```bash
chmod +x clean_xcode.sh
./clean_xcode.sh
```

## 注意事项

1. **Clean vs Clean Build Folder**
   - Clean：只清理当前配置的构建
   - Clean Build Folder：清理所有配置的构建（更彻底）

2. **清理后首次构建会较慢**
   - 需要重新生成所有中间文件
   - 索引需要重建

3. **保留重要文件**
   - Archives 包含已发布的版本，谨慎删除
   - 确认不需要的文件再删除

## 快速清理命令

最常用的清理命令：
```bash
# 快速清理当前项目
rm -rf ~/Library/Developer/Xcode/DerivedData/*toast_talk*
```

清理后重新打开 Xcode 项目即可。