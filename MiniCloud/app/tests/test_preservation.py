"""
Preservation Property Tests — Task 2
=====================================
These tests MUST PASS on UNFIXED code.
They capture baseline behavior that must be preserved after the fix.

Property A: GET /api/hello always returns HTTP 200 with correct payload
            regardless of DB state.

Property B: _read_db_password_secret() with any valid (non-empty) secret
            content returns the stripped value without raising an exception.

Property C: Configuration of unrelated services (db, web, proxy, storage,
            monitoring, loki, grafana, dns) in docker-compose.yml does not
            change after the fix — verified by parsing YAML and asserting
            important keys are still present.

Property D: Module `src` can be imported without side effects at module-level
            (get_db_connection() is NOT called on import).

Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5
"""

import os
import sys
import pathlib
import pytest
from unittest.mock import patch, MagicMock, call

from hypothesis import given, settings, HealthCheck
from hypothesis import strategies as st

# ---------------------------------------------------------------------------
# Path setup — ensure MiniCloud/app/src is importable
# ---------------------------------------------------------------------------
WORKSPACE_ROOT = pathlib.Path(__file__).resolve().parents[3]  # repo root
APP_DIR = WORKSPACE_ROOT / "MiniCloud" / "app"
if str(APP_DIR) not in sys.path:
    sys.path.insert(0, str(APP_DIR))

COMPOSE_FILE = WORKSPACE_ROOT / "MiniCloud" / "docker-compose.yml"

# ---------------------------------------------------------------------------
# Snapshot of unrelated service keys to preserve (Property C)
# ---------------------------------------------------------------------------
UNRELATED_SERVICES = ["db", "web", "proxy", "storage", "monitoring", "loki", "grafana", "dns"]

# Important top-level keys that must remain present for each service
REQUIRED_SERVICE_KEYS = {
    "db":         ["image", "networks", "secrets", "environment", "healthcheck"],
    "web":        ["build", "networks", "healthcheck"],
    "proxy":      ["image", "networks", "volumes", "healthcheck", "depends_on"],
    "storage":    ["image", "networks", "secrets", "environment", "healthcheck"],
    "monitoring": ["image", "networks", "healthcheck"],
    "loki":       ["image", "networks", "healthcheck"],
    "grafana":    ["image", "networks", "healthcheck"],
    "dns":        ["build", "networks", "volumes", "healthcheck"],
}


# ===========================================================================
# Property A — /api/hello always returns HTTP 200 with correct payload
# ===========================================================================

class TestPropertyA_HelloEndpoint:
    """
    **Validates: Requirements 3.1**

    For any HTTP GET request to /api/hello, the response SHALL always be
    HTTP 200 with payload {"message": "Hello from Modular App Server!"},
    regardless of DB state.

    EXPECTED ON UNFIXED CODE: PASS (baseline behavior to preserve)
    """

    @pytest.fixture
    def client(self):
        from src import create_app
        app = create_app()
        app.config["TESTING"] = True
        with app.test_client() as c:
            yield c

    def test_hello_returns_200_with_correct_payload(self, client):
        """Basic unit test: /api/hello returns 200 with correct JSON."""
        response = client.get("/api/hello")
        assert response.status_code == 200
        data = response.get_json()
        assert data == {"message": "Hello from Modular App Server!"}

    def test_hello_returns_200_when_db_unavailable(self, client):
        """
        /api/hello must return 200 even when get_db_connection() would fail.
        The hello route does not call get_db_connection() at all.
        """
        with patch("src.routes.get_db_connection", side_effect=RuntimeError("DB down")):
            response = client.get("/api/hello")
        assert response.status_code == 200
        data = response.get_json()
        assert data == {"message": "Hello from Modular App Server!"}

    @given(
        # Vary query string params — should not affect the response
        params=st.dictionaries(
            keys=st.text(min_size=1, max_size=10, alphabet=st.characters(whitelist_categories=("Lu", "Ll", "Nd"))),
            values=st.text(max_size=20, alphabet=st.characters(whitelist_categories=("Lu", "Ll", "Nd"))),
            max_size=5,
        )
    )
    @settings(max_examples=30, suppress_health_checks=[HealthCheck.function_scoped_fixture])
    def test_hello_always_200_regardless_of_query_params(self, params, client):
        """
        **Validates: Requirements 3.1**

        Property A: For any query parameters, GET /api/hello SHALL return
        HTTP 200 with the exact expected payload.
        """
        query_string = "&".join(f"{k}={v}" for k, v in params.items())
        url = f"/api/hello?{query_string}" if query_string else "/api/hello"
        response = client.get(url)
        assert response.status_code == 200
        data = response.get_json()
        assert data == {"message": "Hello from Modular App Server!"}


# ===========================================================================
# Property B — _read_db_password_secret() returns stripped value for valid input
# ===========================================================================

