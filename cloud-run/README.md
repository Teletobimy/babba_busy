# BABBA AI API (Cloud Run)

BABBA 앱의 AI 기능을 제공하는 FastAPI 서버입니다.

## 기능

- **일일/주간 요약**: Gemini AI를 사용한 활동 요약 생성
- **사업 검토**: AI 기반 사업 아이디어 분석 및 대화형 컨설팅
- **심리검사**: 스트레스, 자존감 등 심리검사 및 AI 분석

## 로컬 개발

```bash
# 가상환경 생성
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# 의존성 설치
pip install -r requirements.txt

# 환경변수 설정
cp .env.example .env
# .env 파일에서 GEMINI_API_KEY 설정

# 서버 실행
uvicorn main:app --reload --port 8080
```

## API 문서

로컬 개발 시 http://localhost:8080/docs 에서 Swagger UI 확인 가능

## 배포

Cloud Build를 통해 자동 배포:

```bash
gcloud builds submit --config cloudbuild.yaml
```

## 환경변수

| 변수명 | 설명 | 기본값 |
|--------|------|--------|
| `ENVIRONMENT` | 환경 (development/production) | development |
| `DEBUG` | 디버그 모드 | false |
| `GCP_PROJECT_ID` | GCP 프로젝트 ID | ***REMOVED_PROJECT_ID*** |
| `GEMINI_API_KEY` | Gemini API 키 | (필수) |
| `GEMINI_MODEL` | Gemini 모델 이름 | gemini-2.5-flash-lite-preview-09-2025 |
