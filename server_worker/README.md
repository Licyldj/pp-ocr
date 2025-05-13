#### 使用hubserving方式部署paddleOCR模型
由于hubserving方式部署的OCR模型，推理时只支持base64的方式，因此在dockerCompose中封装了一个server，负责接受图片，包括图片的URL，base64编码，以及图片的二进制数据，然后调用paddleOCR模型进行识别.

ocr_worker中是针对不同语言的实现方案，每个目录代表一种语言，以ar 阿拉伯语为例：
config.json文件为部署使用的配置值文件，包括是否使用GPU，以及端口和线程数。
module.py文件为模型部署的代码，可以不使用该文件，我使用该文件的目的是控制gpu_mem参数。
params.py文件为模型参数配置文件，建议与我保持一致。

ocr_server中主要是使用fastapi封装了一个接口，负责接受图片后转成base64并调用本机的GPU OCR 推理。