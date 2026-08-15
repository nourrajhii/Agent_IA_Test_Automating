FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        wget gnupg curl unzip \
        tesseract-ocr \
        libnss3 libatk-bridge2.0-0 libgtk-3-0 libgbm1 libasound2 \
        fonts-liberation \
    && wget -q -O /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get install -y /tmp/chrome.deb \
    && rm /tmp/chrome.deb \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

RUN python -c "from webdriver_manager.chrome import ChromeDriverManager; ChromeDriverManager().install()"

COPY app ./app

RUN mkdir -p reports screenshots uploads

ENV TESSERACT_CMD=""
ENV PYTHONUNBUFFERED=1

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]