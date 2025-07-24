#!/bin/bash

# 在/tmp 下创建个目录
mkdir -p /tmp/image-ocr-service-ru

docker compose -f docker-compose-ru.yaml down

docker compose -f docker-compose-ru.yaml up -d
