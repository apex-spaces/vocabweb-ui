# 单词本网站 RESTful API 接口文档

**版本**: v1.0  
**基础路径**: `/api/v1`  
**技术栈**: Next.js 14 (App Router) + Supabase (PostgreSQL + Auth)

---

## 通用说明

### 认证方式
- 使用 JWT Bearer Token
- Header: `Authorization: Bearer <token>`
- Supabase Auth 自动管理 Token 刷新

### 响应格式

**成功响应**:
```json
{
  "success": true,
  "data": { ... },
  "message": "操作成功"
}
```

**错误响应**:
```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "错误描述",
    "details": { ... }
  }
}
```

### 通用错误码
- `401` - 未认证或 Token 过期
- `403` - 权限不足
- `404` - 资源不存在
- `422` - 请求参数验证失败
- `429` - 请求频率超限
- `500` - 服务器内部错误

---

## 1. 认证模块 (Auth)

### 1.1 用户注册

**接口**: `POST /auth/register`  
**认证**: 无需认证

**Request Body**:
```json
{
  "email": "user@example.com",
  "password": "password123",
  "username": "username",
  "language": "zh-CN"
}
```

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "username": "username",
      "created_at": "2024-01-01T00:00:00Z"
    },
    "session": {
      "access_token": "jwt_token",
      "refresh_token": "refresh_token",
      "expires_in": 3600,
      "token_type": "bearer"
    }
  },
  "message": "注册成功"
}
```

**错误响应**:
- `422` - 邮箱已存在、密码强度不足
- `400` - 参数格式错误

---

### 1.2 用户登录

**接口**: `POST /auth/login`  
**认证**: 无需认证

**Request Body**:
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "username": "username",
      "avatar_url": "https://...",
      "settings": {
        "daily_goal": 20,
        "notification_enabled": true
      }
    },
    "session": {
      "access_token": "jwt_token",
      "refresh_token": "refresh_token",
      "expires_in": 3600,
      "token_type": "bearer"
    }
  },
  "message": "登录成功"
}
```

**错误响应**:
- `401` - 邮箱或密码错误
- `403` - 账号已被禁用

---

### 1.3 用户登出

**接口**: `POST /auth/logout`  
**认证**: 需要 Bearer Token

**Request Body**: 无

**Response (200)**:
```json
{
  "success": true,
  "message": "登出成功"
}
```

---

### 1.4 刷新 Token

**接口**: `POST /auth/refresh`  
**认证**: 需要 Refresh Token

**Request Body**:
```json
{
  "refresh_token": "refresh_token_string"
}
```

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "access_token": "new_jwt_token",
    "refresh_token": "new_refresh_token",
    "expires_in": 3600,
    "token_type": "bearer"
  }
}
```

**错误响应**:
- `401` - Refresh Token 无效或过期

---

### 1.5 第三方 OAuth 登录

**接口**: `GET /auth/oauth/{provider}`  
**认证**: 无需认证  
**支持的 Provider**: `google`, `github`, `apple`

**Query Params**:
- `redirect_uri` (optional): 登录成功后的回调地址

**说明**: 
- 重定向到第三方 OAuth 授权页面
- 授权成功后回调到 `/auth/oauth/callback/{provider}`
- Supabase Auth 自动处理 OAuth 流程

**Callback Response**:
重定向到前端页面，URL 包含:
```
https://your-app.com/auth/callback?access_token=xxx&refresh_token=xxx
```

---

### 1.6 获取当前用户信息

**接口**: `GET /auth/me`  
**认证**: 需要 Bearer Token

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "email": "user@example.com",
    "username": "username",
    "avatar_url": "https://...",
    "created_at": "2024-01-01T00:00:00Z",
    "settings": {
      "daily_goal": 20,
      "notification_enabled": true,
      "review_time": "09:00",
      "language": "zh-CN"
    },
    "stats": {
      "total_words": 150,
      "reviewed_today": 12,
      "streak_days": 7
    }
  }
}
```

---

### 1.7 更新用户信息

**接口**: `PATCH /auth/me`  
**认证**: 需要 Bearer Token

**Request Body**:
```json
{
  "username": "new_username",
  "avatar_url": "https://...",
  "settings": {
    "daily_goal": 30,
    "notification_enabled": false,
    "review_time": "10:00"
  }
}
```

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "email": "user@example.com",
    "username": "new_username",
    "avatar_url": "https://...",
    "settings": { ... }
  },
  "message": "更新成功"
}
```

---

## 2. 单词模块 (Words)

### 2.1 添加单词（手动）

**接口**: `POST /words`  
**认证**: 需要 Bearer Token

**Request Body**:
```json
{
  "word": "vocabulary",
  "definition": "词汇；词汇量",
  "pronunciation": "/vəˈkæbjələri/",
  "example_sentence": "He has a large vocabulary.",
  "translation": "他的词汇量很大。",
  "source_url": "https://...",
  "group_id": "uuid",
  "tags": ["academic", "important"]
}
```

**Response (201)**:
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "word": "vocabulary",
    "definition": "词汇；词汇量",
    "pronunciation": "/vəˈkæbjələri/",
    "example_sentence": "He has a large vocabulary.",
    "translation": "他的词汇量很大。",
    "source_url": "https://...",
    "group_id": "uuid",
    "tags": ["academic", "important"],
    "user_id": "uuid",
    "created_at": "2024-01-01T00:00:00Z",
    "next_review_at": "2024-01-02T00:00:00Z",
    "review_count": 0,
    "mastery_level": 0,
    "ease_factor": 2.5
  },
  "message": "单词添加成功"
}
```

