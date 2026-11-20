FROM python:3.11-slim
WORKDIR /opt/roxy-wi
COPY requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
COPY app ./app
COPY run.py ./run.py
EXPOSE 8080
# PATCHED is passed through by docker-compose (0 = vulnerable v8.2.6.4, 1 = fixed).
ENV PATCHED=0
# Runs as root (image default) -> the os:system RCE executes as uid=0, as in the advisory.
CMD ["python", "run.py"]
