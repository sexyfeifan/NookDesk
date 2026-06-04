# NookDesk 🏝️

**动森风格博客管理工作台** — 配合 [animal-island-blog](https://github.com/sexyfeifan/animal-island-blog) 博客系统使用

一款 macOS 桌面应用，让你用动森风格的界面管理你的博客。支持文章创建/编辑、页面内容修改、一键发布到 GitHub Pages。

## 📦 下载安装

1. 前往 [Releases](https://github.com/sexyfeifan/NookDesk/releases) 页面
2. 下载最新版本的 `NookDesk-vX.X.X-universal.dmg`
3. 双击 DMG，将 NookDesk.app 拖入 Applications 文件夹
4. 首次打开可能需要在 系统设置 → 隐私与安全 中允许运行

> 支持 Intel (x86_64) 和 Apple Silicon (arm64) 双架构

## 🚀 快速开始

### 第一步：准备博客项目

1. Fork 本仓库中的 [animal-island-blog](https://github.com/sexyfeifan/animal-island-blog) 到你自己的 GitHub 账号
2. 在仓库 Settings → Pages 中，将 Source 设置为 **GitHub Actions**

### 第二步：首次启动 NookDesk

启动应用后会进入引导流程：

1. **欢迎页** — 了解 NookDesk 的功能
2. **选择项目** — 两种方式：
   - **从 GitHub 克隆**：输入你的博客仓库地址（如 `https://github.com/你的用户名/animal-island-blog.git`），选择本地保存目录
   - **选择本地目录**：如果已经有本地项目，直接选择目录
3. **配置 GitHub** — 填写远程仓库地址和发布分支
4. **配置 Token**（可选）— 填写 GitHub Personal Access Token，用于自动发布
5. **完成** — 查看配置摘要，进入主界面

### 第三步：写作

切换到「写作」标签页：
- 左侧是文章列表
- 点击「新建文章」创建新文章
- 使用 Vditor 富文本编辑器或 Markdown 编辑器编写内容
- 右侧检查器可以修改标题、日期、标签、颜色等

### 第四步：编辑页面

切换到「页面」标签页：
- 编辑首页的个人信息、技能标签、统计数据
- 编辑关于页面内容
- 编辑 FAQ 问答

### 第五步：发布

切换到「发布」标签页：
- 点击「发布」按钮
- 应用会自动：检测配置 → 保存内容 → 提交代码 → 推送到 GitHub
- GitHub Actions 会自动构建并部署到 GitHub Pages

## 🎨 功能特性

### 写作管理
- 📝 Vditor 富文本编辑器 + Markdown 双模式
- 🏷️ 文章标签、分类、颜色标记
- 📅 文章日期管理
- 📊 文章摘要自动生成

### 页面编辑
- 🏠 首页内容编辑（个人信息、技能、统计）
- 📄 关于页面编辑
- ❓ FAQ 问答编辑
- 🎨 13 种动森风格卡片颜色

### 发布管理
- 🚀 一键发布到 GitHub Pages
- ✅ 发布前完整检测（配置、Token、Workflow、Pages 来源）
- 🔧 检测失败自动给出修复建议
- 📊 GitHub Actions 状态监控
- 🔄 远程仓库同步

### 动森风格 UI
- 🎨 13 种 NookPhone 配色方案
- 🃏 圆角卡片设计
- 🌊 波浪分隔线
- 🍃 树叶加载动画
- ⌨️ 打字机文字效果
- 🎮 游戏风格按钮（3D 阴影）

### AI 辅助
- 🤖 AI 写作助手（支持 OpenAI 兼容 API）
- 📝 AI 文本格式化
- 🔍 AI 错误诊断

## 🛠️ 技术栈

- **前端框架**: SwiftUI (macOS 13+)
- **构建工具**: Swift Package Manager
- **博客系统**: React 19 + Vite + animal-island-ui
- **部署**: GitHub Pages + GitHub Actions
- **架构**: arm64 + x86_64 双架构

## 📁 项目结构

```
NookDesk/
├── v0.8.0/                    ← 当前版本源码
│   ├── Sources/NookDesk/
│   │   ├── Backends/          ← SSG 后端协议
│   │   ├── DesignSystem/      ← 动森风格 UI 组件
│   │   ├── Models/            ← 数据模型
│   │   ├── Services/          ← 业务逻辑
│   │   ├── ViewModels/        ← 视图模型
│   │   └── Views/             ← 界面视图
│   ├── Assets.xcassets/       ← 应用资源
│   ├── Package.swift
│   └── dist/                  ← 构建产物
├── v0.7.0/                    ← 历史版本
├── v0.6.0/                    ← 历史版本
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

# 打包 DMG
# ... (见 dist/ 目录)
```

## 📖 博客系统说明

NookDesk 管理的博客基于 [animal-island-blog](https://github.com/guokaigdg/animal-island-blog)，这是一个：

- React 19 + Vite 构建的博客
- 使用 [animal-island-ui](https://github.com/guokaigdg/animal-island-ui) 动森风格组件库
- 文章数据存储在 `src/pages/Home/posts.ts` 中
- 通过 GitHub Pages 部署

### 博客项目结构

```
animal-island-blog/
├── src/
│   ├── pages/
│   │   ├── Home/
│   │   │   ├── Home.tsx       ← 首页
│   │   │   └── posts.ts       ← 文章数据
│   │   └── Post/
│   │       └── Post.tsx       ← 文章详情页
│   ├── App.tsx                ← 路由配置
│   └── main.tsx               ← 入口文件
├── index.html
├── vite.config.ts
└── package.json
```

### 配合使用

1. **创建文章**: 在 NookDesk 写作页创建 → 保存到 posts.ts → 发布
2. **修改首页**: 在 NookDesk 页面页编辑个人信息 → 保存 → 发布
3. **发布**: NookDesk 自动提交推送 → GitHub Actions 自动构建部署

## ⚙️ 配置说明

### GitHub Token

推荐创建 Fine-grained Token：
1. 前往 GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens
2. 选择你的博客仓库
3. 权限选择：Contents (Read and write), Pages (Read and write), Actions (Read)
4. 将 Token 填入 NookDesk 设置

### Pages 部署

确保博客仓库：
1. Settings → Pages → Source 选择 **GitHub Actions**
2. 仓库中有 `.github/workflows/deploy.yml`（NookDesk 可自动生成）

## 📝 版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| v0.8.0 | 2026-06-05 | 完整引导流程、适配博客系统、动森风格 UI、页面编辑、发布检测 |
| v0.7.0 | 2026-06-04 | 修复拉取功能、清理 Hugo 遗留、动森 UI 组件 |
| v0.6.0 | 2026-06-04 | 版本更新检测、仓库结构拉取、AI 连通性测试 |
| v0.5.0 | 2026-06-04 | 初始版本：动森设计系统、3-tab 界面、首次引导 |

## 📄 许可证

MIT License - 仅供学习使用

## 🙏 致谢

- [animal-island-ui](https://github.com/guokaigdg/animal-island-ui) — 动森风格 React 组件库
- [animal-island-blog](https://github.com/guokaigdg/animal-island-blog) — 博客模板
- [Vditor](https://github.com/Vanessa219/vditor) — Markdown 编辑器
- 任天堂《集合啦！动物森友会》— 设计灵感
