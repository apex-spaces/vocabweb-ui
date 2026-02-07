# 单词本网站 — 产品设计总纲

**项目代号**：VocabWeb
**定位**：Web优先的智能单词收集与复习平台
**核心理念**：读什么学什么 — 从真实阅读场景中收集生词，用科学方法记住它们
**目标用户**：雅思/托福/考研/GRE 考试群体（先只做英语）
**设计日期**：2026-02-07

---

## 一、产品概述

### 差异化定位
1. **Web优先** — 电脑阅读场景的最佳伴侣，App们覆盖不到的地方
2. **阅读驱动** — 不背词库，读什么学什么，更自然
3. **强识别能力** — 划词、拍照OCR、文本粘贴、文档导入
4. **适度游戏化** — 打卡、徽章、等级、排行榜、挑战，提升留存
5. **考试导向** — 内置雅思/托福/考研/GRE词库，考频标注，备考计划

### 目标用户
- 经常在电脑上阅读英文内容的人（论文、新闻、文档）
- 想要系统积累词汇但觉得传统背单词App太枯燥的人
- 需要跨设备同步的学习者

---

## 二、核心功能模块

### 模块 1：智能识别与收集
| 收集方式 | 说明 | 优先级 |
|---------|------|--------|
| 浏览器插件划词 | Chrome/Edge插件，选中即收集 | P0 - MVP |
| 文本粘贴分析 | 粘贴一段英文，自动提取生词 | P0 - MVP |
| 图片OCR识别 | 拍书本/截图，识别英文单词 | P1 - Beta |
| 文档导入 | PDF/epub/URL，自动提取生词 | P1 - Beta |

**智能过滤**：根据用户已掌握词汇量，自动过滤已知词，只展示生词
**上下文保存**：记录单词出现的原文句子和来源URL

### 模块 2：艾宾浩斯遗忘曲线复习
- SM-2算法，根据用户反馈动态调整复习间隔
- 三级评分：认识 / 模糊 / 不认识
- 每日复习目标可自定义
- 复习提醒通知
- **按遗忘概率排序**：越容易忘的词排越前面，优先复习

**遗忘概率排序算法：**
```
遗忘概率 = f(easiness_factor, 距上次复习天数, 历史错误率)

排序权重：
  - easiness_factor 越低 → 越难记 → 权重越高
  - 距上次复习时间越长 → 越可能忘 → 权重越高  
  - 历史错误率越高 → 越不稳定 → 权重越高
  - repetitions 越少 → 记忆越不牢固 → 权重越高

复习队列 = 待复习单词按遗忘概率从高到低排序
单词列表 = 也支持按"遗忘风险"排序，随时查看最危险的词
```

### 模块 3：单词本管理
- 分组（如：工作、考试、兴趣）
- 标签（如：#GRE、#计算机、#日常）
- 搜索、排序、批量操作

### 模块 4：学习统计
- 每日学习量趋势图
- 掌握程度分布（新词/学习中/已掌握）
- 遗忘曲线可视化
- 连续学习天数

### 模块 5：游戏化系统
- **连续打卡** — 每日学习打卡，显示连续天数，断签提醒
- **成就徽章** — "百词斩"、"连续7天"、"第一次OCR"、"GRE勇士"等
- **等级系统** — 积累经验值升级（青铜→白银→黄金→钻石）
- **排行榜** — 每周/每月学习量排名（好友/全站）
- **学习目标挑战** — 设定"30天背500词"，完成有奖励动画

### 模块 6：考试功能
- **内置考试词库** — 预装雅思/托福/考研/GRE核心词汇
- **考试模式** — 模拟考试场景的限时测试
- **词汇量测试** — 测试当前水平，推荐对应考试词库
- **考频标注** — 标记每个词在真题中出现的频率（高频/中频/低频）
- **备考计划** — 根据考试日期自动生成每日学习量和进度

---

## 三、技术架构

### 技术栈
| 层级 | 选型 | 说明 |
|------|------|------|
| 前端 | Next.js 14 (App Router) | SSR/SSG，SEO友好 |
| UI库 | Tailwind CSS + shadcn/ui | 快速开发，风格统一 |
| 后端 | Go | 前后端分离，独立Cloud Run服务 |
| 数据库 | Cloud SQL (PostgreSQL 15) | GCP托管，自动备份 |
| 认证 | Google Identity Platform | GCP原生，gcloud可启用 |
| 图片识别 | Cloud Vision API | 高精度OCR文字提取 |
| AI分析 | Vertex AI (Gemini) | 生词判断、释义生成 |
| 存储 | Google Cloud Storage | 音频、图片等静态资源 |
| CDN | Cloud CDN | 全球加速 |
| 部署 | Cloud Run | 容器化，自动扩缩容 |
| CI/CD | Cloud Build | 自动构建部署 |

