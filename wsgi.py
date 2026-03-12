from app import app
# uvicorn wsgi:app --host 0.0.0.0 --port 5501 --workers 1
# Note: Use --workers 1 since browser is shared, or implement proper browser pool for multiple workers
