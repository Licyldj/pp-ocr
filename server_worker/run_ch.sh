#!/bin/bash

# 在/tmp 下创建个目录
mkdir -p /tmp/image-ocr-service-ch

docker compose -f docker-compose-ch.yaml down

docker compose -f docker-compose-ch.yaml up -d
