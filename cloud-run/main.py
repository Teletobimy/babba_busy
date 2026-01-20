from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import time

from config import get_settings
from routers import summary_router, business_router, psychology_router

settings = get_settings()

# FastAPI 앱 생성
app = FastAPI(
    title="BABBA AI API",
    description="BABBA 앱의 AI 기능을 제공하는 API 서버",
    version="1.0.0",
    docs_url="/docs" if settings.debug else None,
    redoc_url="/redoc" if settings.debug else None,
)

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://***REMOVED_WEB_DOMAIN***",
        "https://***REMOVED_AUTH_DOMAIN***",
        "http://localhost:*",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# 요청 로깅 미들웨어
@app.middleware("http")
async def log_requests(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    process_time = time.time() - start_time

    print(
        f"{request.method} {request.url.path} "
        f"- Status: {response.status_code} "
        f"- Time: {process_time:.3f}s"
    )

    return response


# 전역 예외 핸들러
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    print(f"Unhandled error: {exc}")
    return JSONResponse(
        status_code=500,
        content={
            "success": False,
            "error": "Internal Server Error",
            "detail": str(exc) if settings.debug else None,
        },
    )


# 라우터 등록
app.include_router(summary_router)
app.include_router(business_router)
app.include_router(psychology_router)


# 헬스체크
@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "environment": settings.environment,
        "version": "1.0.0",
    }


# 루트
@app.get("/")
async def root():
    return {
        "message": "BABBA AI API",
        "docs": "/docs" if settings.debug else "Disabled in production",
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8080,
        reload=settings.debug,
    )
