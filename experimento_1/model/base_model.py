"""Classe base para modelos do framework."""

from __future__ import annotations

import time
from abc import ABC, abstractmethod
from typing import Any, Dict, Optional

import tiktoken

from core.observability.logger import setup_logger
from core.observability.metrics import TokenMetrics


class BaseModel(ABC):
    """Classe base com funcionalidades compartilhadas entre modelos."""

    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.logger = setup_logger(self.__class__.__name__)
        self.token_metrics = TokenMetrics()
        self.provider: str = config.get("provider", "unknown")
        self.model_name: str = config.get("model") or config.get("name", "")
        self.temperature: float = float(config.get("temperature", 0.7))
        self.max_tokens: int = int(config.get("max_tokens", 2048))
        self.rate_limit: float = float(config.get("rate_limit", 0.0))
        self._encoding_name: Optional[str] = config.get("encoding")
        self.setup_model()

    @abstractmethod
    def setup_model(self) -> None:
        """Configura dados específicos do modelo."""

    @abstractmethod
    def send_prompt(self, prompt: str, **kwargs: Any) -> str:
        """Envia um prompt e retorna a resposta do modelo."""

    def get_name(self) -> str:
        """Retorna o identificador do modelo utilizado."""
        return self.model_name or self.config.get("name", self.__class__.__name__)

    def count_tokens(self, text: str) -> int:
        """Conta tokens usando tiktoken com fallback seguro."""
        if not text:
            return 0

        if self._encoding_name:
            try:
                encoding = tiktoken.get_encoding(self._encoding_name)
                return len(encoding.encode(text))
            except Exception:
                self.logger.debug("Falha ao usar encoding %s, usando fallback", self._encoding_name)

        try:
            encoding = tiktoken.encoding_for_model(self.get_name())
        except Exception:
            encoding = tiktoken.get_encoding("cl100k_base")

        return len(encoding.encode(text))

    def _log_interaction(
        self,
        prompt: str,
        response: str,
        input_tokens: int,
        output_tokens: int,
        mode: str,
        incident_id: Optional[str] = None,
    ) -> None:
        """Registra métricas de interação."""

        self.token_metrics.log_interaction(
            model_name=self.get_name(),
            mode=mode,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            prompt=prompt,
            response=response,
            incident_id=incident_id,
        )

    def _apply_rate_limit(self, override: Optional[float] = None) -> None:
        """Aplica limitação de requisições quando configurada."""

        delay = override if override is not None else self.rate_limit
        if delay and delay > 0:
            time.sleep(delay)

    def get_model_info(self) -> Dict[str, Any]:
        """Retorna informações básicas do modelo."""

        return {
            "name": self.get_name(),
            "provider": self.provider,
            "temperature": self.temperature,
            "max_tokens": self.max_tokens,
            "rate_limit": self.rate_limit,
        }