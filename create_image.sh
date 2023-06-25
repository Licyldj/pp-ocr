#!/bin/bash

lg=$1

det_model_link=https://paddleocr.bj.bcebos.com/PP-OCRv3/multilingual/Multilingual_PP-OCRv3_det_infer.tar

PORT=8860
# lg为空 默认中文识别
if [ -z ${lg} ]; then
  det_model_link=https://paddleocr.bj.bcebos.com/PP-OCRv3/chinese/ch_PP-OCRv3_det_infer.tar
  rec_model_link=https://paddleocr.bj.bcebos.com/PP-OCRv3/chinese/ch_PP-OCRv3_rec_infer.tar
  rec_char_dict_path=./ppocr/utils/ppocr_keys_v1.txt
  lg=ch

# 韩文识别
if [ ${lg} == "korean" ]; then
  rec_model_link=https://paddleocr.bj.bcebos.com/PP-OCRv3/multilingual/korean_PP-OCRv3_rec_infer.tar
  rec_char_dict_path=./ppocr/utils/dict/korean_dict.txt

# 日文识别
elif [ ${lg} == "japan" ]; then
  rec_model_link=https://paddleocr.bj.bcebos.com/PP-OCRv3/multilingual/japan_PP-OCRv3_rec_infer.tar
  rec_char_dict_path=./ppocr/utils/dict/japan_dict.txt

# 中文繁体识别
elif [ ${lg} == "chinese_cht" ]; then
  rec_model_link=https://paddleocr.bj.bcebos.com/PP-OCRv3/multilingual/chinese_cht_PP-OCRv3_rec_infer.tar
  rec_char_dict_path=./ppocr/utils/dict/chinese_cht_dict.txt

# 泰卢固文识别
elif [ ${lg} == "te" ]; then
  rec_model_link=https://paddleocr.bj.bcebos.com/PP-OCRv3/multilingual/te_PP-OCRv3_rec_infer.tar
  rec_char_dict_path=./ppocr/utils/dict/te_dict.txt

# 卡纳达文识别
elif [ ${lg} == "ka" ]; then
  rec_model_link=https://paddleocr.bj.bcebos.com/PP-OCRv3/multilingual/ka_PP-OCRv3_rec_infer.tar
  rec_char_dict_path=./ppocr/utils/dict/ka_dict.txt

# 泰米尔文识别
elif [ ${lg} == "ta" ]; then
  rec_model_link=https://paddleocr.bj.bcebos.com/PP-OCRv3/multilingual/ta_PP-OCRv3_rec_infer.tar
  rec_char_dict_path=./ppocr/utils/dict/ta_dict.txt

# 拉丁文识别
elif [ ${lg} == "latin" ]; then
  rec_model_link=https://paddleocr.bj.bcebos.com/PP-OCRv3/multilingual/latin_PP-OCRv3_rec_infer.tar
  rec_char_dict_path=./ppocr/utils/dict/latin_dict.txt

# 阿拉伯字母
elif [ ${lg} == "arabic" ]; then
  rec_model_link=https://paddleocr.bj.bcebos.com/PP-OCRv3/multilingual/arabic_PP-OCRv3_rec_infer.tar
  rec_char_dict_path=./ppocr/utils/dict/arabic_dict.txt

# 斯拉夫字母
elif [ ${lg} == "cyrillic" ]; then
  rec_model_link=https://paddleocr.bj.bcebos.com/PP-OCRv3/multilingual/cyrillic_PP-OCRv3_rec_infer.tar
  rec_char_dict_path=./ppocr/utils/dict/cyrillic_dict.txt

# 梵文字母
elif [ ${lg} == "devanagari" ]; then
  rec_model_link=https://paddleocr.bj.bcebos.com/PP-OCRv3/multilingual/devanagari_PP-OCRv3_rec_infer.tar
  rec_char_dict_path=./ppocr/utils/dict/devanagari_dict.txt
fi

echo "${lg}"
echo "${det_model_link}"
echo "${rec_model_link}"
echo "${rec_char_dict_path}"

