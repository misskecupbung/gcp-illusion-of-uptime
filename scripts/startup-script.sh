#!/bin/bash
set -e

# Update system
apt-get update

# Install Python and required packages
apt-get install -y python3 python3-pip

# Create non-root user for the app
useradd -r -s /bin/bash -d /opt/uptime-app -m appuser

# Get instance info from metadata
INSTANCE_NAME=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google")
ZONE=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/zone" -H "Metadata-Flavor: Google" | cut -d'/' -f4)

# Create the app
cat > /opt/uptime-app/app.py << 'PYEOF'
from http.server import HTTPServer, BaseHTTPRequestHandler
import socket
import os
import datetime
import json

class UptimeHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            
            hostname = socket.gethostname()
            instance_name = os.environ.get('INSTANCE_NAME', 'unknown')
            zone = os.environ.get('ZONE', 'unknown')
            
            html = f"""
            <!DOCTYPE html>
            <html>
            <head>
                <title>Uptime Demo</title>
                <meta charset="utf-8">
                <style>
                    body {{
                        font-family: -apple-system, sans-serif;
                        max-width: 600px;
                        margin: 40px auto;
                        padding: 20px;
                        line-height: 1.6;
                    }}
                    h1 {{ font-size: 24px; }}
                    .box {{
                        background: #f5f5f5;
                        border-left: 4px solid #333;
                        padding: 15px;
                        margin: 20px 0;
                    }}
                    code {{ 
                        background: #e8e8e8;
                        padding: 2px 6px;
                        font-size: 14px;
                    }}
                </style>
            </head>
            <body>
                <h1>Uptime Demo</h1>
                <p>Served by: <code>{instance_name}</code> in <code>{zone}</code></p>
                <div class="box">
                    <strong>How it works:</strong><br>
                    Three servers run behind a load balancer. Each request hits a random server.
                    If one dies, the others keep serving traffic. You won't even notice.
                </div>
                <p>Hostname: {hostname}<br>
                Time: {datetime.datetime.now().strftime('%H:%M:%S')}</p>
                <p><small>Refresh to see different servers →</small></p>
            </body>
            </html>
            """
            self.wfile.write(html.encode())
            
        elif self.path == '/health':
            # Health check endpoint
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {'status': 'healthy', 'instance': os.environ.get('INSTANCE_NAME', 'unknown')}
            self.wfile.write(json.dumps(response).encode())
            
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        # Log with timestamp
        print(f"[{datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] {format % args}")

if __name__ == '__main__':
    server = HTTPServer(('127.0.0.1', 8080), UptimeHandler)
    print(f"Server running on port 8080")
    print(f"Instance: {os.environ.get('INSTANCE_NAME', 'unknown')}")
    print(f"Zone: {os.environ.get('ZONE', 'unknown')}")
    server.serve_forever()
PYEOF

# Set ownership
chown -R appuser:appuser /opt/uptime-app

# Create env file (systemd EnvironmentFile format - no 'export')
echo "INSTANCE_NAME=$INSTANCE_NAME" > /opt/uptime-app/.env
echo "ZONE=$ZONE" >> /opt/uptime-app/.env
chown appuser:appuser /opt/uptime-app/.env

# Configure nginx as reverse proxy
apt-get install -y nginx
cat > /etc/nginx/sites-available/uptime-app << 'NGINXEOF'
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    location /health {
        proxy_pass http://127.0.0.1:8080/health;
        access_log off;
    }
}
NGINXEOF

ln -sf /etc/nginx/sites-available/uptime-app /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

# Create systemd service
cat > /etc/systemd/system/uptime-app.service << 'SERVICEEOF'
[Unit]
Description=Uptime Demo Application
After=network.target

[Service]
Type=simple
User=appuser
Group=appuser
WorkingDirectory=/opt/uptime-app
EnvironmentFile=/opt/uptime-app/.env
ExecStart=/usr/bin/python3 /opt/uptime-app/app.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/uptime-app

[Install]
WantedBy=multi-user.target
SERVICEEOF

# Start it
systemctl daemon-reload
systemctl enable uptime-app
systemctl start uptime-app

echo "App started"
