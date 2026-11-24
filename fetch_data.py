import time
from datetime import date, timedelta
from pathlib import Path
import requests

BASE = "https://npp.gov.in/public-reports/cea/daily/dgr/{d:%d-%m-%Y}/dgr{n}-{d:%Y-%m-%d}.xls"
out = Path(__file__).parent / "data" / "raw"
(out / "dgr10").mkdir(parents=True, exist_ok=True)
s = requests.Session()
s.headers["User-Agent"] = "Mozilla/5.0"


def get(n, d, path):
    if path.exists() and path.stat().st_size > 2000:
        return True
    for _ in range(3):
        try:
            r = s.get(BASE.format(d=d, n=n), timeout=60)
            if r.status_code == 200 and r.content[:4] == b"\xd0\xcf\x11\xe0":
                path.write_bytes(r.content)
                return True
            if r.status_code == 404:
                return False
        except requests.RequestException:
            time.sleep(5)
    return False


d, end, missing = date(2023, 4, 1), date(2026, 3, 31), []
while d <= end:
    if not get(10, d, out / "dgr10" / f"dgr10_{d}.xls"):
        missing.append(str(d))
    time.sleep(0.3)
    d += timedelta(days=1)

for d2 in (date(2023, 4, 1), date(2026, 3, 31)):
    get(2, d2, out / f"dgr2_{d2}.xls")
print("missing days:", len(missing), missing)
