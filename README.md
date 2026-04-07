# MedExam AI - 医考学习 APP

基于 AI 的国内执业医师/助理医师考试学习平台

## 项目结构

```
medexam/
├── backend/              # 后端服务 (FastAPI)
│   ├── app/
│   │   ├── api/         # API 路由
│   │   │   ├── deps.py         # 认证依赖
│   │   │   ├── questions.py    # 题库接口
│   │   │   ├── ai_chat.py      # AI 答疑接口
│   │   │   └── study.py        # 学习计划接口
│   │   ├── core/        # 核心配置
│   │   │   ├── config.py        # 应用配置
│   │   │   └── database.py      # 数据库连接
│   │   ├── models/      # 数据模型
│   │   │   ├── user.py          # 用户模型
│   │   │   ├── question.py       # 题目模型
│   │   │   ├── study.py          # 学习计划模型
│   │   │   └── conversation.py   # 对话模型
│   │   ├── schemas/     # Pydantic schemas
│   │   └── main.py      # 应用入口
│   └── requirements.txt
│
└── app/                  # Flutter APP
    ├── lib/
    │   ├── core/
    │   │   ├── constants/    # 常量配置
    │   │   └── theme/         # 主题配置
    │   ├── data/
    │   │   ├── models/         # 数据模型
    │   │   ├── providers/      # 状态管理
    │   │   └── services/       # API 服务
    │   └── presentation/
    │       ├── screens/        # 页面
    │       │   ├── home/       # 首页
    │       │   ├── auth/       # 登录注册
    │       │   ├── practice/   # 章节练习
    │       │   ├── exam/       # 模拟考试
    │       │   ├── ai_chat/    # AI 答疑
    │       │   ├── study/      # 学习计划
    │       │   ├── wrong/      # 错题本
    │       │   └── stats/      # 数据统计
    │       └── widgets/       # 通用组件
    └── pubspec.yaml
```

## 技术栈

### 后端
- **框架**: FastAPI (Python)
- **数据库**: PostgreSQL + Redis
- **AI**: 国产大模型 (智谱 GLM / 通义 Qwen / 文心 ERNIE)
- **认证**: JWT

### 前端
- **框架**: Flutter
- **状态管理**: Provider
- **图表**: fl_chart
- **网络**: Dio

## 功能模块

### 1. 题库模块
- 章节练习
- 历年真题
- AI 生成练习题
- 模拟考试

### 2. AI 答疑 (核心)
- 自然语言问答
- 追问机制
- 题目答疑
- 知识拓展

### 3. 学习计划
- 个性化计划
- 艾宾浩斯复习
- 每日任务推送

### 4. 错题本
- 错因分类
- 薄弱点分析
- 针对性复习

### 5. 数据统计
- 总体概况
- 科目分析
- 学习时长统计

## 快速开始

### 后端

```bash
cd backend
pip install -r requirements.txt

# 配置环境变量
export DATABASE_URL=postgresql+asyncpg://user:pass@localhost:5432/medexam
export AI_API_KEY=your-api-key

# 运行服务
uvicorn app.main:app --reload --port 8000
```

### Flutter APP

```bash
cd app
flutter pub get
flutter run
```

#### 固定端口运行（推荐）

```bash
cd app
flutter run -d chrome --web-port 51739
```

端口固定为 51739，浏览器访问 http://localhost:51739

## 配置 AI 模型

在 `backend/.env` 中配置：

```env
# 智谱 GLM
AI_API_KEY=your-zhipu-api-key
AI_BASE_URL=https://open.bigmodel.cn/api/paas/v4
AI_MODEL=glm-4

# 或 通义 Qwen
AI_API_KEY=your-dashscope-api-key
AI_BASE_URL=https://dashscope.aliyuncs.com/api/v1
AI_MODEL=qwen-turbo
```

## 考试大纲

覆盖执业医师考试全部科目：
- 基础医学
- 临床医学
- 内科学
- 外科学
- 妇产科学
- 儿科学
- 预防医学

## License

MIT
