import argparse
import json
import time
from urllib.request import Request, urlopen


def verify(base, commit):
    def fetch(path):
        request = Request(
            f"{base}{path}?commit={commit}", headers={"Cache-Control": "no-cache"}
        )
        with urlopen(request, timeout=12) as response:
            return response.read()

    if b'id="root"' not in fetch("/"):
        raise ValueError("GearPass frontend HTML missing")
    if json.loads(fetch("/version.json")) != {"commit": commit}:
        raise ValueError("Frontend version does not match")
    if json.loads(fetch("/api/health")) != {"status": "ok", "commit": commit}:
        raise ValueError("API health or version does not match")
    items = json.loads(fetch("/api/equipment"))
    if not isinstance(items, list) or not items:
        raise ValueError("Equipment endpoint did not return data")

    print(f"Frontend and FastAPI verified at {base}")
    print(f"Verified commit: {commit}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("url")
    parser.add_argument("commit")
    parser.add_argument("--attempts", type=int, default=1)
    args = parser.parse_args()

    for attempt in range(args.attempts):
        try:
            verify(args.url.rstrip("/"), args.commit)
            break
        except (OSError, ValueError) as error:
            print(f"Attempt {attempt + 1}: {error}", flush=True)
            if attempt + 1 == args.attempts:
                raise
            time.sleep(5)
