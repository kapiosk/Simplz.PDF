# Simplz.PDF

Simplz.PDF is a FastAPI service that uses Playwright Chromium to:

- render raw HTML to PDF
- render a remote URL to PDF
- capture a remote URL as a PNG image

The service listens on port `5501` by default.

## Requirements

- Python 3.12 recommended
- Playwright Chromium browser binaries
- Docker Desktop if you want to run the containerized version

## Local Development

Create and activate a virtual environment, then install dependencies:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
playwright install chromium
```

Start the API locally:

```powershell
python app.py
```

Alternatively, run it with Uvicorn directly:

```powershell
uvicorn wsgi:app --host 0.0.0.0 --port 5501 --workers 1
```

`--workers 1` is intentional. The current implementation keeps a shared Playwright browser instance in process.

Service URL:

```text
http://localhost:5501
```

## Docker

Build and start the service:

```powershell
docker compose up -d --build
```

Stop the service:

```powershell
docker compose down
```

Check container status:

```powershell
docker compose ps
```

The container image installs Chromium and the required Playwright system dependencies during build.

## PowerShell Deployment Script

For Windows environments, use the bundled deployment script:

```powershell
.\deploy.ps1
```

The script:

- stops running containers
- rebuilds the image
- starts the service in detached mode
- prints container status

## API Endpoints

### `GET /`

Simple text response used as a basic sanity check.

Example:

```powershell
curl http://localhost:5501/
```

### `GET /health`

Health endpoint used by Docker health checks.

Example:

```powershell
curl http://localhost:5501/health
```

Expected response:

```json
{"status":"ok"}
```

### `GET /Test`

Generates a small sample PDF to verify Playwright PDF rendering is working.

Example:

```powershell
curl http://localhost:5501/Test --output test.pdf
```

### `POST /PDF`

Accepts raw HTML in the request body and returns a PDF.

Example:

```powershell
$html = '<html><body><h1>Hello</h1><p>Rendered by Simplz.PDF</p></body></html>'
Invoke-WebRequest -Uri http://localhost:5501/PDF -Method Post -Body $html -ContentType 'text/html; charset=utf-8' -OutFile document.pdf
```

### `GET /PDFURL`

Loads a remote page and returns a PDF.

Query parameters:

- `dataUrl`: required target URL

Optional headers:

- `Authorization`: token value to forward as a bearer token
- `landscape`: `true` or `false`

Example:

```powershell
Invoke-WebRequest -Uri 'http://localhost:5501/PDFURL?dataUrl=https://example.com' -OutFile page.pdf
```

Example with forwarded authorization token:

```powershell
Invoke-WebRequest -Uri 'http://localhost:5501/PDFURL?dataUrl=https://example.com' -Headers @{ Authorization = 'your-token' } -OutFile protected.pdf
```

Note: the service currently forwards the header as `Bearer <token>` when requesting the target page.

### `GET /PDFToImage`

Loads a remote page and returns a PNG screenshot.

Query parameters:

- `dataUrl`: required target URL

Optional headers:

- `Authorization`: token value to forward as a bearer token

Example:

```powershell
Invoke-WebRequest -Uri 'http://localhost:5501/PDFToImage?dataUrl=https://example.com' -OutFile screenshot.png
```

## Linux Service Deployment

If you want to run the API directly on a Linux host without Docker, a `systemd` service is the simplest option.

Create a unit file:

```bash
sudo nano /etc/systemd/system/simplzpdf.service
```

Example service configuration:

```ini
[Unit]
Description=Simplz.PDF FastAPI service
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=/var/www/html/Simplz.PDF
Environment="PATH=/var/www/html/Simplz.PDF/.venv/bin"
ExecStart=/var/www/html/Simplz.PDF/.venv/bin/uvicorn wsgi:app --host 127.0.0.1 --port 5501 --workers 1
Restart=always

[Install]
WantedBy=multi-user.target
```

Reload and enable the service:

```bash
sudo systemctl daemon-reload
sudo systemctl start simplzpdf.service
sudo systemctl status simplzpdf.service
sudo systemctl enable simplzpdf.service
```

## Reverse Proxy Example

If you expose the service behind Caddy:

```caddyfile
yourdomain.com {
    reverse_proxy 127.0.0.1:5501
}
```

Or with Nginx:

```nginx
server {
    listen 80;
    server_name simplzpdf.domain;

    location / {
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_pass http://127.0.0.1:5501;
    }
}
```