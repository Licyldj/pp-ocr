import asyncio
import base64
import socket
import time
import traceback

import httpx
from loguru import logger

httpx_client = httpx.AsyncClient()


def image_to_base64(file_path: str) -> str:
    """读取本地图片文件并转换为base64字符串

    Args:
        file_path: 本地图片文件路径

    Returns:
        base64编码的图片字符串

    Raises:
        FileNotFoundError: 当文件不存在时
        ValueError: 当文件不是有效图片时
    """
    try:
        start = time.time()
        # 读取二进制图片数据
        with open(file_path, "rb") as f:
            image_bytes = f.read()

        # 验证图片有效性
        # image_np = np.frombuffer(image_bytes, dtype=np.uint8)
        # cv2.imdecode(image_np, cv2.IMREAD_COLOR)

        # 转换为base64字符串
        return base64.b64encode(image_bytes).decode('utf-8')
    except FileNotFoundError:
        process_time = (time.time() - start) * 1000
        formatted_process_time = '{0:.2f}'.format(process_time)
        logger.error(
            f"file_path={file_path} completed_in={formatted_process_time}ms image_to_base64 error traceback={traceback.format_exc()}")
        return None
    except Exception as e:
        process_time = (time.time() - start) * 1000
        formatted_process_time = '{0:.2f}'.format(process_time)
        logger.error(
            f"file_path={file_path} completed_in={formatted_process_time}ms image_to_base64 error traceback={traceback.format_exc()}")
        return None


async def read_images(image_type: str, image_path: str):
    match image_type:
        case "base64":
            # image_bytes = base64.b64decode(image_path)
            # 验证图片有效性
            # image_np = np.frombuffer(image_bytes, dtype=np.uint8)
            # cv2.imdecode(image_np, cv2.IMREAD_COLOR)

            return image_path
        case "url":
            return await url_to_base64(image_path)
        case "local":
            return await asyncio.to_thread(image_to_base64, image_path)


async def url_to_base64(url: str) -> str:
    """将远程图片URL转换为base64字符串

    Args:
        url: 图片URL地址

    Returns:
        base64编码的图片字符串
    """
    start = time.time()
    for retry in range(2):  # 沿用现有重试机制
        try:
            # 复用全局httpx_client发起请求
            response = await httpx_client.get(url, timeout=0.5)
            response.raise_for_status()

            # 直接获取二进制内容进行编码
            image_bytes = response.content

            # 验证图片有效性
            # image_np = np.frombuffer(image_bytes, dtype=np.uint8)
            # cv2.imdecode(image_np, cv2.IMREAD_COLOR)

            return base64.b64encode(image_bytes).decode('utf-8')
        except Exception as e:
            if retry == 1:
                process_time = (time.time() - start) * 1000
                formatted_process_time = '{0:.2f}'.format(process_time)
                logger.error(
                    f"url={url} completed_in={formatted_process_time}ms url_to_base64 error traceback={traceback.format_exc()}")
            return None


async def get_ocr_result(image_base64: str, port: int, timeout=2):
    return await get_ocr_results([image_base64], port, timeout=timeout)


async def get_ocr_results(image_base64_list: list[str], port: int, timeout=2):
    # post 调用http获取result
    result = {}
    start = time.time()
    try:
        result = await httpx_client.post(
            f"http://{get_host_ip()}:{port}/predict/ocr_system",
            json={"images": image_base64_list},
            timeout=timeout)
        result = result.json()
        if result['status'] == '000':
            return process_ocr_results(result)
    except Exception as e:
        process_time = (time.time() - start) * 1000
        formatted_process_time = '{0:.2f}'.format(process_time)
        logger.error(
            f"completed_in={formatted_process_time}ms get_ocr_result error traceback={traceback.format_exc()}")
    return {
        'lines': []
    }


def process_ocr_results(ocr_data, y_threshold=15, min_confidence=0.6):
    """ 结构化处理OCR原始结果
   Args:
       ocr_data: 原始OCR响应数据
       y_threshold: 行合并垂直阈值(像素)
       min_confidence: 置信度过滤阈值

   Returns:
       list: 结构化结果
           {
               'lines': [
                   {
                       'text': '合并后的文本',
                       'avg_confidence': 0.85,
                       'position': [x1, y1, x2, y2]
                   }
               ]
           }

   """
    image_result = []

    for page_idx, page_results in enumerate(ocr_data['results'], start=1):
        page_data = {
            'lines': []
        }
        # 过滤低置信度结果
        valid_items = [item for item in page_results if item['confidence'] >= min_confidence]

        # 按行合并
        lines = merge_ocr_lines(valid_items, y_threshold)

        for line_text, line_items in lines:
            # 计算行区域坐标
            x_coords = [p[0] for item in line_items for p in item['text_region']]
            y_coords = [p[1] for item in line_items for p in item['text_region']]

            page_data['lines'].append({
                'text': line_text,
                'avgConfidence': sum(i['confidence'] for i in line_items) / len(line_items),
                'position': [
                    min(x_coords),  # left
                    min(y_coords),  # top
                    max(x_coords),  # right
                    max(y_coords)  # bottom
                ]
            })

        image_result.append(page_data)

    return image_result


def merge_ocr_lines(ocr_results, y_threshold=10):
    """ 将OCR结果按行合并
   Args:
       ocr_results: OCR识别结果列表
       y_threshold: 行高差异阈值（像素）

   Returns:
       list: 合并后的行文本列表，格式为 ["Hello World", ...]
   """

    # 计算每个文本框的垂直中线坐标
    processed = []
    for item in ocr_results:
        ys = [point[1] for point in item['text_region']]
        avg_y = sum(ys) / len(ys)
        processed.append((avg_y, item))

    # 按垂直坐标排序后分组
    processed.sort(key=lambda x: x[0])
    lines = []
    current_line = []
    last_y = None

    for y_pos, item in processed:
        if last_y is None or abs(y_pos - last_y) <= y_threshold:
            current_line.append(item)
        else:
            lines.append(current_line)
            current_line = [item]
        last_y = y_pos
    if current_line:
        lines.append(current_line)

    # 行内按水平位置排序并合并文本
    merged_lines = []
    for line in lines:
        # 计算水平中线坐标并排序
        sorted_line = sorted(
            line,
            key=lambda x: sum(point[0] for point in x['text_region']) / 4
        )
        merged_text = ' '.join([item['text'] for item in sorted_line])
        merged_lines.append(merged_text)

    return [(merged_text, sorted_line) for sorted_line, merged_text in zip(lines, merged_lines)]


async def warm_up_ocr(port: int):
    logger.info("Starting OCR service warm-up...")
    await asyncio.sleep(16)
    image_base64 = image_to_base64("41231f9b-8e22-49bb-97db-7d82a481448e.png")
    for _ in range(5):
        await get_ocr_result(image_base64, port)
        await asyncio.sleep(1)
    logger.success("OCR warm-up completed")


def get_host_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
    finally:
        s.close()

    return ip
