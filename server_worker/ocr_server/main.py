import asyncio
import logging
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI
from loguru import logger
from pydantic_settings import BaseSettings

from prometheus_utils import PrometheusMiddleware, metrics_app
from request_body import RequestBody
from utils import get_host_ip, httpx_client, read_images, warm_up_ocr, get_ocr_results


class Settings(BaseSettings):
    port: int = 8002
    worker_port: int = 8802
    profile: str = "test"
    app_name: str = "image-ocr-server-la"


settings = Settings()

logger.info(f"settings={settings}")

# 日志
logger = logging.getLogger()
logger.setLevel(logging.INFO)
ch = logging.StreamHandler()
# fh = logging.FileHandler(filename='./logs/image-ocr-server-la.log')
fh = logging.FileHandler(filename=f"./logs/{settings.app_name}.log")
formatter = logging.Formatter(
    "%(asctime)s - %(module)s - %(funcName)s - line:%(lineno)d - %(levelname)s - %(message)s"
)
fh = logging.handlers.RotatingFileHandler(f"./logs/{settings.app_name}.log", mode="a",
                                          maxBytes=1024 * 1024 * 500,
                                          backupCount=3)

ch.setFormatter(formatter)
fh.setFormatter(formatter)
logger.addHandler(ch)  # 将日志输出至屏幕
logger.addHandler(fh)  # 将日志输出至文件

logging.getLogger('nacos').setLevel(logging.ERROR)
logging.getLogger('apscheduler.executors').setLevel(logging.ERROR)

logger = logging.getLogger(__name__)

host_ip = get_host_ip()
logger.info(f"host_ip={host_ip}")



@asynccontextmanager
async def lifespan(app: FastAPI):
    await warm_up_ocr(settings.worker_port)
    yield
    logger.info(f"APP_NAME={settings.app_name} start shutdown")
    await httpx_client.aclose()


app = FastAPI(lifespan=lifespan, title="ocr检测", description="检测图片中文本内容")

app.add_middleware(PrometheusMiddleware, app_name=settings.app_name)
app.mount("/metrics", metrics_app)


@app.middleware("http")
async def log_requests(request, call_next):
    idem = request.headers.get('Request-ID')

    logger.info(f"rid={idem} start request path={request.url.path}")
    start_time = time.time()
    response = await call_next(request)

    process_time = (time.time() - start_time) * 1000
    formatted_process_time = '{0:.2f}'.format(process_time)
    logger.info(f"rid={idem} completed_in={formatted_process_time}ms status_code={response.status_code}")

    return response


@app.get("/")
def read_root():
    return {"Hello": "World"}


async def get_images_base64(req: RequestBody):
    start = time.time()
    images_base64 = []
    image_type = req.imageType
    for each_image in req.images:
        image = await read_images(image_type, each_image)
        images_base64.append(image)

    process_time = (time.time() - start) * 1000
    formatted_process_time = '{0:.2f}'.format(process_time)
    logging.info("rid={},get_images_base64 used:{}".format(req.taskId, formatted_process_time))
    return images_base64


async def get_ocr_results_by_base64_list(images_base64_list, port: int, timeout: int):
    ocr_result = await get_ocr_results(images_base64_list, port, timeout)
    return ocr_result


@app.post("/predict/ocr")
async def predict(req: RequestBody):
    result = {'status': 0}
    start = time.time()

    try:
        logging.info("rid={},req json_input:{}".format(req.taskId, req))

        # 下载图片
        images = await get_images_base64(req)

        combined = asyncio.gather(get_ocr_results_by_base64_list(images, settings.worker_port, 2))

        res_time = req.timeout / 1000 - (time.time() - start)
        ocr_results = await asyncio.wait_for(combined, timeout=res_time)
        process_time = (time.time() - start) * 1000
        formatted_process_time = '{0:.2f}'.format(process_time)
        logging.info("rid={},step2 used:{} ,get_ocr_results:{}".format(req.taskId, formatted_process_time, ocr_results))

        result['ocrResults'] = ocr_results[0]
        result['used'] = (time.time() - start) * 1000
    except TimeoutError:
        result['status'] = -1
        result['used'] = (time.time() - start) * 1000
        logging.exception("rid={},TimeoutError:", req.taskId)
    except Exception:
        logging.exception("rid={},error:", req.taskId)
        result['status'] = -1
        result['used'] = (time.time() - start) * 1000

    return result