**错误响应**:
- `422` - 单词已存在
- `400` - 必填字段缺失

---

### 2.2 批量添加单词

**接口**: `POST /words/batch`  
**认证**: 需要 Bearer Token

**Request Body**:
```json
{
  "words": [
    {
      "word": "apple",
      "definition": "苹果",
      "group_id": "uuid"
    },
    {
      "word": "banana",
      "definition": "香蕉"
    }
  ],
  "skip_duplicates": true
}
```

**Response (201)**:
```json
{
  "success": true,
  "data": {
    "created": 2,
    "skipped": 0,
    "failed": 0,
    "words": [
      { "id": "uuid1", "word": "apple", ... },
      { "id": "uuid2", "word": "banana", ... }
    ],
    "errors": []
  },
  "message": "批量添加完成"
}
```

---

### 2.3 查询单词列表

**接口**: `GET /words`  
**认证**: 需要 Bearer Token

**Query Params**:
- `page` (int, default: 1): 页码
- `limit` (int, default: 20, max: 100): 每页数量
- `sort` (string, default: "created_at"): 排序字段 (`created_at`, `word`, `mastery_level`, `next_review_at`)
- `order` (string, default: "desc"): 排序方向 (`asc`, `desc`)
- `group_id` (uuid, optional): 按分组筛选
- `tags` (string, optional): 按标签筛选，逗号分隔 (`tag1,tag2`)
- `mastery_level` (int, optional): 按掌握程度筛选 (0-5)
- `status` (string, optional): 筛选状态 (`learning`, `reviewing`, `mastered`)

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "words": [
      {
        "id": "uuid",
        "word": "vocabulary",
        "definition": "词汇；词汇量",
        "pronunciation": "/vəˈkæbjələri/",
        "group": {
          "id": "uuid",
          "name": "TOEFL"
        },
        "tags": ["academic", "important"],
        "mastery_level": 2,
        "next_review_at": "2024-01-05T00:00:00Z",
        "created_at": "2024-01-01T00:00:00Z"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 150,
      "total_pages": 8
    }
  }
}
```

---

### 2.4 搜索单词（模糊搜索）

**接口**: `GET /words/search`  
**认证**: 需要 Bearer Token

**Query Params**:
- `q` (string, required): 搜索关键词
- `fields` (string, optional): 搜索字段 (`word`, `definition`, `all`)，默认 `all`
- `limit` (int, default: 20): 返回数量

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "results": [
      {
        "id": "uuid",
        "word": "vocabulary",
        "definition": "词汇；词汇量",
        "match_field": "word",
        "highlight": "<mark>vocab</mark>ulary"
      }
    ],
    "total": 5
  }
}
```

---

### 2.5 获取单词详情

**接口**: `GET /words/{word_id}`  
**认证**: 需要 Bearer Token

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "word": "vocabulary",
    "definition": "词汇；词汇量",
    "pronunciation": "/vəˈkæbjələri/",
    "example_sentence": "He has a large vocabulary.",
    "translation": "他的词汇量很大。",
    "source_url": "https://...",
    "group": {
      "id": "uuid",
      "name": "TOEFL"
    },
    "tags": ["academic", "important"],
    "user_id": "uuid",
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-03T00:00:00Z",
    "review_stats": {
      "review_count": 5,
      "mastery_level": 2,
      "ease_factor": 2.5,
      "interval_days": 3,
      "next_review_at": "2024-01-05T00:00:00Z",
      "last_reviewed_at": "2024-01-02T00:00:00Z"
    },
    "review_history": [
      {
        "reviewed_at": "2024-01-02T10:00:00Z",
        "quality": 4,
        "time_spent_seconds": 15
      }
    ]
  }
}
```

**错误响应**:
- `404` - 单词不存在或不属于当前用户

---

### 2.6 编辑单词

**接口**: `PATCH /words/{word_id}`  
**认证**: 需要 Bearer Token

**Request Body**:
```json
{
  "definition": "更新后的定义",
  "pronunciation": "/new/",
  "example_sentence": "新例句",
  "translation": "新翻译",
  "group_id": "uuid",
  "tags": ["updated_tag"]
}
```

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "word": "vocabulary",
    "definition": "更新后的定义",
    "updated_at": "2024-01-03T00:00:00Z"
  },
  "message": "更新成功"
}
```

---

### 2.7 删除单词

**接口**: `DELETE /words/{word_id}`  
**认证**: 需要 Bearer Token

**Response (200)**:
```json
{
  "success": true,
  "message": "单词已删除"
}
```

