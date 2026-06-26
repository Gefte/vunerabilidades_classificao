"""Implementação de modelo local usando Ollama."""

from __future__ import annotations

import os
from typing import Any, Dict

import litellm

from .base_model import BaseModel


class LocalModel(BaseModel):
    """Modelo para execução local via Ollama."""

    def setup_model(self) -> None:
        self.api_base = self.config.get("base_url", "http://localhost:11434")
        self.healthcheck_enabled: bool = bool(self.config.get("healthcheck", True))
        self.extra_params: Dict[str, Any] = self.config.get("extra_params", {})

        os.environ.setdefault("OLLAMA_API_BASE", self.api_base)
        self.logger.info(
            "Modelo local configurado: model=%s, endpoint=%s",
            self.model_name,
            self.api_base,
        )

    def send_prompt(self, prompt: str, **kwargs: Any) -> str:
        mode = kwargs.get("mode", "default")

        try:
            self._apply_rate_limit(kwargs.get("rate_limit", 0.5))
            input_tokens = self.count_tokens(prompt)

            response = litellm.completion(
                model=self._build_model_identifier(),
                messages=kwargs.get("messages", [{"role": "user", "content": prompt}]),
                api_base=self.api_base,
                temperature=kwargs.get("temperature", self.temperature),
                max_tokens=kwargs.get("max_tokens", self.max_tokens),
                **self._merge_params(kwargs),
            )

            content = self._extract_content(response)
            output_tokens = self.count_tokens(content)
            self._log_interaction(prompt, content, input_tokens, output_tokens, mode, kwargs.get('incident_id'))
            return content
        except Exception as exc:
            self.logger.error("Falha ao chamar modelo local: %s", exc)
            return f"Erro ao executar modelo local: {exc}"

    def _merge_params(self, kwargs: Dict[str, Any]) -> Dict[str, Any]:
        merged = dict(self.extra_params)
        merged.update({k: v for k, v in kwargs.items() if k not in ["mode", "messages"]})
        return merged

    def _build_model_identifier(self) -> str:
        return f"ollama/{self.model_name}"

    def _extract_content(self, response: Any) -> str:
        try:
            message = response.choices[0].message
            if isinstance(message, dict):
                return message.get("content", "") or ""
            return getattr(message, "content", "") or ""
        except Exception:
            return getattr(response, "content", "") or ""

    def health_check(self) -> bool:
        if not self.healthcheck_enabled:
            return True

        try:
            import requests

            resp = requests.get(f"{self.api_base}/api/version", timeout=5)
            return resp.status_code == 200
        except Exception as exc:
            self.logger.warning("Verificação de saúde do Ollama falhou: %s", exc)
            return False
