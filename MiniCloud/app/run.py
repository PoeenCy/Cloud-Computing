from src import create_app

app = create_app()

if __name__ == '__main__':
    # Khởi động app Flask trên port 8081
    app.run(host='0.0.0.0', port=8081)
