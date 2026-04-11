# ---- Stage 1: Build dependencies ----
# Using a multi-stage build so the final image doesn't carry pip, gcc,
# or any build tooling. This cuts image size significantly and reduces
# the attack surface in production.
FROM python:3.12-slim AS builder

WORKDIR /build

# Copy requirements first, separately from app code.
# WHY: Docker layer caching — requirements change rarely, app code changes often.
# This means `pip install` only re-runs when dependencies actually change,
# saving minutes on every rebuild during development.
COPY requirements.txt .

# Install into a prefix directory so we can copy just the installed packages
# to the final image without dragging along pip/setuptools/wheel.
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---- Stage 2: Production image ----
# Using slim (not alpine) because alpine uses musl libc which can cause
# subtle issues with some Python packages (e.g., grpcio, cryptography).
# Slim gives us glibc compatibility with a small footprint (~120MB).
FROM python:3.12-slim

# Run as non-root user.
# WHY: If the container gets compromised, the attacker only has
# unprivileged access. This is a Kubernetes security best practice
# and many clusters enforce this via PodSecurityStandards.
RUN groupadd -r appuser && useradd -r -g appuser -d /app -s /sbin/nologin appuser

WORKDIR /app

# Copy only the installed Python packages from the builder stage.
COPY --from=builder /install /usr/local

# Copy application code.
COPY app/ ./app/

# Switch to non-root before running.
USER appuser

# Expose the port uvicorn will listen on.
# WHY 8000: It's the uvicorn default and above 1024 (non-root can bind it).
EXPOSE 8000

# Health check built into the image.
# WHY: Even without Kubernetes probes, `docker run` and ECS can use this.
# Checks the /healthz endpoint every 30s with a 5s timeout.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/healthz')"]

# Use exec form (JSON array) so uvicorn gets PID 1 and receives SIGTERM
# directly from Kubernetes during pod shutdown — no zombie processes.
#
# --workers 4: one per CPU core (t3.medium has 2 vCPUs, but we over-provision
# slightly because most time is spent waiting on Vault/KMS I/O, not CPU).
#
# --host 0.0.0.0: listen on all interfaces so Kubernetes service routing works.
#
# --log-level info: enough detail for debugging without flooding CloudWatch.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4", "--log-level", "info"]
