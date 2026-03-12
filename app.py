from fastapi import FastAPI, Request, HTTPException, Header, Query
from fastapi.responses import StreamingResponse, JSONResponse, PlainTextResponse
from playwright.async_api import async_playwright
import io
import logging
from contextlib import asynccontextmanager

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

_playwright = None
_browser = None

async def get_browser():
    global _playwright, _browser
    if _browser is None or not _browser.is_connected():
        if _playwright is None:
            _playwright = await async_playwright().start()
        _browser = await _playwright.chromium.launch()
    return _browser

async def cleanup():
    global _playwright, _browser
    if _browser:
        await _browser.close()
    if _playwright:
        await _playwright.stop()

@asynccontextmanager
async def lifespan(app: FastAPI):
    yield
    await cleanup()

app = FastAPI(lifespan=lifespan)

@app.get('/')
async def index():
    return PlainTextResponse('PostMe! PDF!!')

@app.get('/health')
async def health():
    return JSONResponse(content={'status': 'ok'})

@app.get('/Test')
async def test():
    try:
        browser = await get_browser()
        context = await browser.new_context(ignore_https_errors=True)
        try:
            page = await context.new_page()
            await page.set_content('<p>Test</p>')
            data = await page.pdf(format='A4', print_background=True)
            return StreamingResponse(
                io.BytesIO(data),
                media_type='application/pdf',
                headers={'Content-Disposition': 'inline; filename="test.pdf"'}
            )
        finally:
            await context.close()
    except Exception as e:
        logger.error(f"Error in /Test: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post('/PDF')
async def pdf(request: Request):
    try:
        content = await request.body()
        html_content = content.decode('utf-8')
        
        browser = await get_browser()
        context = await browser.new_context(ignore_https_errors=True)
        try:
            page = await context.new_page()
            await page.set_content(html_content)
            data = await page.pdf(format='A4', print_background=True)
            return StreamingResponse(
                io.BytesIO(data),
                media_type='application/pdf',
                headers={'Content-Disposition': 'inline; filename="document.pdf"'}
            )
        finally:
            await context.close()
    except Exception as e:
        logger.error(f"Error in /PDF: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get('/PDFURL')
async def pdf_from_url(
    dataUrl: str = Query(..., description="URL to convert to PDF"),
    authorization: str = Header(None),
    landscape: bool = Header(False)
):
    if not dataUrl:
        raise HTTPException(status_code=400, detail="Missing dataUrl parameter")

    try:
        browser = await get_browser()
        context = await browser.new_context(ignore_https_errors=True)
        try:
            page = await context.new_page()
            if authorization:
                await page.set_extra_http_headers({'Authorization': f'Bearer {authorization}'})
            await page.goto(dataUrl, timeout=30000)
            await page.wait_for_load_state('networkidle', timeout=30000)
            data = await page.pdf(format='A4', print_background=True, landscape=landscape)
            return StreamingResponse(
                io.BytesIO(data),
                media_type='application/pdf',
                headers={'Content-Disposition': 'inline; filename="document.pdf"'}
            )
        finally:
            await context.close()
    except Exception as e:
        logger.error(f"Error in /PDFURL: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get('/PDFToImage')
async def pdf_to_image(
    dataUrl: str = Query(..., description="URL to convert to image"),
    authorization: str = Header(None)
):
    if not dataUrl:
        raise HTTPException(status_code=400, detail="Missing dataUrl parameter")

    try:
        browser = await get_browser()
        context = await browser.new_context(ignore_https_errors=True)
        try:
            page = await context.new_page()
            if authorization:
                await page.set_extra_http_headers({'Authorization': f'Bearer {authorization}'})
            await page.goto(dataUrl, timeout=30000)
            await page.wait_for_load_state('networkidle', timeout=30000)
            screenshot = await page.screenshot(full_page=True)
            img_byte_arr = io.BytesIO(screenshot)
            img_byte_arr.seek(0)
            return StreamingResponse(
                img_byte_arr,
                media_type='image/png',
                headers={'Content-Disposition': 'inline; filename="screenshot.png"'}
            )
        finally:
            await context.close()
    except Exception as e:
        logger.error(f"Error in /PDFToImage: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == '__main__':
    import uvicorn
    uvicorn.run(app, host='0.0.0.0', port=5501)
