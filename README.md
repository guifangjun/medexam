# MedExam AI

面向卫生类考试用户的 AI 医考学习平台，覆盖卫生执业资格类考试、卫生初级/中级/高级职称考试。项目包含学员端 Flutter Web/App、FastAPI 后端，以及独立的 Web 管理后台。

## 功能概览

### 学员端

- 多考试目标：执业资格、初级职称、中级职称、高级职称
- 首页学习看板：今日任务、学习数据、考试目标切换
- 刷题模块：章节刷题、题目解析、错题记录
- 模考模块：按当前考试目标生成限时模考
- 视频课程：直播课、录播课
- 学习计划：创建计划后自动关联今日任务
- 错题本：错题复习、掌握状态、复习次数
- 数据统计：今日数据、总体学习概况、薄弱科目
- AI 答疑：自然语言问答、题目相关追问

### 管理后台

- 独立后台登录体系
- 题库管理：题目列表、搜索、新增、编辑、删除
- 课程管理：直播课/录播课新增、编辑、删除
- 后台接口鉴权：`/api/admin/*` 需要后台 token

## 技术栈

### 前端

- Flutter
- Provider
- Dio
- fl_chart
- flutter_secure_storage

### 后端

- FastAPI
- SQLAlchemy Async
- SQLite 本地开发默认库
- JWT 认证
- 可配置国产大模型接口

## 项目结构

```text
medexam/
├── app/                         # Flutter 学员端与管理后台
│   ├── lib/
│   │   ├── core/                # 常量、主题、全局消息
│   │   ├── data/                # models/providers/services
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── admin/       # Web 管理后台
│   │       │   ├── auth/        # 学员端登录注册
│   │       │   ├── course/      # 视频课程
│   │       │   ├── exam/        # 模考
│   │       │   ├── home/        # 首页
│   │       │   ├── practice/    # 刷题
│   │       │   ├── stats/       # 数据统计
│   │       │   ├── study/       # 学习计划
│   │       │   ├── syllabus/    # 考试大纲
│   │       │   └── wrong/       # 错题本
│   │       └── widgets/         # 通用液态玻璃组件
│   └── pubspec.yaml
│
└── backend/                     # FastAPI 后端
    ├── app/
    │   ├── api/                 # auth/questions/study/ai/admin
    │   ├── core/                # 配置、数据库、初始化
    │   ├── models/              # SQLAlchemy 模型
    │   └── schemas/             # Pydantic schema
    ├── requirements.txt
    └── medexam.db               # 本地 SQLite 数据库
```

## 本地启动

### 1. 启动后端

```bash
cd backend
pip install -r requirements.txt
python3 -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

后端默认地址：

```text
http://127.0.0.1:8000
```

健康检查：

```bash
curl http://127.0.0.1:8000/health
```

### 2. 启动 Flutter Web

```bash
cd app
flutter pub get
flutter run -d chrome --web-port 5275
```

如果使用静态构建预览：

```bash
cd app
flutter build web
cd build/web
python3 -m http.server 5275 --bind 127.0.0.1
```

### 3. 访问地址

学员端：

```text
http://127.0.0.1:5275/
```

管理后台：

```text
http://127.0.0.1:5275/#/admin
```

## 默认账号

### 学员端演示账号

```text
用户名：demo
密码：demo123
```

### 管理后台演示账号

```text
用户名：admin
密码：admin123
```

注意：默认演示账号仅用于本地开发和预览。正式环境应改为环境变量初始化管理员账号，或关闭默认账号创建逻辑。

## API 模块

### 学员认证

- `POST /api/auth/register`
- `POST /api/auth/login`
- `GET /api/auth/me`

### 题库

- `GET /api/questions/chapters`
- `GET /api/questions/practice`
- `GET /api/questions/exam`
- `POST /api/questions/submit`

### 学习

- `POST /api/study/plan`
- `GET /api/study/plan`
- `GET /api/study/today`
- `GET /api/study/wrong`
- `GET /api/study/stats/today`
- `GET /api/study/stats/overview`

### AI 答疑

- `POST /api/ai/chat`
- `GET /api/ai/history`
- `GET /api/ai/sessions`

### 管理后台

- `POST /api/admin/auth/login`
- `GET /api/admin/auth/me`
- `GET /api/admin/questions`
- `POST /api/admin/questions`
- `PUT /api/admin/questions/{question_id}`
- `DELETE /api/admin/questions/{question_id}`
- `GET /api/admin/courses`
- `POST /api/admin/courses`
- `PUT /api/admin/courses/{course_id}`
- `DELETE /api/admin/courses/{course_id}`

## 环境配置

后端配置位于 `backend/.env`，默认使用本地 SQLite：

```env
DATABASE_URL=sqlite+aiosqlite:///./medexam.db
SECRET_KEY=your-secret-key-change-in-production
AI_API_KEY=your-api-key
AI_BASE_URL=https://api.example.com/v1
AI_MODEL=Qwen/Qwen2.5-7B-Instruct
```

## 常用命令

格式化 Flutter 代码：

```bash
cd app
dart format lib
```

构建 Web：

```bash
cd app
flutter build web
```

Python 语法检查：

```bash
PYTHONPYCACHEPREFIX=/private/tmp/medexam_pycache \
python3 -m py_compile backend/app/api/*.py backend/app/schemas/*.py
```

## 设计风格

当前 UI 使用浅色液态玻璃风格，主色为深海蓝，强调简洁、清晰、适合医疗考试学习场景。学员端和登录页保持统一视觉；管理后台为独立系统，但沿用相同品牌色和组件风格。

## 注意事项

- 管理后台和学员端是两套账号体系，token 分开存储。
- 本地默认数据库文件为 `backend/medexam.db`。
- 当前课程管理后台已支持数据写入，但学员端课程页仍以演示课程数据为主，后续可改为读取 `/api/admin/courses` 的已发布课程。
- `.DS_Store` 不应提交到仓库，建议加入 `.gitignore`。

## License

MIT
