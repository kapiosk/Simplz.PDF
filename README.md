# SimplzPDF

## Installation

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirement.txt
python -m playwright install
python -m playwright install-deps
```

## Deployment

### Service

```bash
sudo nano /etc/systemd/system/simplzpdf.service
```

```bash
[Unit]
Description=Gunicorn instance to serve simplzpdf
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=/var/www/html/SimplzPDF
Environment="PATH=/var/www/html/SimplzPDF/venv/bin"
ExecStart=/var/www/html/SimplzPDF/venv/bin/gunicorn --workers 3 --bind unix:simplzpdf.sock -m 007 wsgi:app

[Install]
WantedBy=multi-user.target
```

_Please note that if you are using globals and main user, you might need to omit group and environment_

### Reload systemctl

```bash
sudo systemctl daemon-reload
```

Start service

```bash
sudo systemctl start simplzpdf.service
```

Check service status service

```bash
sudo systemctl status simplzpdf.service
```

Enable service if everything is ok

```bash
sudo systemctl enable simplzpdf.service
```

### Nginx

```bash
server {
    listen 80;
    server_name simplzpdf.domain;
    location / {
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_pass http://unix:/var/www/html/SimplzPDF/simplzpdf.sock;
    }
}
```
