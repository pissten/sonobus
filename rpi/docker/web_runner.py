#!/usr/bin/env python3
import http.server
import socketserver
import urllib.parse
import os
import subprocess
import time
import signal
import sys

# Docker specific paths
PORT = int(os.environ.get("WEB_PORT", 8080))
CONFIG_FILE = "/opt/sonobus/config.env"
# Start script location inside container
START_SCRIPT = "/opt/sonobus/start_sonobus.sh"

sonobus_process = None

# HTML Template (Same as before)
HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>Sonobus Docker Config</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body {{ font-family: sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background: #2c3e50; color: #ecf0f1; }}
        .container {{ background: #34495e; padding: 30px; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.3); }}
        h1 {{ margin-top: 0; color: #3498db; }}
        .form-group {{ margin-bottom: 20px; }}
        label {{ display: block; margin-bottom: 5px; font-weight: bold; color: #bdc3c7; }}
        input[type="text"], input[type="password"] {{ width: 100%; padding: 10px; border: 1px solid #7f8c8d; border-radius: 4px; box-sizing: border-box; background: #ecf0f1; color: #2c3e50;}}
        button {{ background: #E74C3C; color: white; border: none; padding: 12px 24px; border-radius: 4px; cursor: pointer; font-size: 16px; width: 100%; transition: background 0.3s;}}
        button:hover {{ background: #c0392b; }}
        .status {{ padding: 15px; border-radius: 4px; margin-bottom: 20px; display: none; }}
        .success {{ background: #2ecc71; color: white; display: block; }}
        .footer {{ text-align: center; margin-top: 20px; font-size: 0.9em; color: #95a5a6; }}
    </style>
</head>
<body>
    <div class="container">
        <h1>Sonobus Docker</h1>
        
        {status_message}

        <form method="POST">
            <div class="form-group">
                <label for="SONOBUS_USER">Display Name</label>
                <input type="text" id="SONOBUS_USER" name="SONOBUS_USER" value="{user}" required>
            </div>
            
            <div class="form-group">
                <label for="SONOBUS_GROUP">Group Name</label>
                <input type="text" id="SONOBUS_GROUP" name="SONOBUS_GROUP" value="{group}" required>
            </div>

            <div class="form-group">
                <label for="SONOBUS_PASSWORD">Group Password</label>
                <input type="text" id="SONOBUS_PASSWORD" name="SONOBUS_PASSWORD" value="{password}">
            </div>

            <div class="form-group">
                <label for="SONOBUS_SERVER">Server (Optional)</label>
                <input type="text" id="SONOBUS_SERVER" name="SONOBUS_SERVER" value="{server}" placeholder="Default">
            </div>

            <button type="submit">Save and Restart Sonobus</button>
        </form>
    </div>
    <div class="footer">
        Running in Docker
    </div>
</body>
</html>
"""

def read_config():
    config = {
        "SONOBUS_USER": "",
        "SONOBUS_GROUP": "",
        "SONOBUS_PASSWORD": "",
        "SONOBUS_SERVER": ""
    }
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, 'r') as f:
            for line in f:
                if '=' in line and not line.startswith('#'):
                    key, value = line.strip().split('=', 1)
                    value = value.strip('"') # Remove quotes for UI display
                    if key in config:
                        config[key] = value
    return config

def write_config(data):
    lines = []
    lines.append("# Sonobus Docker Configuration")
    lines.append("# Edited by Web Interface at " + time.ctime())
    lines.append("")
    for key, value in data.items():
        # Escape quotes in value just in case
        safe_value = value.replace('"', '\\"')
        lines.append(f'{key}="{safe_value}"')
    
    with open(CONFIG_FILE, 'w') as f:
        f.write("\n".join(lines) + "\n")

def manage_sonobus_process(restart=False):
    global sonobus_process
    
    if restart and sonobus_process:
        print("Stopping Sonobus process...")
        sonobus_process.terminate()
        try:
            sonobus_process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            sonobus_process.kill()
        sonobus_process = None

    if not sonobus_process:
        print("Starting Sonobus process...")
        # We start the script directly
        try:
            sonobus_process = subprocess.Popen(["/bin/bash", START_SCRIPT], preexec_fn=os.setsid)
        except Exception as e:
            print(f"Failed to start Sonobus: {e}")

class ConfigHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        config = read_config()
        self.send_response(200)
        self.send_header("Content-type", "text/html")
        self.end_headers()
        
        status_html = ""
        hostname = socketserver.socket.gethostname()
        
        html = HTML_TEMPLATE.format(
            status_message=status_html,
            user=config.get("SONOBUS_USER", "DockerUser"),
            group=config.get("SONOBUS_GROUP", "DockerGroup"),
            password=config.get("SONOBUS_PASSWORD", ""),
            server=config.get("SONOBUS_SERVER", ""),
            hostname=hostname
        )
        self.wfile.write(html.encode('utf-8'))

    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length).decode('utf-8')
        params = urllib.parse.parse_qs(post_data)
        
        new_config = {
            "SONOBUS_USER": params.get("SONOBUS_USER", [""])[0],
            "SONOBUS_GROUP": params.get("SONOBUS_GROUP", [""])[0],
            "SONOBUS_PASSWORD": params.get("SONOBUS_PASSWORD", [""])[0],
            "SONOBUS_SERVER": params.get("SONOBUS_SERVER", [""])[0]
        }
        
        write_config(new_config)
        
        # Restart Process
        manage_sonobus_process(restart=True)
        
        self.send_response(200)
        self.send_header("Content-type", "text/html")
        self.end_headers()
        
        status_html = '<div class="status success">Settings saved! Sonobus restarted inside container.</div>'
        hostname = socketserver.socket.gethostname()
        
        html = HTML_TEMPLATE.format(
            status_message=status_html,
            user=new_config["SONOBUS_USER"],
            group=new_config["SONOBUS_GROUP"],
            password=new_config["SONOBUS_PASSWORD"],
            server=new_config["SONOBUS_SERVER"],
            hostname=hostname
        )
        self.wfile.write(html.encode('utf-8'))

if __name__ == "__main__":
    os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
    
    # Start Sonobus initially
    manage_sonobus_process()
    
    server = socketserver.TCPServer(("", PORT), ConfigHandler)
    print(f"Docker Controller serving at port {PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        if sonobus_process:
            sonobus_process.terminate()
    server.server_close()
