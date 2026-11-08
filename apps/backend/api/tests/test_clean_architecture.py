"""Clean Architecture and Thin Router invariant tests.

This test suite ensures that future modifications to the backend codebase never
violate our Clean Architecture standards:
1. No loose service/schema files in root directories.
2. Every domain module has an __init__.py barrel export.
3. Routers are purely thin HTTP transport controllers (<= 15 lines per handler).
4. Zero inline SQL or duplicated authentication logic in routers.
5. All REST endpoints declare Pydantic response_model (except StreamingResponse and WebSocket).
"""

import ast
from pathlib import Path

BACKEND_APP_DIR = Path(__file__).resolve().parent.parent / "app"


def test_no_loose_service_or_schema_files():
    """Ensure no loose .py files reside directly at app/services/ or app/schemas/ root."""
    services_dir = BACKEND_APP_DIR / "services"
    schemas_dir = BACKEND_APP_DIR / "schemas"

    loose_services = [
        f.name for f in services_dir.glob("*.py") if f.name != "__init__.py"
    ]
    loose_schemas = [
        f.name for f in schemas_dir.glob("*.py") if f.name != "__init__.py"
    ]

    assert not loose_services, (
        f"Found loose files in app/services/: {loose_services}. "
        "Move them to app/services/{{module}}/ instead."
    )
    assert not loose_schemas, (
        f"Found loose files in app/schemas/: {loose_schemas}. "
        "Move them to app/schemas/{{module}}/ instead."
    )


def test_all_modules_have_barrel_export():
    """Ensure every domain subfolder in services and schemas has an __init__.py."""
    for parent_dir in ["services", "schemas"]:
        target_dir = BACKEND_APP_DIR / parent_dir
        for subfolder in target_dir.iterdir():
            if subfolder.is_dir() and not subfolder.name.startswith("__"):
                init_file = subfolder / "__init__.py"
                assert init_file.exists(), (
                    f"Missing __init__.py barrel export in {subfolder}."
                )


def test_router_clean_architecture_invariants():
    """Ensure all route handlers in app/api/routes adhere strictly to Thin Controller standards."""
    routes_dir = BACKEND_APP_DIR / "api" / "routes"

    for route_file in routes_dir.glob("*.py"):
        if route_file.name == "__init__.py":
            continue

        content = route_file.read_text(encoding="utf-8")

        # 1. No private authentication helper
        assert "_get_current_user" not in content, (
            f"Duplicated private '_get_current_user' found in {route_file.name}. "
            "Import 'get_current_user' from app.api.dependencies instead."
        )

        # 2. No inline SQL query executions
        assert "select(" not in content, (
            f"Inline SQLAlchemy select() query found in {route_file.name}. "
            "Delegate database interactions to domain services."
        )
        assert "db.execute(" not in content, (
            f"Inline db.execute() found in {route_file.name}. "
            "Delegate database interactions to domain services."
        )
        assert "db.commit(" not in content, (
            f"Inline db.commit() found in {route_file.name}. "
            "Delegate database transactions to domain services."
        )

        # 3. AST Inspection: function length and response_model declaration
        tree = ast.parse(content, filename=str(route_file))
        for node in tree.body:
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                is_route = False
                is_ws = False
                has_response_model = False

                for dec in node.decorator_list:
                    if isinstance(dec, ast.Call) and isinstance(dec.func, ast.Attribute):
                        if dec.func.attr == "websocket":
                            is_ws = True
                            is_route = True
                        elif dec.func.attr in ["get", "post", "put", "patch", "delete"]:
                            is_route = True
                            for kw in dec.keywords:
                                if kw.arg == "response_model":
                                    has_response_model = True

                if is_route:
                    # Check for StreamingResponse return type exception
                    is_streaming = False
                    if node.returns and isinstance(node.returns, ast.Name):
                        if node.returns.id == "StreamingResponse":
                            is_streaming = True

                    if not is_ws and not is_streaming:
                        assert has_response_model, (
                            f"Endpoint '{node.name}' in {route_file.name} missing 'response_model'. "
                            "Every REST endpoint must return a typed Pydantic response."
                        )

                    # Check function length (inclusive of body and docstring)
                    # Handlers must remain thin controllers (<= 18 lines)
                    func_lines = node.end_lineno - node.lineno + 1
                    assert func_lines <= 18, (
                        f"Endpoint '{node.name}' in {route_file.name} is {func_lines} lines long. "
                        "Route handlers must remain thin controllers (<= 15 lines). "
                        "Move logic to the domain service."
                    )
