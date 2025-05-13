#!/bin/bash

# 在/tmp 下创建个目录
mkdir -p /tmp/image-ocr-service-la

docker compose -f docker-compose-la.yaml down

docker compose -f docker-compose-la.yaml up -d
