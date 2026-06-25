ARG PYTHON_IMAGE=python:3.13.1-slim-bookworm
FROM ${PYTHON_IMAGE}

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/opt/app

WORKDIR /opt/app
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && useradd --create-home --uid 10001 appuser

COPY app/src ./src
COPY app/templates ./templates
COPY app/static ./static
RUN chown -R appuser:appuser /opt/app

USER appuser
EXPOSE 8000
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