**错误响应**:
- `404` - 单词不存在

---

### 2.8 批量删除单词

**接口**: `DELETE /words/batch`  
**认证**: 需要 Bearer Token

**Request Body**:
```json
{
  "word_ids": ["uuid1", "uuid2", "uuid3"]
}
```

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "deleted": 3,
    "failed": 0
  },
  "message": "批量删除完成"
}
```

---

## 3. 分组/标签模块 (Groups & Tags)

### 3.1 创建分组

**接口**: `POST /groups`  
**认证**: 需要 Bearer Token

**Request Body**:
```json
{
  "name": "TOEFL",
  "description": "托福词汇",
  "color": "#FF5733"
}
```

**Response (201)**:
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "name": "TOEFL",
    "description": "托福词汇",
    "color": "#FF5733",
    "word_count": 0,
    "created_at": "2024-01-01T00:00:00Z"
  },
  "message": "分组创建成功"
}
```

---

### 3.2 获取分组列表

**接口**: `GET /groups`  
**认证**: 需要 Bearer Token

**Query Params**:
- `include_count` (boolean, default: true): 是否包含单词数量

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "groups": [
      {
        "id": "uuid",
        "name": "TOEFL",
        "description": "托福词汇",
        "color": "#FF5733",
        "word_count": 150,
        "created_at": "2024-01-01T00:00:00Z"
      }
    ],
    "total": 5
  }
}
```

---

### 3.3 获取分组详情

**接口**: `GET /groups/{group_id}`  
**认证**: 需要 Bearer Token

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "name": "TOEFL",
    "description": "托福词汇",
    "color": "#FF5733",
    "word_count": 150,
    "created_at": "2024-01-01T00:00:00Z",
    "stats": {
      "mastered": 50,
      "reviewing": 70,
      "learning": 30
    }
  }
}
```

---

### 3.4 更新分组

**接口**: `PATCH /groups/{group_id}`  
**认证**: 需要 Bearer Token

**Request Body**:
```json
{
  "name": "TOEFL Advanced",
  "description": "托福高级词汇",
  "color": "#00FF00"
}
```

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "name": "TOEFL Advanced",
    "description": "托福高级词汇",
    "color": "#00FF00",
    "updated_at": "2024-01-03T00:00:00Z"
  },
  "message": "分组更新成功"
}
```

---

### 3.5 删除分组

**接口**: `DELETE /groups/{group_id}`  
**认证**: 需要 Bearer Token

**Query Params**:
- `move_words_to` (uuid, optional): 将单词移动到指定分组，不传则解除分组关联

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "deleted_group_id": "uuid",
    "affected_words": 150
  },
  "message": "分组已删除"
}
```

---

### 3.6 创建标签

**接口**: `POST /tags`  
**认证**: 需要 Bearer Token

**Request Body**:
```json
{
  "name": "important",
  "color": "#FF0000"
}
```

**Response (201)**:
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "name": "important",
    "color": "#FF0000",
    "word_count": 0,
    "created_at": "2024-01-01T00:00:00Z"
  },
  "message": "标签创建成功"
}
```

---

### 3.7 获取标签列表

**接口**: `GET /tags`  
**认证**: 需要 Bearer Token

**Query Params**:
- `include_count` (boolean, default: true): 是否包含单词数量

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "tags": [
      {
        "id": "uuid",
        "name": "important",
        "color": "#FF0000",
        "word_count": 25,
        "created_at": "2024-01-01T00:00:00Z"
      }
    ],
    "total": 10
  }
}
```

---

### 3.8 更新标签

**接口**: `PATCH /tags/{tag_id}`  
**认证**: 需要 Bearer Token

**Request Body**:
```json
{
  "name": "very_important",
  "color": "#FF00FF"
}
```

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "name": "very_important",
    "color": "#FF00FF",
    "updated_at": "2024-01-03T00:00:00Z"
  },
  "message": "标签更新成功"
}
```

---

### 3.9 删除标签

**接口**: `DELETE /tags/{tag_id}`  
**认证**: 需要 Bearer Token

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "deleted_tag_id": "uuid",
    "affected_words": 25
  },
  "message": "标签已删除"
}
```

---

### 3.10 给单词添加标签

**接口**: `POST /words/{word_id}/tags`  
**认证**: 需要 Bearer Token

