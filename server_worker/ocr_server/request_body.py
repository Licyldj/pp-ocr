from typing import Literal

from pydantic import BaseModel

imageTypeT = Literal["base64", "local", "url"]


class RequestBody(BaseModel):
    taskId: str
    images: list[str]
    imageType: imageTypeT
    timeout: int