class TestPropertyB_ReadDbPasswordSecret:
    """
    **Validates: Requirements 3.2**

    For any valid (non-empty) secret file content, _read_db_password_secret()
    SHALL return the stripped value without raising an exception.

    EXPECTED ON UNFIXED CODE: PASS (baseline behavior to preserve)
    """

    @given(
        content=st.text(min_size=1, max_size=200).filter(lambda s: s.strip() != "")
    )
    @settings(max_examples=50, suppress_health_checks=[HealthCheck.function_scoped_fixture])
    def test_read_secret_returns_stripped_value(self, content):
        """
        **Validates: Requirements 3.2**

        Property B: For any non-empty secret file content, _read_db_password_secret()
        SHALL return content.strip() and SHALL NOT raise any exception.
        """
        from src.database import _read_db_password_secret

        mock_open = MagicMock()
        mock_open.return_value.__enter__ = MagicMock(return_value=MagicMock(read=MagicMock(return_value=content)))
        mock_open.return_value.__exit__ = MagicMock(return_value=False)

        with patch("os.path.exists", return_value=True), \
             patch("builtins.open", mock_open):
            result = _read_db_password_secret()

        assert result == content.strip(), (
            f"Expected stripped value {content.strip()!r}, got {result!r}"
        )

    def test_read_secret_with_trailing_newline(self):
        """Common case: secret file has trailing newline — must be stripped."""
        from src.database import _read_db_password_secret

        content = "my_password\n"
        mock_open = MagicMock()
        mock_open.return_value.__enter__ = MagicMock(return_value=MagicMock(read=MagicMock(return_value=content)))
        mock_open.return_value.__exit__ = MagicMock(return_value=False)

        with patch("os.path.exists", return_value=True), \
             patch("builtins.open", mock_open):
            result = _read_db_password_secret()

        assert result == "my_password"

    def test_read_secret_with_whitespace_padding(self):
        """Secret file with surrounding whitespace — must be stripped."""
        from src.database import _read_db_password_secret

        content = "  secret123  \n"
        mock_open = MagicMock()
        mock_open.return_value.__enter__ = MagicMock(return_value=MagicMock(read=MagicMock(return_value=content)))
        mock_open.return_value.__exit__ = MagicMock(return_value=False)

        with patch("os.path.exists", return_value=True), \
             patch("builtins.open", mock_open):
            result = _read_db_password_secret()

        assert result == "secret123"


# ===========================================================================
# Property C — Unrelated service configs in docker-compose.yml unchanged
# ===========================================================================

class TestPropertyC_UnrelatedServicesPreserved:
    """
    **Validates: Requirements 3.3, 3.4**

    Configuration of unrelated services (db, web, proxy, storage, monitoring,
    loki, grafana, dns) in docker-compose.yml SHALL not change after the fix.
    Verified by parsing YAML and asserting important keys are still present.

    EXPECTED ON UNFIXED CODE: PASS (baseline behavior to preserve)
    """

    @pytest.fixture(scope="class")
    def compose(self):
        import yaml
        with open(COMPOSE_FILE, "r", encoding="utf-8") as f:
            return yaml.safe_load(f)

    def test_all_unrelated_services_present(self, compose):
        """All unrelated services must exist in docker-compose.yml."""
        services = compose.get("services", {})
        for svc in UNRELATED_SERVICES:
            assert svc in services, f"Service '{svc}' is missing from docker-compose.yml"

    @pytest.mark.parametrize("service", UNRELATED_SERVICES)
    def test_service_required_keys_present(self, compose, service):
        """Each unrelated service must retain its important configuration keys."""
        svc_config = compose["services"][service]
        required_keys = REQUIRED_SERVICE_KEYS.get(service, [])
        for key in required_keys:
            assert key in svc_config, (
                f"Service '{service}' is missing required key '{key}' in docker-compose.yml"
            )

    def test_db_service_image_unchanged(self, compose):
        """db service must use mariadb:10.11 image."""
        assert compose["services"]["db"]["image"] == "mariadb:10.11"

    def test_db_service_secrets_unchanged(self, compose):
        """db service must still mount db_password and db_root_password secrets."""
        db_secrets = compose["services"]["db"].get("secrets", [])
        assert "db_password" in db_secrets
        assert "db_root_password" in db_secrets

    def test_proxy_service_image_unchanged(self, compose):
        """proxy service must use nginx:alpine image."""
        assert compose["services"]["proxy"]["image"] == "nginx:alpine"

    def test_storage_service_image_unchanged(self, compose):
        """storage service must use minio/minio image."""
        assert compose["services"]["storage"]["image"] == "minio/minio"

    def test_monitoring_service_image(self, compose):
        """monitoring service must use prom/prometheus:latest image."""
        assert compose["services"]["monitoring"]["image"] == "prom/prometheus:latest"

    def test_loki_service_image(self, compose):
        """loki service must use grafana/loki:latest image."""
        assert compose["services"]["loki"]["image"] == "grafana/loki:latest"

    def test_grafana_service_image(self, compose):
        """grafana service must use grafana/grafana:latest image."""
        assert compose["services"]["grafana"]["image"] == "grafana/grafana:latest"

    def test_networks_structure_preserved(self, compose):
        """Top-level networks (frontend-net, backend-net, mgmt-net) must be present."""
        networks = compose.get("networks", {})
        for net in ["frontend-net", "backend-net", "mgmt-net"]:
            assert net in networks, f"Network '{net}' is missing from docker-compose.yml"

    def test_secrets_structure_preserved(self, compose):
        """Top-level secrets must all be present."""
        secrets = compose.get("secrets", {})
        for secret in ["db_root_password", "db_password", "kc_admin_password",
                       "storage_root_user", "storage_root_pass"]:
            assert secret in secrets, f"Secret '{secret}' is missing from docker-compose.yml"

    @given(
        service=st.sampled_from(UNRELATED_SERVICES)
    )
    @settings(max_examples=20, suppress_health_checks=[HealthCheck.function_scoped_fixture])
    def test_unrelated_service_has_healthcheck(self, service):
        """
        **Validates: Requirements 3.3, 3.4**

        Property C: For any unrelated service, the healthcheck configuration
        SHALL remain present in docker-compose.yml.
        """
        import yaml
        with open(COMPOSE_FILE, "r", encoding="utf-8") as f:
            compose = yaml.safe_load(f)

        svc_config = compose["services"][service]
        assert "healthcheck" in svc_config, (
            f"Service '{service}' lost its healthcheck configuration"
        )


