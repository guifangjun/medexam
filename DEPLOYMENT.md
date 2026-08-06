# MedExam 公网部署说明

## 1. 部署后端 API

后端位于 `backend/`，已经提供 Dockerfile，可部署到 Render、Railway、Fly.io 等支持 Docker 的平台。

Render 可直接识别仓库根目录的 `render.yaml`：

- 服务名：`medexam-api`
- 健康检查：`/api/health`
- 默认端口：平台注入的 `PORT`
- 默认数据库：SQLite `sqlite+aiosqlite:///./medexam.db`

演示环境可以直接使用 SQLite。正式运营建议改为 PostgreSQL，并把 `DATABASE_URL` 配成平台提供的 PostgreSQL 连接串。

后端部署成功后，记录公网 API 地址，例如：

```text
https://medexam-api.onrender.com
```

## 2. 构建前端 Web

拿到后端公网 API 地址后，在项目根目录执行：

```bash
./scripts/build_web_public.sh https://medexam-api.onrender.com
```

构建产物会生成在：

```text
app/build/web
```

## 3. 部署前端静态站

将 `app/build/web` 作为静态网站部署目录，部署到 Sites、Cloudflare Pages、Vercel、Netlify 等平台均可。

需要注意：前端必须使用第 2 步带公网 API 地址重新构建，否则公网访问时会继续请求本机 `127.0.0.1:8000`。

## 4. 验证

部署完成后检查：

- 打开前端公网链接，页面能正常加载
- 使用演示账号登录：`13800000000 / demo123`
- 后台地址：`/#/admin`
- 后台演示账号：`admin / admin123`
