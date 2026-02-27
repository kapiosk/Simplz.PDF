from flask import Flask, request, Response, send_file, jsonify
from playwright.sync_api import sync_playwright
import io
import logging
import atexit

app = Flask(__name__)

# Configure logging
logging.basicConfig(level=logging.INFO)

_playwright = None
_browser = None

def get_browser():
    global _playwright, _browser
    if _browser is None or not _browser.is_connected():
        if _playwright is None:
            _playwright = sync_playwright().start()
        _browser = _playwright.chromium.launch()
    return _browser

def _cleanup():
    global _playwright, _browser
    if _browser:
        _browser.close()
    if _playwright:
        _playwright.stop()

atexit.register(_cleanup)

@app.route('/', methods=['GET'])
def index():
    return 'PostMe! PDF!!'

@app.route('/health', methods=['GET'])
def health():
    return jsonify(status='ok'), 200

@app.route('/Test', methods=['GET'])
def test():
    try:
        browser = get_browser()
        with browser.new_context(ignore_https_errors=True) as context:
            page = context.new_page()
            page.set_content('<p>Test</p>')
            data = page.pdf(format='A4', print_background=True)
            return Response(response=data, status=200, mimetype='application/pdf')
    except Exception as e:
        logging.error(f"Error in /Test: {e}")
        return jsonify(error=str(e)), 500

@app.route('/PDF', methods=['POST'])
def pdf():
    try:
        browser = get_browser()
        with browser.new_context(ignore_https_errors=True) as context:
            page = context.new_page()
            page.set_content(request.get_data(as_text=True))
            data = page.pdf(format='A4', print_background=True)
            return Response(response=data, status=200, mimetype='application/pdf')
    except Exception as e:
        logging.error(f"Error in /PDF: {e}")
        return jsonify(error=str(e)), 500

@app.route('/PDFURL', methods=['GET'])
def pdfFromURL():
    dataUrl = request.args.get('dataUrl')
    if not dataUrl:
        return jsonify(error="Missing dataUrl parameter"), 400

    try:
        browser = get_browser()
        with browser.new_context(ignore_https_errors=True) as context:
            page = context.new_page()
            if 'Authorization' in request.headers:
                authorization = request.headers['Authorization']
                page.set_extra_http_headers({'Authorization': f'Bearer {authorization}'})
            landscape = request.headers.get('landscape', 'false').lower() == 'true'
            page.goto(dataUrl, timeout=30000)
            page.wait_for_load_state('networkidle', timeout=30000)
            data = page.pdf(format='A4', print_background=True, landscape=landscape)
            return Response(response=data, status=200, mimetype='application/pdf')
    except Exception as e:
        logging.error(f"Error in /PDFURL: {e}")
        return jsonify(error=str(e)), 500

@app.route('/PDFToImage', methods=['GET'])
def pdfToImage():
    dataUrl = request.args.get('dataUrl')
    if not dataUrl:
        return jsonify(error="Missing dataUrl parameter"), 400

    try:
        browser = get_browser()
        with browser.new_context(ignore_https_errors=True) as context:
            page = context.new_page()
            if 'Authorization' in request.headers:
                authorization = request.headers['Authorization']
                page.set_extra_http_headers({'Authorization': f'Bearer {authorization}'})
            page.goto(dataUrl, timeout=30000)
            page.wait_for_load_state('networkidle', timeout=30000)
            screenshot = page.screenshot(full_page=True)
            img_byte_arr = io.BytesIO(screenshot)
            img_byte_arr.seek(0)
            return send_file(img_byte_arr, mimetype='image/png')
    except Exception as e:
        logging.error(f"Error in /PDFToImage: {e}")
        return jsonify(error=str(e)), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5501)
