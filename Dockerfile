FROM python:3.11-slim
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y gcc libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy and extract artifact
COPY artifacts/*.tar.gz app.tar.gz
RUN tar -xzf app.tar.gz && rm app.tar.gz

# Install Python dependencies from the extracted artifact
RUN pip install --no-cache-dir -r requirements.txt

# Create app user
RUN useradd -m appuser && chown -R appuser:appuser /app
USER appuser

# Static files are already collected in the artifact
EXPOSE 8000
CMD ["gunicorn", "book_shop.wsgi:application", "--bind", "0.0.0.0:8000"]
