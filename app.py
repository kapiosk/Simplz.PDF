from flask import Flask, request, Response, send_file
from playwright.sync_api import sync_playwright
import io

app = Flask(__name__)

@app.route('/', methods=['GET'])
def index():
    return 'PostMe! PDF!!'

@app.route('/Test', methods=['GET'])
def test():
    with sync_playwright() as p:
        with p.chromium.launch() as browser:
            with browser.new_context(ignore_https_errors=True) as context:
                page = context.new_page()
                page.set_content('<p>Test</p>')
                data = page.pdf(format='A4', print_background=True)
                return Response(response=data, status=200, mimetype='application/pdf')

@app.route('/PDF', methods=['POST'])
def pdf():
    with sync_playwright() as p:
        with p.chromium.launch() as browser:
            with browser.new_context(ignore_https_errors=True) as context:
                page = context.new_page()
                page.set_content(request.get_data(as_text=True))
                data = page.pdf(format='A4', print_background=True)
                return Response(response=data, status=200, mimetype='application/pdf')

@app.route('/PDFURL', methods=['GET'])
def pdfFromURL():
    dataUrl = request.args['dataUrl']
    if dataUrl is not None:
        with sync_playwright() as p:
            with p.chromium.launch() as browser:
                page = browser.new_page()
                if 'Authorization' in request.headers:
                    authorization = request.headers['Authorization']
                    page.set_extra_http_headers({'Authorization': f'Bearer {authorization}'})
                landscape = False
                if 'landscape' in request.headers:
                    landscape = True
                page.goto(dataUrl)
                page.wait_for_load_state('networkidle')
                data = page.pdf(format='A4', print_background=True, landscape=landscape)
                return Response(response=data, status=200, mimetype='application/pdf')

@app.route('/PDFToImage', methods=['GET'])
def pdfToImage():
    dataUrl = request.args['dataUrl']
    if dataUrl is not None:
        with sync_playwright() as p:
            with p.chromium.launch() as browser:
                page = browser.new_page()
                page.goto(dataUrl)
                page.wait_for_load_state('networkidle')
                screenshot = page.screenshot(full_page=True)
                img_byte_arr = io.BytesIO(screenshot)
                img_byte_arr.seek(0)
                return send_file(img_byte_arr, mimetype='image/png')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5501)
