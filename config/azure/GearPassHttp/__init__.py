import azure.functions as func

from main import app

middleware = func.AsgiMiddleware(app)


async def main(req: func.HttpRequest, context: func.Context) -> func.HttpResponse:
    return await middleware.handle_async(req, context)
