#!/usr/bin/env bash

set -e

cat >server.py <<EOF
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import uuid

class MyHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        rqst_uuid = str(uuid.uuid4())

        resp = {"tier": "db", "request": rqst_uuid, "data": "abc123"}

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