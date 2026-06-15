# NookDesk 🏝️

**动森风格博客管理工作台** — 支持 Astro / Vite / Hugo 多博客系统

一款 macOS 桌面应用，让你用动森风格的界面管理你的博客。支持文章创建/编辑、页面内容修改、一键发布到 GitHub Pages。

## 支持的博客系统

| 后端 | 框架 | 文章格式 | 说明 |
|------|------|----------|------|
| **Astro** | Astro + React | Markdown + frontmatter | ✅ 推荐，动森风格模板 |
| Vite | React 19 + Vite | TypeScript (posts.ts) | animal-island-blog 模板 |
| Hugo | Hugo | Markdown + TOML/YAML | 通用 Hugo 博客 |

## 📦 下载安装

1. 前往 [Releases](https://github.com/sexyfeifan/NookDesk/releases) 页面
2. 下载最新版本的 `NookDesk-v2.0.0-universal.dmg`
3. 双击 DMG，将 NookDesk.app 拖入 Applications 文件夹
4. 首次打开可能需要在 系统设置 → 隐私与安全 中允许运行

> 支持 Intel (x86_64) 和 Apple Silicon (arm64) 双架构，最低系统要求 macOS 13

---

## 🚀 快速开始（Astro 博客）

### 第一步：Fork 博客模板

1. 打开 [animal-island-blog-astro](https://github.com/sexyfeifan/sexyfeifan.github.io)（或使用 NookDesk 内置模板）
2. 点击右上角 **Fork** 按钮
3. 进入 **Settings → Pages**，将 Source 改为 **GitHub Actions**

### 第二步：配置 NookDesk

1. 启动 NookDesk，进入引导流程
2. 选择本地博客目录或从 GitHub 克隆
3. 填写 GitHub Token（推荐 Fine-grained Token）
4. 完成配置

### 第三步：写作

切换到 **「写作」** 标签页：

- 点击「+ 新文章」创建 Markdown 文章
- 编辑标题、摘要、分类、标签等 frontmatter
- 使用 Markdown 编辑器编写正文
- 点击「保存并发布」一键推送

### 第四步：编辑页面

切换到 **「页面」** 标签页：

- **站点配置** — 修改站点标题和描述
- **项目展示** — 管理项目列表
- **友情链接** — 管理友链

### 第五步：发布

切换到 **「发布」** 标签页：

1. 点击「一键发布」
2. 自动检查配置 → 提交推送 → 等待部署
3. 部署完成后访问 `https://你的用户名.github.io`

---

## 🎨 功能特性

### 写作管理
- 📝 Markdown 编辑器（支持中文输入法）
- 🏷️ 分类 + 标签系统
- 📅 日期管理
- 🎨 12 种动森风格卡片颜色
- 💾 保存 / 保存并发布 / 删除

### 页面编辑
- 🏠 Astro：站点配置、项目展示、友链管理
- 🏠 Vite：品牌、英雄区、技能、统计、关于、FAQ
- 📝 每个区域独立保存

### 发布管理
- 🚀 一键发布（3 步简化流程）
- ✅ 自动检测项目配置
- 🔧 自动生成 GitHub Actions Workflow
- 📊 部署状态监控

### 动森风格 UI
- 🎨 12 种 NookPhone 配色方案
- 🃏 圆角卡片设计
- 🌊 波浪分隔线
- 🍃 树叶加载动画

---

## 📖 Astro 博客文章格式

文章存储在 `src/content/blog/` 目录下，使用 Markdown + YAML frontmatter：

```markdown
---
title: "文章标题"
description: "文章描述"
pubDate: 2026-06-15
category: "技术"
tags: ["Astro", "博客"]
cover: "🏝️"
color: "app-blue"
readTime: "5 分钟"
draft: false
---

## 章节标题

正文内容...
```

---

## ⚙️ GitHub Token 配置

推荐创建 Fine-grained Token：

1. GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens
2. Generate new token，选择你的博客仓库
3. Permissions：Contents (Read and write)、Pages (Read and write)、Actions (Read)
4. 在 NookDesk 设置中粘贴 Token

---

## 🛠️ 技术栈

- **应用框架**: SwiftUI (macOS 13+)
- **构建工具**: Swift Package Manager
- **博客系统**: Astro / React 19 + Vite / Hugo
- **部署**: GitHub Pages + GitHub Actions
- **架构**: arm64 + x86_64 双架构

## 📁 项目结构

```
NookDesk/
├── v0.8.0/                    ← 当前版本源码
│   ├── Sources/NookDesk/
│   │   ├── Backends/          ← SSG 后端（Astro / Hugo / Vite）
│   │   ├── DesignSystem/      ← 动森风格 UI 组件
│   │   ├── Models/            ← 数据模型
│   │   ├── Services/          ← 业务逻辑
│   │   ├── ViewModels/        ← 视图模型
│   │   └── Views/             ← 界面视图
│   └── Package.swift
├── README.md
└── LICENSE
```

## 📝 版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| v2.0.0 | 2026-06-15 | 新增 Astro 后端支持、简化发布流程、页面编辑器适配 |
| v1.3.4 | 2026-06-14 | 逐行审查修复 |
| v1.3.3 | 2026-06-11 | 深度审计修复 |
| v1.3.0 | 2026-06-11 | 全面审计修复 |
| v1.0.0 | 2026-06-06 | 重写文章解析 |
| v0.8.0 | 2026-06-05 | 动森设计系统、3-tab 界面 |

## 📄 许可证

MIT License - 仅供学习使用

## 🙏 致谢

- [animal-island-ui](https://github.com/guokaigdg/animal-island-ui) — 动森风格 React 组件库
- [animal-island-blog](https://github.com/guokaigdg/animal-island-blog) — 博客模板
- [Astro](https://astro.build/) — 现代 Web 构建框架
- 任天堂《集合啦！动物森友会》— 设计灵感
