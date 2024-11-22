from flask import Flask, request, send_from_directory, jsonify, abort
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
from werkzeug.utils import secure_filename
import socket
import os
from datetime import datetime

class Config:
    SQLALCHEMY_DATABASE_URI = os.getenv(
        'DATABASE_URL',
        'postgresql://root:sa-hw4-88@192.168.88.1:5432/sa-hw4'
    )
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    UPLOAD_FOLDER = os.path.join(os.getcwd(), 'uploads')
    MAX_CONTENT_LENGTH = 16 * 1024 * 1024  # 16 MB

app = Flask(__name__)
app.config.from_object(Config)

CORS(app)

db = SQLAlchemy(app)

if not os.path.exists(app.config['UPLOAD_FOLDER']):
    os.makedirs(app.config['UPLOAD_FOLDER'])

class User(db.Model):
    __tablename__ = 'user'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), unique=True, nullable=False)
    age = db.Column(db.Integer, nullable=False)
    birthday = db.Column(db.Date, nullable=False)
    
    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'age': self.age,
            'birthday': self.birthday.strftime('%Y-%m-%d')
        }

@app.route('/ip', methods=['GET'])
def get_ip():
    hostname = socket.gethostname()
    try:
        ip_address = socket.gethostbyname(hostname)
    except socket.gaierror:
        ip_address = 'Unable to retrieve IP address'
    return jsonify({'ip': ip_address, 'hostname': hostname}), 200

@app.route('/file/<string:filename>', methods=['GET'])
def get_file(filename):
    try:
        return send_from_directory(directory=app.config['UPLOAD_FOLDER'], path=filename, as_attachment=True)
    except FileNotFoundError:
        abort(404, description=f"File '{filename}' not found")

@app.route('/upload', methods=['POST'])
def upload_file():
    if 'file' not in request.files:
        return jsonify({'error': 'No file part in the request'}), 400
    
    file = request.files['file']
    
    if file.filename == '':
        return jsonify({'error': 'No file selected'}), 400
    
    filename = secure_filename(file.filename)
    file_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    file.save(file_path)
    
    return jsonify({'filename': filename, 'success': True}), 200

@app.route('/db/<string:name>', methods=['GET'])
def get_user(name):
    user = User.query.filter_by(name=name).first()
    if user is None:
        return jsonify({'error': f"User '{name}' not found"}), 404
    return jsonify(user.to_dict()), 200

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    
    app.run(host='192.168.88.1', port=8080, debug=True)
