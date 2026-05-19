FROM python:3.11-slim
WORKDIR /app
RUN apt-get update && apt-get install -y gcc libpq-dev && rm -rf /var/lib/apt/lists/*

# Build FROM the committed artifact, NOT from source
COPY artifacts/*.tar.gz app.tar.gz
RUN tar -xzf app.tar.gz && rm app.tar.gz

# Install dependencies that were frozen in the artifact
RUN pip install --no-cache-dir -r requirements.txt

# Setup user
RUN useradd -m appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000
CMD ["gunicorn", "book_shop.wsgi:application", "--bind", "0.0.0.0:8000"]
