# EUROPESIP custom MCP Server for HCL DX IQ (Lab 3B of https://github.com/europesip/hcl-dx-compose-labs)
FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY server.py .

# Any non-root user works (OpenShift assigns its own UID): the server writes nothing to disk
USER 10001
ENV PORT=3000 PYTHONUNBUFFERED=1
EXPOSE 3000
CMD ["python", "server.py"]
