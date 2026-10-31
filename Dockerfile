# ==========================================
# 1. Build Stage
# ==========================================
FROM cgr.dev/chainguard/python:3.13-dev AS builder

WORKDIR /app

# Create isolated virtual environment
RUN python -m venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

# Install runtime dependencies and purge build/packaging tools
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && \
    pip uninstall -y pip setuptools wheel 2>/dev/null || true

# ==========================================
# 2. Production Stage (Hardened Runtime)
# ==========================================
FROM cgr.dev/chainguard/python@sha256:35d6025b288eb1c40ae631db77ed6cdd26c6f51d898428d8fc9989db7f29e784

WORKDIR /app

# Code Immutability: Files owned by root (read-only to runtime user)
# Naturally preserves host permissions (755 for dirs, 644 for files)
COPY --from=builder --chown=root:root /app/venv /app/venv
COPY --chown=root:root app/ ./app/

# Optimize Python execution
ENV PATH="/app/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Expose default application port
EXPOSE 8080

# Enforce non-root execution
USER 65532:65532

# Exec-form ENTRYPOINT ensures Gunicorn handles SIGTERM/SIGINT gracefully
ENTRYPOINT ["/app/venv/bin/gunicorn", "--chdir", "app", "--bind", "0.0.0.0:8080"]
CMD ["--workers", "2", "app:app"]
