"""Crea usuarios Auth + profiles en Supabase desde ATTCONTROL_BD.xlsx / personal.json.

Requiere .env con SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY.
No subas .env al repositorio.
"""
from __future__ import annotations

import json
import os
import pathlib
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]


def load_env() -> None:
    for name in (".env", ".env.seed"):
        path = ROOT / name
        if not path.exists():
            continue
        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            os.environ.setdefault(k.strip(), v.strip())


def main() -> None:
    load_env()
    url = os.environ.get("SUPABASE_URL", "").rstrip("/")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
    password = os.environ.get("SEED_PASSWORD", "").strip()
    if "YOUR_PROJECT" in url or not key or key.startswith("your_"):
        raise SystemExit(
            "Configura SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY en .env"
        )
    if len(password) < 8:
        raise SystemExit(
            "Define SEED_PASSWORD (mínimo 8 caracteres) en .env.seed; "
            "no hay clave por defecto."
        )

    people = json.loads((ROOT / "assets" / "seed" / "personal.json").read_text(encoding="utf-8"))
    for row in people:
        email = f"{row['documento']}@users.attcontrol.local"
        user = _request(
            f"{url}/auth/v1/admin/users",
            key,
            {
                "email": email,
                "password": password,
                "email_confirm": True,
                "app_metadata": {"rol": row["rol"]},
                "user_metadata": {"correo": row["correo"]},
            },
        )
        user_id = user.get("id")
        if not user_id:
            print("skip/create fail", row["documento"], user)
            continue
        _request(
            f"{url}/rest/v1/profiles",
            key,
            {
                "id": user_id,
                "documento": row["documento"],
                "nombre": row["nombre"],
                "apellido": row["apellido"],
                "cargo": row["cargo"],
                "correo": row["correo"],
                "rh": row["rh"],
                "eps": row["eps"],
                "arl": row["arl"],
                "rol": row["rol"],
                "activo": True,
                "location_id": "11111111-1111-1111-1111-111111111111",
                "shift_id": "22222222-2222-2222-2222-222222222222",
            },
            extra_headers={
                "Prefer": "resolution=merge-duplicates,return=minimal",
            },
        )
        print("ok", row["documento"], row["nombre"])


def _request(url: str, key: str, payload: dict, extra_headers: dict | None = None) -> dict:
    headers = {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
    }
    if extra_headers:
        headers.update(extra_headers)
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read().decode("utf-8")
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        print("HTTP", exc.code, exc.read().decode("utf-8", errors="replace"))
        return {}


if __name__ == "__main__":
    main()
