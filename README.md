# GameJam 第一幕 —— Godot 4.7

## 玩法流程
1. 开局：小人静止在背景上，不能移动。
2. **点击屏幕任意位置**：
   - 每次点击：切换到下一个皮肤 + 小人瞬移到点击位置
   - 逐个切换所有皮肤，**切到最后一个皮肤时自动激活移动**
3. 激活后：WASD / 方向键移动，显示行走动画
4. 激活后继续点击：循环切换皮肤 + 瞬移
5. 地上有背包，小人走到背包附近 → 背包旁出现"拾取" UI 图标
6. 点击 UI 图标或按 E 键 → 拾取背包，它消失
7. 拾取一个后，另一个不再弹出 UI（互斥）

## 操作
- 换造型 + 瞬移：鼠标左键点击屏幕任意位置
- 移动：W / A / S / D 或 ↑ / ← / ↓ / →
- 拾取：点击背包旁的 UI 图标，或按 E

---

## 自定义区域
### 障碍物（不让小人去的地方）
- 场景树里 **Obstacles** 节点下有 Wall1、Wall2 两个障碍物
- **直接拖动** Wall1/Wall2 调整位置
- **调整大小**：选中 CollisionShape2D 子节点，在 2D 视图拖边/角
- **新增障碍物**：复制 Wall1 → 改名 → 改位置/大小
- 障碍物是 StaticBody2D，小人会被它挡住（走不过去、瞬移也穿不过去）

### 调整人物大小
- 选中 **Player** 节点，Inspector 里改 **Sprite Scale**（默认 0.3）
- 碰撞范围也要同步改：Player 下 **CollisionShape2D** 的大小

---

## 你要做的：素材 + 属性

### 1. 背景图
- **Background** → 拖图到 Texture

### 2. 小人（Player 节点）
选中 **Player**，Inspector 导出变量：

| 属性 | 说明 | 内容 |
|---|---|---|
| **Skins** | 皮肤图数组 | 拖多张小人待机图（逐个切换） |
| **Walk Frames** | 行走帧数组 | 拖小人行走帧（2~4 帧循环） |
| **Sprite Scale** | 人物大小 | 调这个控制小人大小 |
| **Move Speed** | 移动速度 | 默认 220 |
| **Walk Fps** | 行走流畅度 | 默认 10 |

> 没有行走帧也能跑：Walk Frames 留空时移动只显示当前皮肤。

### 3. 背包
- 每个 Backpack 下的 **Sprite** → 拖背包图到 Texture
- 调整背包 Position / Collision 大小

### 4. 拾取 UI 图标
- 每个 Backpack 下的 **PickupUI/Sprite2D** → 拖 UI 图标到 Texture
- 图标大小：改 PickupUI 节点的 Scale
- 图标位置：改 PickupUI 节点的 Position

---

## 碰撞层说明
| 节点 | Layer | Mask | 效果 |
|---|---|---|---|
| Player | 1 | 1 | 被障碍物阻挡，检测背包 |
| Obstacles/Wall* | 1 | 0 | 阻挡玩家 |
| Backpack* (Area2D) | 2 | 1 | 不阻挡玩家，仅触发靠近检测 |

> 小人可以和背包自由重叠，不会被背包挡住。

## 文件结构
```
gamejam/
├── project.godot
├── README.md
└── act1/
    ├── Act1.tscn          # 主场景（F5 运行）
    ├── Act1.gd            # 主控：互斥拾取
    ├── Player.gd          # 换肤 + 瞬移 + 移动
    ├── Backpack.gd        # 背包 + UI 显隐
    ├── PickupUI.tscn      # 拾取 UI 子场景
    └── PickupUI.gd        # UI 显示/隐藏 + 点击检测
```

## 可随意改
- **增加背包**：复制 Backpack1 → 改名
- **增加障碍**：复制 Wall1 → 改名，拖位置
- **人物大小**：Player 的 Sprite Scale
- **移动速度**：Player 的 Move Speed
- **UI 位置**：每个 PickupUI 的 Position

## 运行
打开 `act1/Act1.tscn`，按 F5。