**Request Body**:
```json
{
  "tag_ids": ["uuid1", "uuid2"]
}
```

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "word_id": "uuid",
    "tags": [
      { "id": "uuid1", "name": "important" },
      { "id": "uuid2", "name": "academic" }
    ]
  },
  "message": "标签添加成功"
}
```

---

### 3.11 移除单词标签

**接口**: `DELETE /words/{word_id}/tags`  
**认证**: 需要 Bearer Token

**Request Body**:
```json
{
  "tag_ids": ["uuid1", "uuid2"]
}
```

**Response (200)**:
```json
{
  "success": true,
  "message": "标签移除成功"
}
```

---

## 4. 复习模块 (Review)

### 4.1 获取今日待复习单词列表

**接口**: `GET /review/due`  
**认证**: 需要 Bearer Token

**Query Params**:
- `limit` (int, default: 20): 返回数量
- `group_id` (uuid, optional): 按分组筛选
- `include_new` (boolean, default: false): 是否包含新单词

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "words": [
      {
        "id": "uuid",
        "word": "vocabulary",
        "definition": "词汇；词汇量",
        "pronunciation": "/vəˈkæbjələri/",
        "example_sentence": "He has a large vocabulary.",
        "translation": "他的词汇量很大。",
        "group": {
          "id": "uuid",
          "name": "TOEFL"
        },
        "tags": ["academic"],
        "review_stats": {
          "review_count": 5,
          "mastery_level": 2,
          "ease_factor": 2.5,
          "last_reviewed_at": "2024-01-02T00:00:00Z",
          "next_review_at": "2024-01-05T00:00:00Z"
        }
      }
    ],
    "total_due": 15,
    "total_new": 5,
    "returned": 15
  }
}
```

---

### 4.2 提交复习结果

**接口**: `POST /review/submit`  
**认证**: 需要 Bearer Token

**Request Body**:
```json
{
  "word_id": "uuid",
  "quality": 4,
  "time_spent_seconds": 15
}
```

**Quality 评分标准 (SM-2算法)**:
- `0` - 完全不记得
- `1` - 不认识
- `2` - 模糊，想了很久才想起
- `3` - 犹豫，但最终想起
- `4` - 轻松想起，稍有犹豫
- `5` - 完全掌握，立即想起

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "word_id": "uuid",
    "review_stats": {
      "review_count": 6,
      "mastery_level": 3,
      "ease_factor": 2.6,
      "interval_days": 7,
      "next_review_at": "2024-01-12T00:00:00Z",
      "last_reviewed_at": "2024-01-05T10:30:00Z"
    },
    "progress": {
      "level_up": true,
      "previous_level": 2,
      "current_level": 3
    }
  },
  "message": "复习记录已保存"
}
```

---

### 4.3 批量提交复习结果

**接口**: `POST /review/submit-batch`  
**认证**: 需要 Bearer Token

**Request Body**:
```json
{
  "reviews": [
    {
      "word_id": "uuid1",
      "quality": 4,
      "time_spent_seconds": 15
    },
    {
      "word_id": "uuid2",
      "quality": 2,
      "time_spent_seconds": 25
    }
  ]
}
```

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "processed": 2,
    "failed": 0,
    "results": [
      {
        "word_id": "uuid1",
        "next_review_at": "2024-01-12T00:00:00Z",
        "mastery_level": 3
      },
      {
        "word_id": "uuid2",
        "next_review_at": "2024-01-06T00:00:00Z",
        "mastery_level": 1
      }
    ]
  },
  "message": "批量复习完成"
}
```

---


### 4.4 获取复习历史

**接口**: `GET /review/history`  
**认证**: 需要 Bearer Token

**Query Params**:
- `page` (int, default: 1): 页码
- `limit` (int, default: 20): 每页数量
- `word_id` (uuid, optional): 按单词筛选
- `start_date` (date, optional): 开始日期 (YYYY-MM-DD)
- `end_date` (date, optional): 结束日期 (YYYY-MM-DD)

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "history": [
      {
        "id": "uuid",
        "word": {
          "id": "uuid",
          "word": "vocabulary",
          "definition": "词汇；词汇量"
        },
        "quality": 4,
        "time_spent_seconds": 15,
        "reviewed_at": "2024-01-05T10:30:00Z",
        "mastery_level_before": 2,
        "mastery_level_after": 3
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 150,
      "total_pages": 8
    }
  }
}
```

---

### 4.5 获取复习统计概览

**接口**: `GET /review/overview`  
**认证**: 需要 Bearer Token

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "today": {
      "due": 15,
      "completed": 12,
      "remaining": 3,
      "new_words": 5
    },
    "upcoming": {
      "tomorrow": 8,
      "next_7_days": 45,
      "next_30_days": 120
    },
    "mastery_distribution": {
      "level_0": 20,
      "level_1": 30,
      "level_2": 40,
      "level_3": 35,
      "level_4": 20,
      "level_5": 5
    }
  }
}
```

---

## 5. 统计模块 (Stats)

### 5.1 获取每日学习统计

**接口**: `GET /stats/daily`  
**认证**: 需要 Bearer Token

**Query Params**:
- `date` (date, optional): 指定日期 (YYYY-MM-DD)，默认今天

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "date": "2024-01-05",
    "words_reviewed": 12,
    "words_added": 5,
    "time_spent_minutes": 45,
    "accuracy_rate": 0.85,
    "streak_days": 7,
    "daily_goal": 20,
    "goal_progress": 0.6,
    "mastery_changes": {
      "level_up": 3,
      "level_down": 1
    }
  }
}
```

---

### 5.2 获取累计统计

**接口**: `GET /stats/total`  
**认证**: 需要 Bearer Token

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "total_words": 150,
    "total_reviews": 450,
    "total_time_minutes": 1200,
    "average_accuracy": 0.82,
    "longest_streak": 15,
    "current_streak": 7,
    "mastered_words": 25,
    "learning_words": 100,
    "new_words": 25,
    "account_age_days": 30,
    "average_daily_reviews": 15
  }
}
```

