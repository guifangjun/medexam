from contextlib import asynccontextmanager

from fastapi import FastAPI, Response
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.core.init_db import init_database
from app.api import deps
from app.api import admin, questions, ai_chat, study


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_database()
    yield


app = FastAPI(title=settings.APP_NAME, version="1.0.0", lifespan=lifespan)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 注册路由
app.include_router(deps.router)
app.include_router(admin.router)
app.include_router(questions.router)
app.include_router(ai_chat.router)
app.include_router(study.router)


@app.get("/")
async def root():
    return {"message": "MedExam AI 医考学习平台 API", "version": "1.0.0"}


@app.get("/favicon.ico", include_in_schema=False)
async def favicon():
    return Response(status_code=204)


@app.get("/health")
async def health():
    return {"status": "healthy"}