# ===========================================================================
# Property D — Module src imports without side effects
# ===========================================================================

class TestPropertyD_ModuleImportNoSideEffects:
    """
    **Validates: Requirements 3.5**

    Module `src` SHALL be importable without side effects at module-level.
    Specifically, get_db_connection() must NOT be called during import.

    EXPECTED ON UNFIXED CODE: PASS (baseline behavior to preserve)
    """

    def test_import_src_does_not_call_get_db_connection(self):
        """
        **Validates: Requirements 3.5**

        Property D: Importing src (or create_app) must not trigger any call
        to get_db_connection() at module level.
        """
        # We track calls to get_db_connection during import
        call_count = []

        original_get_db = None

        # Force reimport by removing cached modules
        modules_to_remove = [k for k in sys.modules if k.startswith("src")]
        for mod in modules_to_remove:
            sys.modules.pop(mod, None)

        with patch("src.database.get_db_connection", side_effect=lambda: call_count.append(1)) as mock_db:
            # Import the module — this should NOT call get_db_connection
            import src
            from src import create_app

        assert len(call_count) == 0, (
            f"SIDE EFFECT DETECTED — get_db_connection() was called {len(call_count)} "
            "time(s) during module import. It must only be called lazily (inside route handlers)."
        )

    def test_create_app_does_not_call_get_db_connection(self):
        """
        Calling create_app() itself must not trigger get_db_connection().
        """
        call_count = []

        # Remove cached modules to ensure fresh import
        modules_to_remove = [k for k in sys.modules if k.startswith("src")]
        for mod in modules_to_remove:
            sys.modules.pop(mod, None)

        with patch("src.database.get_db_connection", side_effect=lambda: call_count.append(1)):
            from src import create_app
            app = create_app()

        assert len(call_count) == 0, (
            f"SIDE EFFECT DETECTED — get_db_connection() was called {len(call_count)} "
            "time(s) during create_app(). It must only be called inside route handlers."
        )

    def test_import_src_succeeds_without_secret_file(self):
        """
        Module import must succeed even when /run/secrets/db_password does not exist.
        This confirms there are no module-level DB calls.
        """
        modules_to_remove = [k for k in sys.modules if k.startswith("src")]
        for mod in modules_to_remove:
            sys.modules.pop(mod, None)

        with patch("os.path.exists", return_value=False):
            try:
                from src import create_app
                app = create_app()
            except RuntimeError as exc:
                pytest.fail(
                    f"SIDE EFFECT DETECTED — Importing src raised RuntimeError: {exc}. "
                    "This means get_db_connection() or _read_db_password_secret() is being "
                    "called at module level."
                )
            except Exception as exc:
                # ConnectionError or other DB errors are also side effects
                if "secret" in str(exc).lower() or "db_password" in str(exc).lower():
                    pytest.fail(
                        f"SIDE EFFECT DETECTED — Importing src raised {type(exc).__name__}: {exc}"
                    )
                # Other exceptions (e.g. import errors for mysql) are acceptable
