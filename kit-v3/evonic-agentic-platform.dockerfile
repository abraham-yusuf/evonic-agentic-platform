# syntax=docker/sandbox-kit:3
ARG EVONIC_REF=c902fae060192ac6261697598ce0034ce10b5819
FROM python:3.12-slim-bookworm

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HOME=/home/evonic \
    HOST=0.0.0.0 \
    PORT=8080 \
    SHARED_DB_DIR=/opt/evonic/shared/db

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates git build-essential libpq-dev libgl1 libglib2.0-0 \
      libsm6 libxext6 libxrender1 \
    && apt-get clean

RUN useradd --create-home --uid 10001 --shell /bin/bash evonic \
    && git clone --depth 1 --branch "${EVONIC_REF}" \
       https://github.com/anvie/evonic.git /opt/evonic

WORKDIR /opt/evonic
RUN python -m pip install --no-cache-dir --upgrade pip \
    && python -m pip install --no-cache-dir -r requirements.txt \
    && mkdir -p /opt/evonic/shared/db \
    && chown -R evonic:evonic /opt/evonic /home/evonic

USER evonic
EXPOSE 8080
VOLUME ["/opt/evonic/shared"]
CMD ["python", "app.py"]
