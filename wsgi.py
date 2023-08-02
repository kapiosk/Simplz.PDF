from app import app
# gunicorn --bind 0.0.0.0:5501 wsgi:app
if __name__ == "__main__":
    app.run()