---

### 5.3 获取掌握程度分布

**接口**: `GET /stats/mastery-distribution`  
**认证**: 需要 Bearer Token

**Query Params**:
- `group_id` (uuid, optional): 按分组筛选

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "distribution": [
      {
        "mastery_level": 0,
        "count": 20,
        "percentage": 0.133,
        "label": "新单词"
      },
      {
        "mastery_level": 1,
        "count": 30,
        "percentage": 0.2,
        "label": "学习中"
      },
      {
        "mastery_level": 2,
        "count": 40,
        "percentage": 0.267,
        "label": "熟悉"
      },
      {
        "mastery_level": 3,
        "count": 35,
        "percentage": 0.233,
        "label": "掌握"
      },
      {
        "mastery_level": 4,
        "count": 20,
        "percentage": 0.133,
        "label": "熟练"
      },
      {
        "mastery_level": 5,
        "count": 5,
        "percentage": 0.033,
        "label": "精通"
      }
    ],
    "total_words": 150
  }
}
```

---


### 5.4 获取学习趋势

**接口**: `GET /stats/trend`  
**认证**: 需要 Bearer Token

**Query Params**:
- `period` (string, default: "week"): 时间周期 (`week`, `month`, `year`)
- `metric` (string, default: "reviews"): 指标类型 (`reviews`, `words_added`, `time_spent`, `accuracy`)

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "period": "week",
    "metric": "reviews",
    "data_points": [
      {
        "date": "2024-01-01",
        "value": 15,
        "label": "周一"
      },
      {
        "date": "2024-01-02",
        "value": 20,
        "label": "周二"
      },
      {
        "date": "2024-01-03",
        "value": 18,
        "label": "周三"
      },
      {
        "date": "2024-01-04",
        "value": 22,
        "label": "周四"
      },
      {
        "date": "2024-01-05",
        "value": 12,
        "label": "周五"
      }
    ],
    "summary": {
      "total": 87,
      "average": 17.4,
      "max": 22,
      "min": 12
    }
  }
}
```

---

### 5.5 获取学习热力图数据

**接口**: `GET /stats/heatmap`  
**认证**: 需要 Bearer Token

**Query Params**:
- `year` (int, optional): 年份，默认当前年份

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "year": 2024,
    "heatmap": [
      {
        "date": "2024-01-01",
        "count": 15,
        "level": 2
      },
      {
        "date": "2024-01-02",
        "count": 20,
        "level": 3
      },
      {
        "date": "2024-01-03",
        "count": 0,
        "level": 0
      }
    ],
    "total_days": 365,
    "active_days": 180,
    "longest_streak": 15,
    "current_streak": 7
  }
}
```

---

## 6. 插件同步模块 (Extension Sync)

### 6.1 插件认证（获取 API Token）

**接口**: `POST /extension/auth`  
**认证**: 需要 Bearer Token

**Request Body**:
```json
{
  "device_name": "Chrome Extension - MacBook Pro",
  "device_id": "unique_device_identifier"
}
```

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "api_token": "ext_xxxxxxxxxxxxxxxx",
    "expires_at": "2025-01-01T00:00:00Z",
    "device_id": "unique_device_identifier",
    "user_id": "uuid"
  },
  "message": "插件认证成功"
}
```

**说明**:
- API Token 用于插件后续请求
- Token 有效期为 1 年
- 使用 Header: `X-Extension-Token: ext_xxxxxxxxxxxxxxxx`

---

### 6.2 验证插件 Token

**接口**: `GET /extension/verify`  
**认证**: 需要 Extension Token (Header: `X-Extension-Token`)

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "valid": true,
    "user": {
      "id": "uuid",
      "username": "username",
      "email": "user@example.com"
    },
    "device_name": "Chrome Extension - MacBook Pro",
    "expires_at": "2025-01-01T00:00:00Z"
  }
}
```

**错误响应**:
- `401` - Token 无效或过期

---


### 6.3 插件批量同步单词

**接口**: `POST /extension/sync`  
**认证**: 需要 Extension Token (Header: `X-Extension-Token`)

**Request Body**:
```json
{
  "words": [
    {
      "word": "serendipity",
      "definition": "意外发现珍奇事物的能力",
      "source_url": "https://example.com/article",
      "context": "原文上下文片段...",
      "selected_text": "serendipity",
      "timestamp": "2024-01-05T10:30:00Z"
    },
    {
      "word": "ephemeral",
      "definition": "短暂的；瞬息的",
      "source_url": "https://example.com/blog",
      "context": "Life is ephemeral...",
      "selected_text": "ephemeral",
      "timestamp": "2024-01-05T10:35:00Z"
    }
  ],
  "auto_group": true,
  "default_group_id": "uuid"
}
```

**Response (201)**:
```json
{
  "success": true,
  "data": {
    "synced": 2,
    "skipped": 0,
    "failed": 0,
    "words": [
      {
        "id": "uuid1",
        "word": "serendipity",
        "status": "created"
      },
      {
        "id": "uuid2",
        "word": "ephemeral",
        "status": "created"
      }
    ]
  },
  "message": "同步完成"
}
```

---

### 6.4 插件心跳检测

**接口**: `POST /extension/heartbeat`  
**认证**: 需要 Extension Token (Header: `X-Extension-Token`)

**Request Body**:
```json
{
  "device_id": "unique_device_identifier",
  "version": "1.0.5",
  "last_sync_at": "2024-01-05T10:00:00Z"
}
```

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "server_time": "2024-01-05T10:30:00Z",
    "token_valid": true,
    "pending_updates": 0,
    "user_settings": {
      "auto_sync": true,
      "sync_interval_minutes": 5
    }
  }
}
```

