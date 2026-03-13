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
                <style>
                    body {{
                        font-family: Arial, sans-serif;
                        max-width: 800px;
                        margin: 50px auto;
                        padding: 20px;
                        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                        color: white;
                    }}
                    .card {{
                        background: rgba(255, 255, 255, 0.1);
                        padding: 30px;
                        border-radius: 10px;
                        backdrop-filter: blur(10px);
                    }}
                    h1 {{ margin-top: 0; }}
                    .info {{ 
                        background: rgba(0, 0, 0, 0.2);
                        padding: 15px;
                        border-radius: 5px;
                        margin: 10px 0;
                    }}
                    .status {{ color: #4ade80; font-weight: bold; }}
                </style>
            </head>
            <body>
                <div class="card">
                    <h1>The Illusion of 100% Uptime</h1>
                    <p class="status">✓ Service is healthy</p>
                    <div class="info">
                        <strong>Instance:</strong> {instance_name}<br>
                        <strong>Zone:</strong> {zone}<br>
                        <strong>Hostname:</strong> {hostname}<br>
                        <strong>Time:</strong> {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
                    </div>
                    <p>This request is being served by one of several instances behind a load balancer. 
                    If this instance fails, the load balancer will automatically route your next request to a healthy one.</p>
                    <p><em>Refresh a few times to see different instances!</em></p>
                </div>
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
chown -R appuser:appuser /opt/uptime-appopt/uptime-app/.env
echo "export ZONE=$ZONE" >> /opt/uptime-app/.env
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
     appuser
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
ReadWritePaths=/opt/uptime-app/health {
        proxy_pass http://127.0.0.1:8080/health;
        access_log off;
    }
}
NGINXEOF

ln -sf /etc/nginx/sites-available/uptime-app /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx
# Set env vars
echo "export INSTANCE_NAME=$INSTANCE_NAME" >> /etc/environment
echo "export ZONE=$ZONE" >> /etc/environment

# Create systemd service
cat > /etc/systemd/system/uptime-app.service << 'SERVICEEOF'
[Unit]
Description=Uptime Demo Application
After=network.target

[Service]
Type=simple
User=root
EnvironmentFile=/etc/environment
ExecStart=/usr/bin/python3 /opt/uptime-app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICEEOF

# Start it
systemctl daemon-reload
systemctl enable uptime-app
systemctl start uptime-app

echo "App started"
