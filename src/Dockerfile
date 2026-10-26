FROM debian:bookworm-slim AS s5cmd
ARG TARGETARCH
ARG S5CMD_VERSION=2.2.2
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && case "$TARGETARCH" in arm64) A=arm64 ;; *) A=64bit ;; esac \
    && curl -fsSL "https://github.com/peak/s5cmd/releases/download/v${S5CMD_VERSION}/s5cmd_${S5CMD_VERSION}_Linux-${A}.tar.gz" \
    | tar -xz -C /usr/local/bin s5cmd

FROM python:3.10-slim AS builder
ENV PIP_NO_CACHE_DIR=1
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY requirements.txt .
RUN pip install --extra-index-url https://download.pytorch.org/whl/cpu torch==2.4.1 -r requirements.txt

FROM python:3.10-slim
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    HF_HUB_OFFLINE=1 \
    TRANSFORMERS_OFFLINE=1

RUN useradd --create-home --uid 1000 worker \
    && mkdir /models && chown worker /models

COPY --from=s5cmd /usr/local/bin/s5cmd /usr/local/bin/s5cmd
COPY --from=builder /opt/venv /opt/venv

WORKDIR /app
COPY app.py worker.py entrypoint.sh ./
RUN chmod +x entrypoint.sh

USER worker
ENTRYPOINT ["/app/entrypoint.sh"]
