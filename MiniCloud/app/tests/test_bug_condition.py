"""
Bug Condition Exploration Tests — Task 1
========================================
These tests MUST FAIL on unfixed code. Failure confirms the bugs exist.

Sub-test A: Compose Config (Bug 1)
  - Asserts docker-compose.yml auth.environment does NOT contain KC_DB_PASSWORD
    or KEYCLOAK_ADMIN_PASSWORD (hardcoded values).
  - FAILS on unfixed code because both hardcoded keys still exist.

Sub-test B: Flask Secret Missing (Bug 2)
  - Calls get_db_connection() with /run/secrets/db_password mocked as missing.
  - Asserts ConnectionError is raised (not RuntimeError, not a crash).
  - FAILS on unfixed code because RuntimeError is raised instead.

Sub-test C: Route DB Failure (Bug 2)
  - Calls GET /api/student with get_db_connection mocked to raise ConnectionError.
  - Asserts HTTP 503 response.
  - FAILS on unfixed code because route has no try/except → HTTP 500 or crash.
"""

import os
import sys
import pathlib
import pytest
from unittest.mock import patch, MagicMock

# ---------------------------------------------------------------------------
# Path setup — ensure MiniCloud/app/src is importable
# ---------------------------------------------------------------------------
WORKSPACE_ROOT = pathlib.Path(__file__).resolve().parents[3]  # repo root
APP_DIR = WORKSPACE_ROOT / "MiniCloud" / "app"
if str(APP_DIR) not in sys.path:
    sys.path.insert(0, str(APP_DIR))

COMPOSE_FILE = WORKSPACE_ROOT / "MiniCloud" / "docker-compose.yml"


# ===========================================================================
# Sub-test A — Compose Config (Bug 1)
# ===========================================================================

class TestComposeConfigBug1:
    """
    Parse docker-compose.yml and assert that auth.environment does NOT contain
    KC_DB_PASSWORD or KEYCLOAK_ADMIN_PASSWORD as hardcoded values.

    EXPECTED ON UNFIXED CODE: FAIL
    Counterexample: KC_DB_PASSWORD = "secure_db_password_123!" exists in auth.environment
    """

    def test_kc_db_password_not_hardcoded(self):
        """
        Bug 1 — KC_DB_PASSWORD must NOT be a hardcoded value in auth.environment.
        After fix: replaced by KC_DB_PASSWORD_FILE pointing to the Docker Secret.
        """
        import yaml

        with open(COMPOSE_FILE, "r", encoding="utf-8") as f:
            compose = yaml.safe_load(f)

        auth_env = compose["services"]["auth"].get("environment", {})

        # On unfixed code this key exists → test FAILS (confirms bug)
        assert "KC_DB_PASSWORD" not in auth_env, (
            f"BUG CONFIRMED — KC_DB_PASSWORD is hardcoded in auth.environment: "
            f"{auth_env.get('KC_DB_PASSWORD')!r}. "
            "Expected: key absent (replaced by KC_DB_PASSWORD_FILE)."
        )

    def test_kc_admin_password_not_hardcoded(self):
        """
        Bug 1 — KEYCLOAK_ADMIN_PASSWORD must NOT be a hardcoded value in auth.environment.
        After fix: replaced by KEYCLOAK_ADMIN_PASSWORD_FILE pointing to the Docker Secret.
        """
        import yaml

        with open(COMPOSE_FILE, "r", encoding="utf-8") as f:
            compose = yaml.safe_load(f)

        auth_env = compose["services"]["auth"].get("environment", {})

        # On unfixed code this key exists → test FAILS (confirms bug)
        assert "KEYCLOAK_ADMIN_PASSWORD" not in auth_env, (
            f"BUG CONFIRMED — KEYCLOAK_ADMIN_PASSWORD is hardcoded in auth.environment: "
            f"{auth_env.get('KEYCLOAK_ADMIN_PASSWORD')!r}. "
            "Expected: key absent (replaced by KEYCLOAK_ADMIN_PASSWORD_FILE)."
        )


# ===========================================================================
# Sub-test B — Flask Secret Missing (Bug 2)
# ===========================================================================

class TestFlaskSecretMissingBug2:
    """
    Call get_db_connection() when /run/secrets/db_password does not exist.
    Assert ConnectionError is raised (not RuntimeError, not an unhandled crash).

    EXPECTED ON UNFIXED CODE: FAIL
    Counterexample: RuntimeError raised instead of ConnectionError.
    """

    def test_get_db_connection_raises_connection_error_when_secret_missing(self):
        """
        Bug 2 — When secret file is absent, get_db_connection() must raise
        ConnectionError, not RuntimeError.
        On unfixed code: _read_db_password_secret() raises RuntimeError which
        propagates uncaught → test FAILS.
        """
        from src.database import get_db_connection

        with patch("os.path.exists", return_value=False):
            # On unfixed code: RuntimeError is raised → pytest.raises(ConnectionError) fails
            with pytest.raises(ConnectionError, match="(?i)(secret|db_password|connect)"):
                get_db_connection()

    def test_get_db_connection_does_not_raise_runtime_error_when_secret_missing(self):
        """
        Complementary assertion: RuntimeError must NOT escape get_db_connection().
        On unfixed code: RuntimeError propagates → this test FAILS.
        """
        from src.database import get_db_connection

        with patch("os.path.exists", return_value=False):
            try:
                get_db_connection()
            except ConnectionError:
                pass  # correct — expected after fix
            except RuntimeError as exc:
                pytest.fail(
                    f"BUG CONFIRMED — get_db_connection() raised RuntimeError instead of "
                    f"ConnectionError: {exc}"
                )
            except Exception:
                pass  # other exceptions (e.g. mysql connect) are acceptable


# ===========================================================================
# Sub-test C — Route DB Failure (Bug 2)
# ===========================================================================

class TestRouteDbFailureBug2:
    """
    Call GET /api/student with get_db_connection mocked to raise ConnectionError.
    Assert HTTP 503 response.

    EXPECTED ON UNFIXED CODE: FAIL
    Counterexample: route returns HTTP 500 (or crashes) because there is no
    try/except around get_db_connection() in routes.py.
    """

    @pytest.fixture
    def client(self):
        from src import create_app
        app = create_app()
        app.config["TESTING"] = True
        with app.test_client() as c:
            yield c

    def test_get_student_returns_503_when_db_unavailable(self, client):
        """
        Bug 2 — Route /api/student must return HTTP 503 when DB is unavailable.
        On unfixed code: no try/except in route → unhandled exception → HTTP 500.
        """
        with patch("src.routes.get_db_connection", side_effect=ConnectionError("DB down")):
            response = client.get("/api/student")

        assert response.status_code == 503, (
            f"BUG CONFIRMED — GET /api/student returned HTTP {response.status_code} "
            f"instead of 503 when DB is unavailable. "
            "Expected: route catches ConnectionError and returns 503."
        )
