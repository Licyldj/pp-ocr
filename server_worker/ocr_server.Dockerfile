FROM python:3.10-slim

# timezone
#COPY Shanghai /etc/localtime
#RUN echo "Asia/Shanghai" > /etc/timezone

WORKDIR /app

#EXPOSE 8002

COPY ocr_server .

RUN pip install -r requirements.txt --no-cache-dir

#CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8002" ]