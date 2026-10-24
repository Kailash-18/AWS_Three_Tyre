#!/bin/bash
dnf update -y
dnf install -y python3-pip
pip3 install flask pymysql
cat << 'EOF' > /opt/app.py
from flask import Flask, jsonify
app = Flask(__name__)
@app.route("/health")
def health():
    return jsonify({"status": "ok"})
@app.route("/api/data")
def data():
    return jsonify({"message": "Hello from 3-Tier Backend API"})
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
EOF
nohup python3 /opt/app.py > /var/log/backend.log 2>&1 &
