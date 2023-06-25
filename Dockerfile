# Version: 2.3.0
FROM registry.baidubce.com/paddlepaddle/paddle:2.3.0

# PaddleOCR base on Python3.7
RUN pip3.7 install --upgrade pip -i https://mirror.baidu.com/pypi/simple

RUN pip3.7 install paddlehub --upgrade -i https://mirror.baidu.com/pypi/simple

RUN git clone https://github.com/PaddlePaddle/PaddleOCR.git /PaddleOCR

WORKDIR /PaddleOCR

RUN pip3.7 install -r requirements.txt -i https://mirror.baidu.com/pypi/simple

RUN mkdir -p /PaddleOCR/inference/
ENV det_model_link=https://paddleocr.bj.bcebos.com/dygraph_v2.0/ch/ch_ppocr_server_v2.0_det_infer.tar
ENV det_model_file=ch_ppocr_server_v2.0_det_infer
ENV classify_model_link=https://paddleocr.bj.bcebos.com/dygraph_v2.0/ch/ch_ppocr_mobile_v2.0_cls_infer.tar
ENV classify_model_file=ch_ppocr_mobile_v2.0_cls_infer
ENV rec_model_link=https://paddleocr.bj.bcebos.com/dygraph_v2.0/ch/ch_ppocr_server_v2.0_rec_infer.tar
ENV rec_model_file=ch_ppocr_server_v2.0_rec_infer
# Download orc detect model(light version). if you want to change normal version, you can change ch_ppocr_mobile_v2.0_det_infer to ch_ppocr_server_v2.0_det_infer, also remember change det_model_dir in deploy/hubserving/ocr_system/params.py�~I
ADD ${det_model_link} /PaddleOCR/inference/
RUN tar xf /PaddleOCR/inference/${det_model_file}.tar -C /PaddleOCR/inference/ \
  && mv /PaddleOCR/inference/${det_model_file} /PaddleOCR/inference/ch_PP-OCRv3_det_infer

# Download direction classifier(light version). If you want to change normal version, you can change ch_ppocr_mobile_v2.0_cls_infer to ch_ppocr_mobile_v2.0_cls_infer, also remember change cls_model_dir in deploy/hubserving/ocr_system/params.py�~I
ADD ${classify_model_link} /PaddleOCR/inference/
RUN tar xf /PaddleOCR/inference/${classify_model_file}.tar -C /PaddleOCR/inference/
# && mv /PaddleOCR/inference/${classify_model_file} /PaddleOCR/inference/ch_ppocr_mobile_v2.0_cls_infer

# Download orc recognition model(light version). If you want to change normal version, you can change ch_ppocr_mobile_v2.0_rec_infer to ch_ppocr_server_v2.0_rec_infer, also remember change rec_model_dir in deploy/hubserving/ocr_system/params.py�~I
ADD ${rec_model_link} /PaddleOCR/inference/
RUN tar xf /PaddleOCR/inference/${rec_model_file}.tar -C /PaddleOCR/inference/ \
  && mv /PaddleOCR/inference/${rec_model_file} /PaddleOCR/inference/ch_PP-OCRv3_rec_infer

EXPOSE 8866

CMD ["/bin/bash","-c","hub install deploy/hubserving/ocr_system/ && hub serving start -m ocr_system"]