# 设置交通路线搜索工具

## 新增文件

为了支持交通路线搜索功能，项目中添加了以下新文件：

1. **TransitRouteService.swift** - 交通路线搜索服务
   - 与德国公共交通API通信
   - 根据经纬度搜索路线
   - 生成GeoJSON格式的地理数据

2. **LLMToolSystem.swift** - LLM工具系统框架
   - 定义工具协议
   - 管理工具调用
   - 实现交通路线搜索工具

3. **StreamLLMServiceWithTools.swift** - 支持工具的LLM服务
   - 扩展标准LLM服务
   - 支持OpenAI工具调用API
   - 处理工具执行和结果返回

4. **StreamConversationManagerWithTools.swift** - 支持工具的对话管理器
   - 集成工具调用功能
   - 管理地图数据展示
   - 协调语音输入输出

5. **MapRouteView.swift** - 地图路线视图
   - 使用MapKit显示路线
   - 支持站点标记和路线绘制
   - 显示详细路线信息

6. **ContentViewWithTools.swift** - 支持工具的主界面（可选）
   - 完整的桌面版界面
   - 包含地图展示功能

7. **StreamChatToastViewWithTools.swift** - 支持工具的Toast界面
   - 保持原有的紧凑设计
   - 添加地图按钮和工具提示

8. **EnhancedMapRouteView.swift** - 增强版地图路线视图
   - 支持显示最多3个路线方案
   - 不同交通工具使用不同颜色
   - 显示详细的时刻表信息

## Xcode项目配置

1. 在Xcode中右键点击 `toast_talk` 文件夹
2. 选择 "Add Files to toast_talk..."
3. 选择以下文件并添加：
   - TransitRouteService.swift
   - LLMToolSystem.swift
   - StreamLLMServiceWithTools.swift
   - StreamConversationManagerWithTools.swift
   - MapRouteView.swift
   - EnhancedMapRouteView.swift
   - StreamChatToastViewWithTools.swift
   - ContentViewWithTools.swift (可选)

## 使用说明

主应用文件已更新为使用新的支持工具的视图：

```swift
StreamChatToastViewWithTools()
```

如果要切换回原版本，只需将 `toast_talkApp.swift` 中的视图改回：

```swift
StreamChatToastView()
```

## API限制

- 当前使用的是德国公共交通API (v6.db.transport.rest)
- 主要支持德国地区的公共交通查询
- API为免费公开服务，可能有速率限制

## 测试示例

可以使用以下坐标进行测试（慕尼黑地区）：
- 起点：48.1457899, 11.5653114 (慕尼黑中央车站附近)
- 终点：48.107662, 11.5338275 (慕尼黑南部)