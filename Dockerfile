FROM python:slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

WORKDIR /app

RUN apt-get update \
    && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# The registry sits behind Cloudflare, which rejects any request body over
# 100 MiB. Docker uploads each layer as a single PUT, so no layer may exceed
# that. The headless shell install is ~250 MiB as one layer, dominated by the
# ~188 MiB chrome-headless-shell binary -- and a single file cannot span
# layers. So stage it into two trees that each mirror /ms-playwright: the
# binary alone, and everything else. They are COPYed separately below, which
# lands them as two layers of roughly 79 MiB and 30 MiB.
FROM base AS browser

RUN playwright install --only-shell chromium \
    && mkdir -p /stage-rest /stage-big \
    && cp -a /ms-playwright /stage-rest/ms-playwright \
    && cd /stage-rest/ms-playwright \
    && shell="$(find . -type f -name chrome-headless-shell -size +50M | head -1)" \
    && [ -n "$shell" ] \
    && mkdir -p "/stage-big/ms-playwright/$(dirname "$shell")" \
    && mv "$shell" "/stage-big/ms-playwright/$shell"

FROM base

# Chromium's system dependencies, split into libraries and fonts for the same
# 100 MiB reason. The list mirrors `playwright install-deps chromium`; the
# install-deps call afterwards is a cheap safety net that picks up anything a
# future playwright version adds to that list.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libasound2t64 libatk-bridge2.0-0t64 libatk1.0-0t64 libatspi2.0-0t64 \
        libcairo2 libcups2t64 libdbus-1-3 libdrm2 libfontconfig1 libfreetype6 \
        libgbm1 libglib2.0-0t64 libnspr4 libnss3 libpango-1.0-0 libx11-6 \
        libxcb1 libxcomposite1 libxdamage1 libxext6 libxfixes3 libxkbcommon0 \
        libxrandr2 xvfb \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        fonts-freefont-ttf fonts-ipafont-gothic fonts-liberation \
        fonts-noto-color-emoji fonts-tlwg-loma-otf fonts-unifont \
        fonts-wqy-zenhei xfonts-scalable \
    && rm -rf /var/lib/apt/lists/*

RUN playwright install-deps chromium \
    && rm -rf /var/lib/apt/lists/*

COPY --from=browser /stage-rest/ms-playwright /ms-playwright
COPY --from=browser /stage-big/ms-playwright /ms-playwright

# Fails the build loudly if the staged split above did not reassemble into a
# launchable browser -- e.g. a playwright upgrade relocating the binary.
RUN python -c "from playwright.sync_api import sync_playwright; p = sync_playwright().start(); b = p.chromium.launch(); b.close(); p.stop()"

COPY . .

EXPOSE 5501

CMD ["uvicorn", "wsgi:app", "--host", "0.0.0.0", "--port", "5501", "--workers", "1"]
