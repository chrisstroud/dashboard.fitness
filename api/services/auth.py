"""Authentication services — Apple Sign In + JWT tokens."""
from __future__ import annotations

import jwt as pyjwt
from jwt import PyJWKClient
from datetime import datetime, timedelta, timezone
from flask import current_app, request, g, jsonify
from functools import wraps

APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"
APPLE_ISSUER = "https://appleid.apple.com"
BUNDLE_ID = "com.chrisstroud.Dashboard-Fitness"

_jwks_client: PyJWKClient | None = None


def _get_jwks_client() -> PyJWKClient:
    global _jwks_client
    if _jwks_client is None:
        _jwks_client = PyJWKClient(APPLE_JWKS_URL)
    return _jwks_client


def validate_apple_token(identity_token: str) -> dict:
    """Validate an Apple identity token and return decoded claims."""
    client = _get_jwks_client()
    signing_key = client.get_signing_key_from_jwt(identity_token)
    return pyjwt.decode(
        identity_token,
        signing_key.key,
        algorithms=["RS256"],
        audience=BUNDLE_ID,
        issuer=APPLE_ISSUER,
    )


def create_token(user_id: str) -> str:
    """Create a JWT for the given user."""
    payload = {
        "sub": user_id,
        "iat": datetime.now(timezone.utc),
        "exp": datetime.now(timezone.utc) + timedelta(days=30),
    }
    return pyjwt.encode(payload, current_app.config["SECRET_KEY"], algorithm="HS256")


def decode_token(token: str) -> dict:
    """Decode and validate our JWT. Raises on invalid/expired."""
    return pyjwt.decode(
        token, current_app.config["SECRET_KEY"], algorithms=["HS256"]
    )


def require_auth(f):
    """Decorator — extracts user_id from Bearer token into g.user_id."""
    @wraps(f)
    def decorated(*args, **kwargs):
        auth_header = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            return jsonify({"error": "Missing authentication token"}), 401
        token = auth_header[7:]
        try:
            payload = decode_token(token)
            g.user_id = payload["sub"]
        except pyjwt.ExpiredSignatureError:
            return jsonify({"error": "Token expired"}), 401
        except pyjwt.InvalidTokenError:
            return jsonify({"error": "Invalid token"}), 401
        return f(*args, **kwargs)
    return decorated
