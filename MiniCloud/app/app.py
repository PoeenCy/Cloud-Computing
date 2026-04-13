from flask import Flask, jsonify
import json

app = Flask(__name__)

# Route này đã được sửa thêm tiền tố /api/ để pass healthcheck của Nhã
@app.get("/api/hello")
def hello(): 
    return jsonify(message="Hello from App Server!")

@app.get("/api/student")
def student():
    with open("students.json") as f:
        data = json.load(f)
    return jsonify(data)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8081)