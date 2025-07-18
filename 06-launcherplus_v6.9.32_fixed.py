#!/usr/bin/env python3
import os
import sys
from flask import Flask, request, render_template_string

app = Flask(__name__)

HTML_TEMPLATE = """
<!doctype html>
<title>Cursor Web UI</title>
<h1>Welcome to Cursor Web Interface</h1>
<form method="post">
<input name="command" placeholder="Enter command">
<button type="submit">Run</button>
</form>
<pre>{{ output }}</pre>
"""

@app.route("/", methods=["GET", "POST"])
def index():
    output = ""
    if request.method == "POST":
        command = request.form.get("command", "")
        try:
            output = "Command execution disabled for security."
        except Exception as e:
            output = str(e)
    return render_template_string(HTML_TEMPLATE, output=output)

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=8080)  # Changed to localhost for security