---

### 6.5 获取插件配置

**接口**: `GET /extension/config`  
**认证**: 需要 Extension Token (Header: `X-Extension-Token`)

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "auto_sync": true,
    "sync_interval_minutes": 5,
    "default_group_id": "uuid",
    "auto_add_tags": ["from_extension"],
    "show_notifications": true,
    "capture_context": true,
    "context_length": 200
  }
}
```

---

### 6.6 更新插件配置

**接口**: `PATCH /extension/config`  
**认证**: 需要 Extension Token (Header: `X-Extension-Token`)

**Request Body**:
```json
{
  "auto_sync": false,
  "sync_interval_minutes": 10,
  "default_group_id": "uuid",
  "show_notifications": false
}
```

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "auto_sync": false,
    "sync_interval_minutes": 10,
    "default_group_id": "uuid",
    "show_notifications": false
  },
  "message": "配置更新成功"
}
```

---

### 6.7 撤销插件 Token

**接口**: `DELETE /extension/auth`  
**认证**: 需要 Extension Token (Header: `X-Extension-Token`)

**Response (200)**:
```json
{
  "success": true,
  "message": "Token 已撤销"
}
```

---


## 附录

### A. SM-2 算法说明

**SuperMemo 2 (SM-2) 间隔重复算法**用于计算下次复习时间：

**核心参数**:
- `EF` (Ease Factor): 难易度因子，初始值 2.5
- `I` (Interval): 复习间隔（天数）
- `n` (Repetition): 复习次数
- `q` (Quality): 用户评分 (0-5)

**算法逻辑**:
```
如果 q >= 3 (认识):
  如果 n = 0: I = 1
  如果 n = 1: I = 6
  如果 n > 1: I = I(n-1) × EF
  
  EF' = EF + (0.1 - (5 - q) × (0.08 + (5 - q) × 0.02))
  如果 EF' < 1.3: EF' = 1.3
  
  n = n + 1

如果 q < 3 (不认识):
  n = 0
  I = 1
  EF 保持不变
```

**Mastery Level 映射**:
- Level 0: 新单词 (n = 0)
- Level 1: 学习中 (n = 1-2)
- Level 2: 熟悉 (n = 3-5)
- Level 3: 掌握 (n = 6-10)
- Level 4: 熟练 (n = 11-20)
- Level 5: 精通 (n > 20)

---

### B. 数据库表结构建议

**核心表**:

1. **users** - 用户表
   - id (uuid, PK)
   - email (string, unique)
   - username (string)
   - avatar_url (string)
   - settings (jsonb)
   - created_at, updated_at

2. **words** - 单词表
   - id (uuid, PK)
   - user_id (uuid, FK)
   - word (string)
   - definition (text)
   - pronunciation (string)
   - example_sentence (text)
   - translation (text)
   - source_url (string)
   - group_id (uuid, FK, nullable)
   - created_at, updated_at

3. **review_stats** - 复习统计表
   - id (uuid, PK)
   - word_id (uuid, FK)
   - user_id (uuid, FK)
   - review_count (int)
   - mastery_level (int)
   - ease_factor (float)
   - interval_days (int)
   - next_review_at (timestamp)
   - last_reviewed_at (timestamp)
   - updated_at

4. **review_history** - 复习历史表
   - id (uuid, PK)
   - word_id (uuid, FK)
   - user_id (uuid, FK)
   - quality (int)
   - time_spent_seconds (int)
   - mastery_level_before (int)
   - mastery_level_after (int)
   - reviewed_at (timestamp)

5. **groups** - 分组表
   - id (uuid, PK)
   - user_id (uuid, FK)
   - name (string)
   - description (text)
   - color (string)
   - created_at, updated_at

6. **tags** - 标签表
   - id (uuid, PK)
   - user_id (uuid, FK)
   - name (string)
   - color (string)
   - created_at, updated_at

7. **word_tags** - 单词标签关联表
   - word_id (uuid, FK)
   - tag_id (uuid, FK)
   - created_at
   - PRIMARY KEY (word_id, tag_id)

8. **extension_tokens** - 插件 Token 表
   - id (uuid, PK)
   - user_id (uuid, FK)
   - token (string, unique)
   - device_name (string)
   - device_id (string)
   - expires_at (timestamp)
   - created_at

