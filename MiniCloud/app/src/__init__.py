from flask import Flask
from flask_oidc import OpenIDConnect

# Khởi tạo đối tượng OIDC
oidc = OpenIDConnect()

def create_app():
    app = Flask(__name__)
    
    # Cấu hình Secret Key cho Session (bắt buộc khi dùng xác thực)
    app.config['SECRET_KEY'] = 'khoa_bi_mat_cho_session_flask'
    # Trỏ tới file JSON vừa tạo
    app.config['OIDC_CLIENT_SECRETS'] = 'client_secrets.json'
    
    # --- THÊM DÒNG NÀY ĐỂ FIX LỖI ISSUER MISMATCH TRONG DOCKER ---
    app.config['OIDC_VALIDATE_ISSUER'] = False
    # Gắn OIDC vào app
    oidc.init_app(app)
    
    # Import và đăng ký các route
    from .routes import api_bp
    app.register_blueprint(api_bp)
    
    return app