import time
from prometheus_client import Summary, make_asgi_app
from starlette.middleware.base import BaseHTTPMiddleware, DispatchFunction

metrics_app = make_asgi_app()
REQUESTS_PROCESSING_TIME = Summary(
    name="requests_processing_time",
    documentation="requests_processing_time",
    labelnames=["method", "path", "app_name"],
)


class PrometheusMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, app_name) -> None:
        super().__init__(app)
        self.app_name = app_name

    async def dispatch(self, request, call_next):
        method = request.method
        path = request.url.path
        before_time = time.perf_counter_ns()
        response = await call_next(request)
        after_time = time.perf_counter_ns()
        latent_time = (after_time - before_time) / 1e6
        REQUESTS_PROCESSING_TIME.labels(
            method=method, path=path, app_name=self.app_name
        ).observe(latent_time)
        return response