---


### C. 索引建议

**性能优化索引**:

```sql
-- 单词表
CREATE INDEX idx_words_user_id ON words(user_id);
CREATE INDEX idx_words_group_id ON words(group_id);
CREATE INDEX idx_words_word ON words(word);
CREATE INDEX idx_words_created_at ON words(created_at DESC);

-- 复习统计表
CREATE INDEX idx_review_stats_user_id ON review_stats(user_id);
CREATE INDEX idx_review_stats_word_id ON review_stats(word_id);
CREATE INDEX idx_review_stats_next_review ON review_stats(next_review_at);
CREATE INDEX idx_review_stats_mastery ON review_stats(mastery_level);

-- 复习历史表
CREATE INDEX idx_review_history_user_id ON review_history(user_id);
CREATE INDEX idx_review_history_word_id ON review_history(word_id);
CREATE INDEX idx_review_history_reviewed_at ON review_history(reviewed_at DESC);

-- 分组表
CREATE INDEX idx_groups_user_id ON groups(user_id);

-- 标签表
CREATE INDEX idx_tags_user_id ON tags(user_id);

-- 单词标签关联表
CREATE INDEX idx_word_tags_tag_id ON word_tags(tag_id);

-- 插件 Token 表
CREATE INDEX idx_extension_tokens_user_id ON extension_tokens(user_id);
CREATE INDEX idx_extension_tokens_token ON extension_tokens(token);
CREATE INDEX idx_extension_tokens_expires_at ON extension_tokens(expires_at);
```

---

### D. API 最佳实践

**1. 分页查询**
- 默认每页 20 条，最大 100 条
- 使用 `page` 和 `limit` 参数
- 返回 `pagination` 对象包含总数和总页数

**2. 错误处理**
- 统一错误响应格式
- 使用标准 HTTP 状态码
- 提供清晰的错误信息和错误码

**3. 认证安全**
- JWT Token 有效期 1 小时
- Refresh Token 有效期 30 天
- 插件 Token 有效期 1 年
- 敏感操作需要二次验证

**4. 性能优化**
- 使用数据库索引
- 实现查询结果缓存（Redis）
- 批量操作优于循环单次操作
- 分页加载大数据集

**5. 数据验证**
- 前端和后端双重验证
- 使用 Zod 或 Yup 进行 schema 验证
- 防止 SQL 注入和 XSS 攻击

**6. 限流策略**
- 普通接口：100 次/分钟
- 批量接口：20 次/分钟
- 搜索接口：30 次/分钟
- 使用 IP + User ID 组合限流

---


### E. Next.js 14 App Router 实现建议

**目录结构**:
```
app/
├── api/
│   └── v1/
│       ├── auth/
│       │   ├── register/route.ts
│       │   ├── login/route.ts
│       │   ├── logout/route.ts
│       │   ├── refresh/route.ts
│       │   ├── me/route.ts
│       │   └── oauth/[provider]/route.ts
│       ├── words/
│       │   ├── route.ts
│       │   ├── [id]/route.ts
│       │   ├── batch/route.ts
│       │   └── search/route.ts
│       ├── groups/
│       │   ├── route.ts
│       │   └── [id]/route.ts
│       ├── tags/
│       │   ├── route.ts
│       │   └── [id]/route.ts
│       ├── review/
│       │   ├── due/route.ts
│       │   ├── submit/route.ts
│       │   ├── submit-batch/route.ts
│       │   ├── history/route.ts
│       │   └── overview/route.ts
│       ├── stats/
│       │   ├── daily/route.ts
│       │   ├── total/route.ts
│       │   ├── mastery-distribution/route.ts
│       │   ├── trend/route.ts
│       │   └── heatmap/route.ts
│       └── extension/
│           ├── auth/route.ts
│           ├── verify/route.ts
│           ├── sync/route.ts
│           ├── heartbeat/route.ts
│           └── config/route.ts
├── lib/
│   ├── supabase/
│   │   ├── client.ts
│   │   └── server.ts
│   ├── auth/
│   │   └── middleware.ts
│   ├── algorithms/
│   │   └── sm2.ts
│   └── utils/
│       ├── response.ts
│       └── validation.ts
└── middleware.ts
```

**中间件示例** (`middleware.ts`):
```typescript
import { createMiddlewareClient } from '@supabase/auth-helpers-nextjs'
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export async function middleware(req: NextRequest) {
  const res = NextResponse.next()
  const supabase = createMiddlewareClient({ req, res })
  
  // 刷新 session
  await supabase.auth.getSession()
  
  return res
}

export const config = {
  matcher: ['/api/v1/:path*']
}
```

**认证工具函数** (`lib/auth/middleware.ts`):
```typescript
import { createRouteHandlerClient } from '@supabase/auth-helpers-nextjs'
import { cookies } from 'next/headers'
import { NextResponse } from 'next/server'

export async function requireAuth() {
  const supabase = createRouteHandlerClient({ cookies })
  const { data: { session } } = await supabase.auth.getSession()
  
  if (!session) {
    return NextResponse.json(
      { success: false, error: { code: 'UNAUTHORIZED', message: '未认证' } },
      { status: 401 }
    )
  }
  
  return { session, user: session.user }
}
```

