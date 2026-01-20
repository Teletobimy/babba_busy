import google.generativeai as genai
from abc import ABC, abstractmethod
from typing import Any, Optional
from config import get_settings

settings = get_settings()
genai.configure(api_key=settings.gemini_api_key)


class BaseAgent(ABC):
    """에이전트 베이스 클래스"""

    def __init__(self, model_type: str = "agent"):
        """
        model_type: "pm" | "agent" | "lite"
        """
        if model_type == "pm":
            model_name = settings.gemini_pm_model
        elif model_type == "lite":
            model_name = settings.gemini_lite_model
        else:
            model_name = settings.gemini_agent_model

        self.model = genai.GenerativeModel(model_name)
        self.model_name = model_name

    @abstractmethod
    async def run(self, *args, **kwargs) -> Any:
        """에이전트 실행"""
        pass

    async def _generate(self, prompt: str) -> str:
        """프롬프트로 텍스트 생성"""
        try:
            response = await self.model.generate_content_async(prompt)
            return response.text.strip()
        except Exception as e:
            print(f"[{self.__class__.__name__}] Generation error: {e}")
            raise

    async def _generate_json(self, prompt: str) -> dict:
        """프롬프트로 JSON 생성"""
        import json
        try:
            response = await self.model.generate_content_async(prompt)
            text = response.text.strip()
            # ```json ... ``` 형식 처리
            if text.startswith("```"):
                text = text.split("```")[1]
                if text.startswith("json"):
                    text = text[4:]
            return json.loads(text)
        except json.JSONDecodeError as e:
            print(f"[{self.__class__.__name__}] JSON parse error: {e}")
            print(f"Raw response: {response.text[:500]}")
            raise
        except Exception as e:
            print(f"[{self.__class__.__name__}] Generation error: {e}")
            raise
