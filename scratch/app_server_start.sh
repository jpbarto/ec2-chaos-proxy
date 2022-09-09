#!/usr/bin/env bash

set -e

cat >server.py <<EOF
from http.server import HTTPServer, BaseHTTPRequestHandler
from http.client import HTTPConnection
import json
import uuid

db_host = "10.0.1.92"

class MyHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        db = HTTPConnection(db_host, 80, timeout=2)
        rqst_uuid = str(uuid.uuid4())

        db.request("GET","/")

        db_resp = db.getresponse()
        db_data = json.loads(db_resp.read().decode("utf-8"))

        resp = {"tier": "app", "request": rqst_uuid, "downstream": db_data}

        # send 200 response
        self.send_response(200)
        # send response headers
        self.end_headers()
        # send the body of the response
        self.wfile.write(bytes(json.dumps(resp), "utf-8"))

httpd = HTTPServer(('0.0.0.0', 80), MyHandler)
httpd.serve_forever()
EOF

nohup python3 server.py 2>server-err.log 1>server.log &