# NookDesk 🏝️

**动森风格博客管理工作台** — 配合 [animal-island-blog](https://github.com/guokaigdg/animal-island-blog) 博客系统使用

一款 macOS 桌面应用，让你用动森风格的界面管理你的博客。支持文章创建/编辑、页面内容修改、一键发布到 GitHub Pages。

## 📋 三个仓库的关系

| 仓库 | 作用 | 说明 |
|------|------|------|
| [animal-island-blog](https://github.com/guokaigdg/animal-island-blog) | 博客模板 | 原始项目，包含博客的完整代码（React 19 + Vite + 动森风格 UI） |
| `你的用户名.github.io` 或 `你的用户名/animal-island-blog` | 你的博客 | Fork 模板后，这是你的博客数据仓库，包含你的文章和配置 |
| [NookDesk](https://github.com/sexyfeifan/NookDesk) | 博客管理软件 | macOS 桌面应用，用于管理你的博客（创建文章、编辑页面、发布） |

**关系图：**
```
guokaigdg/animal-island-blog (原始模板)
    ↓ fork
你的用户名/animal-island-blog (你的博客数据)
    ↑ 管理
NookDesk (桌面管理软件)
```

## 📦 下载安装

1. 前往 [Releases](https://github.com/sexyfeifan/NookDesk/releases) 页面
2. 下载最新版本的 `NookDesk-vX.X.X-universal.dmg`
3. 双击 DMG，将 NookDesk.app 拖入 Applications 文件夹
4. 首次打开可能需要在 系统设置 → 隐私与安全 中允许运行

> 支持 Intel (x86_64) 和 Apple Silicon (arm64) 双架构，最低系统要求 macOS 13

---

## 🚀 完整使用流程

### 第一步：Fork 博客模板

1. 打开 [animal-island-blog](https://github.com/guokaigdg/animal-island-blog)
2. 点击右上角 **Fork** 按钮，fork 到你的 GitHub 账号
3. Fork 后可以选择重命名（如 `我的用户名.github.io`）或保持原名
4. 进入你 fork 后的仓库，进入 **Settings → Pages**
5. 将 Source 改为 **GitHub Actions**（不是 Deploy from a branch）

> **为什么需要 fork？** NookDesk 管理的是你自己的博客仓库。fork 后你拥有完整的代码控制权，NookDesk 通过 git 操作你的仓库来发布文章。

### 第二步：安装并启动 NookDesk

1. 下载 DMG 安装包并安装
2. 首次启动会进入 **引导流程**（5 步）

### 第三步：引导配置

引导流程会帮你完成所有必要的配置：

**步骤 1 — 欢迎**
- 了解 NookDesk 的功能介绍
- 点击「开始配置」进入下一步

**步骤 2 — 选择项目**
有两种方式：

方式 A：**从 GitHub 克隆**（推荐首次使用）
- 输入你的博客仓库地址，如 `https://github.com/你的用户名/animal-island-blog.git`
- 选择本地保存目录（如 `~/Documents/Blog`）
- NookDesk 会自动克隆仓库到本地
- 克隆完成后自动检测项目类型

方式 B：**选择本地目录**（已有本地项目）
- 直接选择你之前克隆/下载的博客项目目录
- NookDesk 会自动检测项目类型

**步骤 3 — 配置 GitHub**
- 远程仓库地址（通常自动从 git remote 读取）
- 发布分支（默认 `main`）

**步骤 4 — 配置 Token**（可选但推荐）
- 填写 GitHub Personal Access Token
- Token 用于自动推送代码到 GitHub
- 可以跳过，但发布时需要手动输入

**步骤 5 — 完成**
- 显示配置摘要
- 点击「进入 NookDesk」开始使用

> **如果引导失败？** 重新启动 app 会自动重新进入引导流程。之前填写的信息会保留。

### 第四步：写作

切换到 **「写作」** 标签页：

**界面布局：**
```
┌─────────────────────────────────────────────────────┐
│ 侧边栏          │ 文章编辑区                          │
│                  │                                    │
│ [+ 新文章]       │ 📝 基本信息                        │
│                  │   标题 / 摘要 / 日期 / 标签 / 颜色  │
│ ▸ 文章1          │                                    │
│ ▸ 文章2          │ 📖 正文内容                        │
│ ▸ 文章3          │   章节1: 标题 + 段落                │
│                  │   章节2: 标题 + 段落                │
│ [读取本地]       │   [+ 添加章节]                     │
│ [拉取]           │                                    │
│ [恢复]           │ 🌿 文章要点                        │
│                  │   • 要点1  • 要点2                  │
│                  │   [+ 添加要点]                     │
│                  │                                    │
│                  │ [保存]  [保存并发布]  [删除]        │
└─────────────────────────────────────────────────────┘
```

**创建文章：**
1. 点击侧边栏「+ 新文章」
2. 填写标题（显示在博客列表中）
3. 填写摘要（文章简介）
4. 选择标签（Blog / 技术 / 生活 / 设计 / 工具 / AI / 思考）
5. 选择卡片颜色（13 种动森风格颜色）
6. 设置封面 emoji（如 🏝️ ⌨️ 🎨）
7. 设置阅读时间（如 "6 分钟"）

**编写正文：**
- 正文由 **章节（sections）** 组成，这是博客实际渲染的内容
- 每个章节有 **标题** 和 **段落**
- 可以添加多个章节，每个章节可以有多个段落
- 段落支持中文输入（使用 CJKTextEditor，正确处理中文输入法）
- 点击章节标题旁的箭头可以折叠/展开

**添加要点：**
- 要点显示在文章末尾的黄色卡片中
- 用于总结文章的核心观点
- 可以添加/删除多个要点

**保存文章：**
- 「保存」— 保存当前编辑到本地 posts.ts 文件
- 「保存并发布」— 保存 + 推送到 GitHub（触发 Actions 部署）
- 「删除」— 删除当前文章（需要确认）

**侧边栏按钮：**
- 「读取本地」— 从本地 posts.ts 重新加载文章列表
- 「拉取」— 从 GitHub 拉取最新代码（`git pull`），然后重新加载
- 「恢复」— 从你的 fork 仓库下载默认文章模板（本地文章优先保留）

### 第五步：编辑页面

切换到 **「页面」** 标签页：

可以编辑博客首页的各个部分：
- **品牌信息** — 站点标题、副标题
- **英雄区** — 打字机文字、描述文字
- **技能标签** — 显示在首页的技能列表
- **统计数据** — 文章数、坐标等
- **关于区** — 个人介绍
- **FAQ** — 常见问题

每个部分有独立的保存按钮，修改后需要发布才能生效。

### 第六步：发布

切换到 **「发布」** 标签页：

**发布流程（6 步引导）：**

| 步骤 | 操作 | 说明 |
|------|------|------|
| 1. 检查项目状态 | 自动 | 检查 package.json、vite.config.ts、posts.ts、deploy.yml |
| 2. 生成 Workflow | 自动/手动 | 确保 .github/workflows/deploy.yml 存在 |
| 3. 检查 Pages 来源 | 自动 | 确保 GitHub Pages 使用 Actions 部署 |
| 4. 提交并推送 | 点击发布 | git add → git commit → git push |
| 5. 等待部署 | 自动 | 监控 GitHub Actions 状态 |
| 6. 部署完成 | 自动 | 显示部署结果和访问地址 |

**一键发布按钮：**
- 点击后自动执行所有步骤
- 显示进度弹窗，每步状态（✅/❌/⏳）
- 失败时显示错误信息和修复建议

**发布前检测项：**
- ✅ package.json 存在
- ✅ vite.config.ts 存在
- ✅ posts.ts 文章数据存在
- ✅ .github/workflows/deploy.yml 存在
- ✅ Git 远程地址已配置
- ✅ GitHub Token 已配置

### 第七步：查看博客

发布成功后：
1. 等待 GitHub Actions 完成（通常 1-3 分钟）
2. 访问 `https://你的用户名.github.io` 查看博客
3. 文章详情页会显示：标题、摘要、章节内容、要点

---

## 🎨 功能特性

### 写作管理
- 📝 表单化编辑器（标题/摘要/章节/要点）
- 🏷️ 7 种文章标签 + 13 种卡片颜色
- 📅 文章日期管理
- 🎨 封面 emoji 自定义
- 🔤 中文输入法完整支持（CJKTextEditor）
- 📖 章节折叠/展开
- 💾 保存 / 保存并发布 / 删除

### 页面编辑
- 🏠 首页内容编辑（品牌、英雄区、技能、统计、关于、FAQ）
- 🎨 13 种动森风格卡片颜色
- 📝 每个字段有中文说明和影响位置提示

### 发布管理
- 🚀 一键发布到 GitHub Pages
- ✅ 发布前 6 项检测
- 🔧 检测失败自动给出修复建议
- 📊 GitHub Actions 状态监控
- 📋 发布进度弹窗（每步状态 + 错误日志）

### 动森风格 UI
- 🎨 13 种 NookPhone 配色方案
- 🃏 圆角卡片设计
- 🌊 波浪分隔线
- 🍃 树叶加载动画
- ⌨️ 打字机文字效果
- 🎮 游戏风格按钮

### 项目管理
- 🔄 自动检测项目类型（Hugo / Vite）
- 📥 从 GitHub 克隆项目
- 🔍 项目结构检查
- 📋 操作日志记录

### 版本管理
- 🔄 自动检测 NookDesk 新版本
- 📦 版本下载和更新提示

---

## 📖 博客文章结构

博客文章存储在 `src/pages/Home/posts.ts` 中，每篇文章的结构：

```typescript
{
    id: "demo-001",                    // 唯一标识
    title: "在无人岛上学会慢生活",       // 标题
    excerpt: "从钓竿到夕阳...",          // 摘要
    body: "搬到岛上后做的第一件事...",   // 开头引言（博客不渲染）
    date: "2026-04-18",                // 日期
    tag: "生活",                        // 标签
    color: "app-blue",                 // 卡片颜色
    readTime: "6 分钟",                // 阅读时间
    cover: "🏝️",                      // 封面 emoji
    sections: [                        // 正文章节（博客实际渲染的内容）
        {
            heading: "重新找回...",      // 章节标题
            paragraphs: [              // 章节段落
                "在城市生活的时候...",
                "下午只有海浪声...",
            ],
        },
    ],
    takeaways: [                       // 文章要点
        "前三天要和罪恶感战斗",
        "把时间单位换成自然现象",
    ],
}
```

> **重要：** `sections` 才是博客实际渲染的正文内容。`body` 字段在博客中不显示。NookDesk 的编辑器直接编辑 sections。

---

## ⚙️ GitHub Token 配置

推荐创建 Fine-grained Token：

1. 前往 GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens
2. 点击「Generate new token」
3. Token name：`NookDesk`
4. Repository access：选择「Only select repositories」，选择你的博客仓库
5. Permissions：
   - **Contents**: Read and write（提交代码）
   - **Pages**: Read and write（管理 Pages 部署）
   - **Actions**: Read（监控 Actions 状态）
6. 点击「Generate token」
7. 复制 token，在 NookDesk 引导流程或设置中粘贴

> **注意：** Token 只保存在本地 Keychain 中，不会上传到任何地方。

---

## 🛠️ 技术栈

- **应用框架**: SwiftUI (macOS 13+)
- **构建工具**: Swift Package Manager
- **博客系统**: React 19 + Vite + animal-island-ui
- **部署**: GitHub Pages + GitHub Actions
- **架构**: arm64 + x86_64 双架构
- **字体**: Nunito + ZCOOL KuaiLe（中文）

## 📁 项目结构

```
NookDesk/
├── v0.8.0/                    ← 当前版本源码
│   ├── Sources/NookDesk/
│   │   ├── Backends/          ← SSG 后端协议（Hugo / Vite）
│   │   ├── DesignSystem/      ← 动森风格 UI 组件
│   │   ├── Models/            ← 数据模型
│   │   ├── Services/          ← 业务逻辑（Git、发布、文章解析）
│   │   ├── ViewModels/        ← 视图模型
│   │   └── Views/             ← 界面视图
│   ├── Assets.xcassets/       ← 应用资源和图标
│   ├── Package.swift
│   └── dist/                  ← 构建产物（.dmg）
├── archive/                   ← 历史版本
│   ├── v0.5.0/
│   ├── v0.6.0/
│   └── ...
└── README.md
```

## 🔧 从源码构建

```bash
cd v0.8.0

# Debug 构建
swift build

# Release 构建（双架构）
swift build -c release --arch arm64
swift build -c release --arch x86_64

# 合并双架构
mkdir -p .build/universal
lipo -create \
  .build/arm64-apple-macosx/release/NookDesk \
  .build/x86_64-apple-macosx/release/NookDesk \
  -output .build/universal/NookDesk

# 打包 .app
APP="dist/NookDesk.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/universal/NookDesk "$APP/Contents/MacOS/"
cp Sources/NookDesk/Resources/AppIcon.png "$APP/Contents/Resources/"

# 打包 DMG
hdiutil create -volname "NookDesk" -srcfolder "$APP" -ov -format UDZO dist/NookDesk.dmg
```

## 📝 版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| v1.3.2 | 2026-06-11 | 逐行审查修复：转义处理、日期格式、渲染验证、发布安全 |
| v1.3.1 | 2026-06-11 | 深度审计修复：try? → try、IME 保护、非空目录安全 |
| v1.3.0 | 2026-06-11 | 全面审计修复：保存失败阻止发布、模板字符串支持、异步网络 |
| v1.2.3 | 2026-06-06 | 修复删除功能：savePosts 不再合并回已删除文章 |
| v1.2.2 | 2026-06-06 | 恢复从 fork 仓库、fork 更新为中文内容 |
| v1.2.1 | 2026-06-06 | 卡片宽度统一、CJK 输入修复、日文文章恢复 |
| v1.2.0 | 2026-06-06 | 重构写作页面：表单化编辑 sections |
| v1.1.3 | 2026-06-06 | 审计修复：extractField 转义、findMatchingBracket、Token 分类 |
| v1.1.2 | 2026-06-06 | 修复 sections paragraphs 解析 |
| v1.1.1 | 2026-06-06 | 移除硬编码仓库信息、README 仓库关系说明 |
| v1.0.3 | 2026-06-06 | 纯 Swift 解析器（不依赖 esbuild/Node.js） |
| v1.0.2 | 2026-06-06 | 恢复合并、标题实时更新 |
| v1.0.1 | 2026-06-06 | 修复 Actions 构建（body 改用双引号） |
| v1.0.0 | 2026-06-06 | 重写文章解析（esbuild + Node.js） |
| v0.9.9 | 2026-06-05 | 恢复按钮从原始仓库下载 |
| v0.9.8 | 2026-06-05 | savePosts 安全保护 |
| v0.9.7 | 2026-06-05 | 安全保护逻辑修正 |
| v0.9.5 | 2026-06-05 | 修复闪退、强制配置 |
| v0.9.0 | 2026-06-05 | 发布进度弹窗、按钮修复、写作教学 |
| v0.8.0 | 2026-06-05 | 动森设计系统、3-tab 界面、首次引导 |

## 📄 许可证

MIT License - 仅供学习使用

## 🙏 致谢

- [animal-island-ui](https://github.com/guokaigdg/animal-island-ui) — 动森风格 React 组件库
- [animal-island-blog](https://github.com/guokaigdg/animal-island-blog) — 博客模板
- [animal_island_flutter](https://github.com/ohmangocat/animal_island_flutter) — 动森风格 Flutter 组件库
- [Vditor](https://github.com/Vanessa219/vditor) — Markdown 编辑器
- 任天堂《集合啦！动物森友会》— 设计灵感
