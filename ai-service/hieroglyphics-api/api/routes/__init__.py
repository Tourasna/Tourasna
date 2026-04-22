"""
Public router exports.

main.py imports these and registers them under the /api prefix.
"""
from api.routes.health import router as health_router
from api.routes.signs import router as signs_router
from api.routes.translate import router as translate_router

__all__ = ["health_router", "signs_router", "translate_router"]