### GCP 部署架构
```
用户 → Cloud CDN → Cloud Run (Next.js 前端)
                        ↓ API调用
                   Cloud Run (Go 后端)
                        ↓
                   Cloud SQL (PostgreSQL)
                   Cloud Vision API (图片OCR)
                   Vertex AI / Gemini (生词分析)
                   Cloud Storage (静态资源)
                   Identity Platform (认证)
```

### 部署信息
- **GCP项目**：openclaw-lytzju
- **区域**：asia-east2（香港）
- **原则**：尽可能使用Google Cloud基础设施，统一运维

### 成本预估（GCP）
| 阶段 | 月活用户 | 预估月费 |
|------|---------|---------|
| MVP | <100 | ~$10-20（Cloud Run最低配 + Cloud SQL基础版）|
| 增长期 | 1K-10K | ~$50-100 |
| 规模化 | 10K+ | $200+ |

---

## 四、页面清单

| # | 页面 | 路由 | 说明 |
|---|------|------|------|
| 1 | Landing Page | `/` | 产品介绍，注册引导 |
| 2 | 登录/注册 | `/auth` | 邮箱+Google登录 |
| 3 | Dashboard | `/dashboard` | 今日待复习、统计概览、最近收集 |
| 4 | 单词列表 | `/words` | 全部单词，分组/标签/搜索/遗忘风险排序 |
| 5 | 复习页 | `/review` | 卡片翻转式复习，按遗忘概率排序 |
| 6 | 单词详情 | `/words/[id]` | 释义、例句、复习历史 |
| 7 | 学习统计 | `/stats` | 图表、趋势、分布 |
| 8 | 考试中心 | `/exam` | 词库选择、考试模式、词汇量测试 |
| 9 | 备考计划 | `/plan` | 根据考试日期生成学习计划 |
| 10 | 排行榜 | `/leaderboard` | 每周/每月学习量排名 |
| 11 | 成就 | `/achievements` | 徽章、等级、挑战进度 |
| 12 | 设置 | `/settings` | 目标、提醒、账号 |

详细原型见：`vocabulary-app-prototype.md`

---

## 五、数据模型概览

### 核心表（12张）
| 表名 | 用途 | 关键字段 |
|------|------|---------|
| profiles | 用户扩展信息 | username, daily_review_goal, timezone, level, xp |
| words | 全局单词库（共享） | word, phonetic, definitions, frequency_rank |
| user_words | 用户-单词关系 | user_id, word_id, source_url, context_sentence |
| groups | 用户分组 | name, color, sort_order |
| tags | 用户标签 | name, color |
| user_word_tags | 单词-标签关联 | user_word_id, tag_id |
| review_logs | 复习记录 | quality, easiness_factor, interval, next_review_at |
| daily_stats | 每日统计快照 | new_words, reviewed, mastered, streak_days |
| achievements | 成就/徽章定义 | name, description, condition, icon |
| user_achievements | 用户已获得成就 | user_id, achievement_id, earned_at |
| exam_wordlists | 考试词库 | exam_type, word_id, frequency_in_exam |
| study_plans | 备考计划 | user_id, exam_type, exam_date, daily_target |

完整DDL见：`vocabulary-db-schema.sql`

---

## 六、API 模块概览

| 模块 | 接口数 | 说明 |
|------|--------|------|
| Auth | 7 | 注册、登录、OAuth、Token管理 |
| Words | 8 | 单词CRUD、搜索、批量操作 |
| Groups & Tags | 11 | 分组/标签CRUD、关联管理 |
| Review | 5 | 待复习列表、提交结果、历史 |
| Stats | 5 | 每日/累计统计、趋势、热力图 |
| Extension Sync | 7 | 插件认证、批量同步、心跳 |
| **合计** | **43** | |

完整接口文档见：`vocabulary-api-docs.md`

---

## 七、智能识别模块设计

### 7.1 浏览器插件（P0 - MVP）
- Chrome Extension (Manifest V3)
- Content Script 监听选中文本
- 弹窗显示释义 + 一键收藏
- 后台同步到云端

