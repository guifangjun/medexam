# MedExam AI 医考培训系统

MedExam AI 是一款医考培训产品，包含学员端、独立管理后台和 FastAPI 后端。当前版本聚焦医考学习闭环：考试分类切换、题库练习、错题复习、课程学习、学习计划、AI 答疑，以及后台题库/课程/用户/数据看板运营管理。

## 功能概览

### 学员端

- 手机号注册与登录：支持手机号 + 密码、手机号 + 验证码登录。
- 首页学习闭环：今日学习任务、今日数据、推荐下一步、一键开始今日任务、继续学习。
- 考试分类：执业资格、初级职称、中级职称、高级职称。
- 专项练习：章节练习、未做题、错题复习、高频考点、随机练习。
- 模拟考试：按当前考试分类抽取真题/模考题。
- 课程学习：直播课、录播课，课程可关联章节题库并进入课后练习。
- 学习中心：学习计划、今日任务、错题复习、今日统计。
- 错题本：错题详情、答案解析、复习次数、掌握状态。
- AI 答疑：医学考试学习问答、会话历史。

### 管理后台

- 独立后台账号体系，和学员账号/token 分离。
- 题库管理：按考试分类/章节筛选，新增、编辑、删除题目。
- 课程管理：新增、编辑、删除课程，绑定章节题库，控制发布状态。
- 用户管理：用户增删改查、搜索、考试分类筛选、启用/停用。
- 数据看板：用户总数、今日活跃、今日做题、正确率、错题复习、课程数、考试分类分布、章节练习热度。

## 技术栈

- 前端：Flutter Web、Provider、Dio、flutter_secure_storage、fl_chart
- 后端：FastAPI、SQLAlchemy Async、SQLite、JWT、Passlib
- 本地服务：FastAPI `127.0.0.1:8000`，Flutter 静态 Web `127.0.0.1:5275`

## 项目结构

```text
medexam/
├── app/                         # Flutter 学员端与管理后台
│   ├── lib/
│   │   ├── core/                # 常量、主题、全局消息
│   │   ├── data/                # models/providers/services
│   │   └── presentation/
│   │       ├── screens/         # home/practice/course/exam/study/admin 等页面
│   │       └── widgets/         # 通用 UI 组件
│   └── pubspec.yaml
├── backend/                     # FastAPI 后端
│   ├── app/
│   │   ├── api/                 # auth/questions/study/ai/admin
│   │   ├── core/                # 配置、数据库、初始化、种子数据
│   │   ├── models/              # SQLAlchemy 模型
│   │   └── schemas/             # Pydantic schema
│   ├── tests/                   # 后端接口流测试
│   └── requirements.txt
└── scripts/
    ├── start_local.sh           # 一键启动
    └── serve_web.py             # 本地 Flutter Web 静态服务
```

## 本地启动

推荐直接使用一键启动脚本：

```bash
cd /Users/ahuai/Documents/medexam
./scripts/start_local.sh
```

脚本会清理本机 `8000` 和 `5275` 端口，启动 FastAPI，构建 Flutter Web，并启动本地静态服务。

访问地址：

```text
学员端：http://127.0.0.1:5275/
管理后台：http://127.0.0.1:5275/#/admin
后端 API：http://127.0.0.1:8000
```

## 默认账号

学员端演示账号：

```text
手机号：13800000000
密码：demo123
```

管理后台演示账号：

```text
账号：admin
密码：admin123
```

本地演示环境的短信验证码会直接返回给前端使用；接真实短信网关前不要用于生产。

## 常用命令

后端测试：

```bash
cd /Users/ahuai/Documents/medexam/backend
python3 -B -m unittest discover -s tests -v
```

Flutter 静态检查：

```bash
cd /Users/ahuai/Documents/medexam/app
/Users/ahuai/development/flutter/bin/flutter analyze
```

只查看 Flutter 编译级错误：

```bash
cd /Users/ahuai/Documents/medexam/app
/Users/ahuai/development/flutter/bin/flutter analyze 2>&1 | rg "error •"
```

格式化 Flutter 代码：

```bash
cd /Users/ahuai/Documents/medexam
/Users/ahuai/development/flutter/bin/dart format app/lib
```

手动启动后端：

```bash
cd /Users/ahuai/Documents/medexam/backend
python3 -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

手动构建并预览前端：

```bash
cd /Users/ahuai/Documents/medexam/app
/Users/ahuai/development/flutter/bin/flutter build web
python3 ../scripts/serve_web.py --directory build/web --host 127.0.0.1 --port 5275
```

## 主要 API

### 学员认证

- `POST /api/auth/sms-code`
- `POST /api/auth/register`
- `POST /api/auth/login`
- `POST /api/auth/login/sms`
- `GET /api/auth/me`

### 题库

- `GET /api/questions/chapters`
- `GET /api/questions/practice`
  - 支持 `mode=chapter|unanswered|wrong|tag|random`
- `GET /api/questions/exam`
- `POST /api/questions/submit`
- `POST /api/questions/exam/submit`

### 学习

- `POST /api/study/plan`
- `GET /api/study/plan`
- `GET /api/study/today`
- `GET /api/study/wrong`
- `POST /api/study/wrong/{wrong_id}/review`
- `GET /api/study/stats/today`
- `GET /api/study/stats/overview`

### 管理后台

- `POST /api/admin/auth/login`
- `GET /api/admin/auth/me`
- `GET /api/admin/dashboard`
- `GET|POST /api/admin/questions`
- `PUT|DELETE /api/admin/questions/{question_id}`
- `GET|POST /api/admin/courses`
- `PUT|DELETE /api/admin/courses/{course_id}`
- `GET|POST /api/admin/users`
- `PUT|DELETE /api/admin/users/{user_id}`

## 数据与配置

后端默认使用本地 SQLite：

```env
DATABASE_URL=sqlite+aiosqlite:///./medexam.db
SECRET_KEY=your-secret-key-change-in-production
AI_API_KEY=your-api-key
AI_BASE_URL=https://api.example.com/v1
AI_MODEL=Qwen/Qwen2.5-7B-Instruct
```

本地数据库、备份、环境变量和构建产物不提交到 Git：

- `backend/medexam.db`
- `backend/backups/`
- `backend/.env`
- `app/build/`
- `app/.dart_tool/`

## 注意事项

- 管理后台和学员端是两套账号体系。
- 客户端切换考试分类后，题库和课程内容应同步切换。
- 课程 v1 采用单章节绑定：`course.chapter_id`。
- 后台用户管理不展示/编辑每日目标。
- Flutter analyze 当前可能存在历史 info/warning，验收重点看是否有 `error •`。

## License

MIT
