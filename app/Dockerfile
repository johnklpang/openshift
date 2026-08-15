FROM registry.access.redhat.com/ubi9/python-312:latest

ENV APP_NAME=openshift-lab-hello \
    APP_VERSION=1.0.0 \
    PORT=8080 \
    PYTHONUNBUFFERED=1

WORKDIR /opt/app-root/src

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

EXPOSE 8080

USER 1001

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "1", "--threads", "2", "app:app"]