det_model_file=$(basename -s .tar "${det_model_link}")
echo "${det_model_file}"
rec_model_file=$(basename -s .tar "${rec_model_link}")
echo "${rec_model_file}"

cat>ocr_system/config.json<<EOF
{
    "modules_info": {
        "ocr_system": {
            "init_args": {
                "version": "1.0.0",
                "use_gpu": true
            },
            "predict_args": {
            }
        }
    },
    "port": ${PORT},
    "use_multiprocess": false,
    "workers": 2
}
EOF

cat>ocr_system/params.py<<EOF
from __future__ import absolute_import
from __future__ import division
from __future__ import print_function


class Config(object):
    pass


def read_params():
    cfg = Config()

    #params for text detector
    cfg.det_algorithm = "DB"
    cfg.det_model_dir = "./inference/${det_model_file}/"
    cfg.det_limit_side_len = 960
    cfg.det_limit_type = 'max'

    #DB parmas
    cfg.det_db_thresh = 0.3
    cfg.det_db_box_thresh = 0.5
    cfg.det_db_unclip_ratio = 1.6
    cfg.use_dilation = False
    cfg.det_db_score_mode = "fast"

    #EAST parmas
    cfg.det_east_score_thresh = 0.8
    cfg.det_east_cover_thresh = 0.1
    cfg.det_east_nms_thresh = 0.2

    #params for text recognizer
    cfg.rec_algorithm = "CRNN"
    cfg.rec_model_dir = "./inference/${rec_model_file}/"

    cfg.rec_image_shape = "3, 48, 320"
    cfg.rec_batch_num = 6
    cfg.max_text_length = 25

    cfg.rec_char_dict_path = "${rec_char_dict_path}"
    cfg.use_space_char = True

    cfg.use_pdserving = False
    cfg.use_tensorrt = False
    cfg.drop_score = 0.5

    return cfg
EOF


cat>DockerfileGPU-${lg}<<EOF
# Version: 2.3.0
FROM registry.baidubce.com/paddlepaddle/paddle:2.4.0-gpu-cuda11.7-cudnn8.4-trt8.4

# PaddleOCR base on Python3.7
RUN pip3.7 install --upgrade pip -i https://mirror.baidu.com/pypi/simple

RUN pip3.7 install paddlehub --upgrade -i https://mirror.baidu.com/pypi/simple

RUN git clone https://github.com/PaddlePaddle/PaddleOCR.git /PaddleOCR

WORKDIR /PaddleOCR

RUN pip3.7 install -r requirements.txt -i https://mirror.baidu.com/pypi/simple


RUN mkdir -p /PaddleOCR/inference/

ENV det_model_link=${det_model_link}
ENV det_model_file=${det_model_file}

ENV rec_model_link=${rec_model_link}
ENV rec_model_file=${rec_model_file}

ADD ${det_model_link} /PaddleOCR/inference/
RUN tar xf /PaddleOCR/inference/${det_model_file}.tar -C /PaddleOCR/inference/


ADD ${rec_model_link} /PaddleOCR/inference/
RUN tar xf /PaddleOCR/inference/${rec_model_file}.tar -C /PaddleOCR/inference/


COPY ./ocr_system/params.py /PaddleOCR/deploy/hubserving/ocr_system
COPY ./ocr_system/config.json /PaddleOCR/deploy/hubserving/ocr_system

ENV CUDA_VISIBLE_DEVICES=0

CMD ["/bin/bash","-c","hub install deploy/hubserving/ocr_system/ && hub serving start -c deploy/hubserving/ocr_system/config.json -m ocr_system"]
EOF

docker build -f DockerfileGPU-${lg} -t paddleocr-${lg}:gpu .

echo "build image success ->>> DockerfileGPU-${lg}:gpu"

docker run -d --rm --gpus=all -p ${PORT}:${PORT} --name paddleocr-${lg} paddleocr-${lg}:gpu

host_ip=$(ifconfig eth0 | grep "inet" |grep -v inet6 | awk '{ print $2}')

echo "paddleocr-${lg} start success URL:http://${host_ip}:${PORT}/predict/ocr_system"