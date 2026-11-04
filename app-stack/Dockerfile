FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY src/ ./src/
WORKDIR /app/src
USER nobody
EXPOSE 8000
# Exec form so python is PID 1 and receives SIGHUP from `docker kill -s HUP`.
CMD ["python", "main.py"]