**SM-2 算法实现** (`lib/algorithms/sm2.ts`):
```typescript
export interface SM2Result {
  interval: number
  repetition: number
  easeFactor: number
  nextReviewAt: Date
}

export function calculateSM2(
  quality: number,
  repetition: number,
  easeFactor: number,
  interval: number
): SM2Result {
  let newEF = easeFactor
  let newInterval = interval
  let newRepetition = repetition

  if (quality >= 3) {
    if (newRepetition === 0) {
      newInterval = 1
    } else if (newRepetition === 1) {
      newInterval = 6
    } else {
      newInterval = Math.round(interval * easeFactor)
    }

    newEF = easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02))
    if (newEF < 1.3) newEF = 1.3

    newRepetition += 1
  } else {
    newRepetition = 0
    newInterval = 1
  }

  const nextReviewAt = new Date()
  nextReviewAt.setDate(nextReviewAt.getDate() + newInterval)

  return {
    interval: newInterval,
    repetition: newRepetition,
    easeFactor: Number(newEF.toFixed(2)),
    nextReviewAt
  }
}

export function getMasteryLevel(repetition: number): number {
  if (repetition === 0) return 0
  if (repetition <= 2) return 1
  if (repetition <= 5) return 2
  if (repetition <= 10) return 3
  if (repetition <= 20) return 4
  return 5
}
```

---


### F. Supabase 配置建议

**Row Level Security (RLS) 策略**:

```sql
-- 启用 RLS
ALTER TABLE words ENABLE ROW LEVEL SECURITY;
ALTER TABLE review_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE review_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags ENABLE ROW LEVEL SECURITY;

-- 单词表策略
CREATE POLICY "用户只能查看自己的单词"
  ON words FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "用户只能创建自己的单词"
  ON words FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "用户只能更新自己的单词"
  ON words FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "用户只能删除自己的单词"
  ON words FOR DELETE
  USING (auth.uid() = user_id);

-- 复习统计表策略（类似）
CREATE POLICY "用户只能查看自己的复习统计"
  ON review_stats FOR SELECT
  USING (auth.uid() = user_id);

-- 其他表类似配置...
```

**实时订阅配置**:
```typescript
// 监听单词变化
const subscription = supabase
  .channel('words_changes')
  .on(
    'postgres_changes',
    {
      event: '*',
      schema: 'public',
      table: 'words',
      filter: `user_id=eq.${userId}`
    },
    (payload) => {
      console.log('Word changed:', payload)
    }
  )
  .subscribe()
```

---

### G. 浏览器插件集成建议

**Chrome Extension Manifest V3**:
```json
{
  "manifest_version": 3,
  "name": "单词本助手",
  "version": "1.0.0",
  "permissions": [
    "storage",
    "activeTab",
    "contextMenus"
  ],
  "host_permissions": [
    "https://your-api.com/*"
  ],
  "background": {
    "service_worker": "background.js"
  },
  "content_scripts": [
    {
      "matches": ["<all_urls>"],
      "js": ["content.js"]
    }
  ]
}
```

**插件核心功能**:
1. 划词翻译 + 添加单词
2. 右键菜单快速添加
3. 自动同步到服务器
4. 离线缓存支持
5. 每日复习提醒

---


## 总结

本 API 文档涵盖了单词本网站的完整功能模块：

### 核心功能模块
1. **认证模块** - 7 个接口，支持邮箱登录和第三方 OAuth
2. **单词模块** - 8 个接口，支持 CRUD、搜索、批量操作
3. **分组/标签模块** - 11 个接口，灵活的分类管理
4. **复习模块** - 5 个接口，基于 SM-2 算法的智能复习
5. **统计模块** - 5 个接口，全面的学习数据分析
6. **插件同步模块** - 7 个接口，浏览器插件无缝集成

### 技术特点
- ✅ RESTful 设计规范
- ✅ JWT + Supabase Auth 认证
- ✅ SM-2 间隔重复算法
- ✅ PostgreSQL + RLS 数据安全
- ✅ Next.js 14 App Router 原生支持
- ✅ 浏览器插件友好的 API 设计

### 接口统计
- **总接口数**: 43 个
- **需要认证**: 36 个
- **公开接口**: 7 个（认证相关）
- **批量操作**: 4 个

---

## 版本历史

### v1.0 (2024-01-05)
- ✅ 初始版本发布
- ✅ 完整的 6 大功能模块
- ✅ SM-2 算法支持
- ✅ 浏览器插件集成

---

## 联系方式

如有问题或建议，请联系：
- 📧 Email: api@example.com
- 📚 文档: https://docs.example.com
- 🐛 Issues: https://github.com/example/vocabulary-api/issues

---

**文档生成时间**: 2024-01-05  
**API 版本**: v1.0  
**文档版本**: 1.0.0

