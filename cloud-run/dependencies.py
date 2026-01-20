from fastapi import Header, HTTPException
from typing import Optional

from services import FirebaseAuth


async def get_current_user(
    authorization: Optional[str] = Header(None),
) -> dict:
    """Firebase ID 토큰에서 현재 사용자 정보 추출"""
    if not authorization:
        raise HTTPException(
            status_code=401,
            detail="인증이 필요합니다.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Bearer 토큰 추출
    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(
            status_code=401,
            detail="잘못된 인증 형식입니다.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = parts[1]

    # 토큰 검증
    user = await FirebaseAuth.verify_token(token)
    if not user:
        raise HTTPException(
            status_code=401,
            detail="유효하지 않은 토큰입니다.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return user


async def get_optional_user(
    authorization: Optional[str] = Header(None),
) -> Optional[dict]:
    """선택적 인증 (인증 없어도 진행 가능)"""
    if not authorization:
        return None

    try:
        return await get_current_user(authorization)
    except HTTPException:
        return None
