#!/bin/bash

# 在/tmp 下创建个目录
mkdir -p /tmp/image-ocr-service-ar

docker compose -f docker-compose-ar.yaml down

docker compose -f docker-compose-ar.yaml up -d