### 7.2 文本粘贴分析（P0 - MVP）
- 用户粘贴英文段落
- 后端分词 → 过滤已知词 → 返回生词列表
- 用户勾选要收集的词
- 保存原文作为上下文

### 7.3 图片智能识别（P0 - MVP）
- **两步方案：Cloud Vision + Vertex AI (Gemini)**
- 全部在 GCP 生态内，统一管理

**Step 1：Cloud Vision API — 高精度OCR**
- 使用 DOCUMENT_TEXT_DETECTION（适合书本/文档）
- 提取完整文字 + 段落结构 + 位置信息
- 准确率 95-99%，支持弯曲页面、高亮标注、图文混排

**Step 2：Vertex AI (Gemini) — 智能分析**
- 输入OCR提取的文字 + 用户词汇水平
- 输出：生词列表 + 释义 + 词性 + 原文上下文
- 能理解语境，判断一词多义

**流程：**
```
图片上传 → Cloud Vision (OCR提取文字)
         → Vertex AI / Gemini (分析生词+释义)
         → 返回生词列表供用户确认
         → 用户勾选 → 入库
```

**成本（GCP统一计费）：**
| API | 免费额度 | 超出后 |
|-----|---------|--------|
| Cloud Vision | 1000次/月免费 | $1.5/千次 |
| Vertex AI (Gemini) | 有免费额度 | 按token计费 |

**为什么用两步而不是一步：**
- Cloud Vision 专做OCR，精度最高
- Gemini 专做语义理解，生词判断更准
- 各司其职，比单一方案更可靠
- 全在 GCP 内，一个项目一个账单

### 7.4 文档导入（P1 - Beta）
- 支持 PDF、epub、纯文本
- 使用 pdf-parse / epub.js 提取文本
- 同上流程：分词 → 过滤 → 展示

### 7.5 生词智能过滤算法
```
输入文本 → 分词(NLP) → 词形还原(lemmatization)
    → 过滤停用词(the/a/is...)
    → 过滤用户已掌握词
    → 按词频排序（低频词优先展示）
    → 自动查询释义
    → 返回生词列表
```

---

## 八、实施路线图

### Phase 1: MVP-核心（2周）
- [ ] 项目初始化（Next.js前端 + Go后端 + GCP）
- [ ] Google Identity Platform 认证
- [ ] 手动添加单词 + 文本粘贴分析
- [ ] SM-2遗忘曲线复习（含遗忘概率排序）
- [ ] Dashboard基础版
- [ ] 部署到Cloud Run（前后端各一个服务）

### Phase 2: MVP-识别（1周）
- [ ] Cloud Vision OCR + Vertex AI Gemini 图片识别
- [ ] 用户确认生词 → 入库
- [ ] 上下文保存

### Phase 3: MVP-插件（1周）
- [ ] Chrome浏览器划词插件
- [ ] 插件认证 + 同步

### Phase 4: 考试功能（2周）
- [ ] 内置考试词库（雅思/托福/考研/GRE）
- [ ] 词汇量测试
- [ ] 考频标注
- [ ] 考试模式（限时测试）
- [ ] 备考计划生成

### Phase 5: 游戏化（2周）
- [ ] 连续打卡 + 断签提醒
- [ ] 成就徽章系统
- [ ] 等级系统（经验值）
- [ ] 排行榜
- [ ] 学习目标挑战

### Phase 6: 体验优化（2周）
- [ ] 学习统计页（图表）
- [ ] 发音/例句（接词典API）
- [ ] 移动端适配（响应式/PWA）
- [ ] 复习提醒通知
- [ ] 生词智能过滤（COCA词频）

### Phase 7: 增长（持续）
- [ ] 文档导入（PDF/epub）
- [ ] SEO优化
- [ ] 用户反馈迭代

---

## 九、设计文档索引

| 文档 | 路径 | 内容 |
|------|------|------|
| 产品总纲（本文件） | `projects/vocabulary-app/PLAN.md` | 整体设计 |
| 页面原型 | `vocabulary-app-prototype.md` | 8个页面详细原型 |
| 数据库DDL | `vocabulary-db-schema.sql` | 完整SQL，可直接执行 |
| API接口文档 | `vocabulary-api-docs.md` | 43个接口完整定义 |
| 决策记录 | `projects/vocabulary-app/DECISIONS.md` | 待创建 |
| 进度追踪 | `projects/vocabulary-app/PROGRESS.md` | 待创建 |
