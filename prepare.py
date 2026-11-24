import re
from pathlib import Path
import pandas as pd
import xlrd

root = Path(__file__).parent
raw = root / "data" / "raw"
out = root / "data" / "clean"
out.mkdir(parents=True, exist_ok=True)
REGIONS = {"NORTHERN", "WESTERN", "SOUTHERN", "EASTERN", "NORTH EASTERN"}


def text(v):
    if isinstance(v, float):
        return "" if v != v else (str(int(v)) if v == int(v) else str(v))
    return re.sub(r"\s+", " ", str(v)).strip()


def when(v, book):
    if isinstance(v, float) and v > 0:
        return xlrd.xldate_as_datetime(v, book.datemode).strftime("%Y-%m-%d %H:%M")
    s = text(v)
    m = re.match(r"(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})\s*(\d{1,2})?[:.]?(\d{2})?", s)
    if not m:
        return ""
    d, mo, y, h, mi = m.groups()
    return f"{y}-{int(mo):02d}-{int(d):02d} {int(h or 0):02d}:{int(mi or 0):02d}"


def num(v):
    try:
        return float(text(v).replace(",", "") or 0)
    except ValueError:
        return 0.0


units = []
for f in sorted(raw.glob("dgr2_*.xls")):
    book = xlrd.open_workbook(f)
    sh = book.sheet_by_index(0)
    cap = next(j for j, v in enumerate(sh.row_values(2)) if text(v).startswith("MONITORED"))
    region = state = sector = ftype = station = ""
    for i in range(5, sh.nrows):
        c = sh.row_values(i)
        a = text(c[0])
        if not a:
            continue
        nxt = text(sh.cell_value(i + 1, 0)) if i + 1 < sh.nrows else ""
        if nxt == "STATE TOTAL":
            state = a.title()
        elif a.upper() in REGIONS:
            region = a.title()
        elif a in ("REGION TOTAL", "STATE TOTAL", "ALL INDIA TOTAL") or a.endswith("TOTAL"):
            continue
        elif a == "SECTOR:":
            sector = next((text(v) for v in c[1:cap] if text(v)), "").replace(" SECTOR", "").title()
        elif a == "TYPE:":
            ftype = next((text(v) for v in c[1:cap] if text(v)), "")
        elif a == "Unit":
            units.append([f.stem.split("_")[1], region, state, sector, ftype, station, text(c[1]), num(c[cap])])
        else:
            station = a

u = pd.DataFrame(units, columns=["file_date", "region", "state", "sector", "fuel_type", "station", "unit_no", "capacity_mw"])
u.to_csv(out / "unit_master.csv", index=False, lineterminator="\n")
print("unit master rows:", len(u))
names = {re.sub(r"[^A-Z0-9]", "", n.upper()) for n in u.station}

rows, skipped, merged, totals = [], 0, 0, {}
for f in sorted((raw / "dgr10").glob("dgr10_*.xls")):
    day = f.stem.split("_")[1]
    book = xlrd.open_workbook(f)
    sh = book.sheet_by_index(0)
    start = next(i for i in range(sh.nrows) if text(sh.cell_value(i, 0)) == "1")
    pos = {text(v): j for j, v in enumerate(sh.row_values(start)) if text(v)}
    pos = [pos[str(k)] for k in range(1, 11)]
    region, prev = "", None
    for i in range(start + 1, sh.nrows):
        c = [sh.cell_value(i, j) for j in pos]
        state, station, unit = text(c[0]), text(c[1]), text(c[2])
        if state.upper() in REGIONS and not station:
            region = state.title()
            continue
        if state.lower() == "total":
            totals[day] = sum(num(x) for x in c[3:7])
        if not unit or state.lower().startswith("total") or not station:
            if any(text(x) for x in c):
                skipped += 1
            continue
        r = [day, region, state, station, unit, num(c[3]), num(c[4]), num(c[5]), num(c[6]),
             when(c[7], book), when(c[8], book), text(c[9])]
        if prev and prev[0] == day and prev[2] == state and prev[4] == unit and prev[5:10] == r[5:10] \
                and (station == prev[3] or station.startswith("(")
                     or re.sub(r"[^A-Z0-9]", "", f"{prev[3]}{station}".upper()) in names):
            if station != prev[3]:
                prev[3] = f"{prev[3]} {station}"
            if r[11] and r[11] != prev[11]:
                prev[11] = f"{prev[11]} {r[11]}".strip()
            merged += 1
            continue
        rows.append(r)
        prev = r

cols = ["report_date", "region", "state", "station", "unit_no", "planned_mw", "forced_major_mw",
        "forced_minor_mw", "other_mw", "outage_start", "expected_return", "reason"]
df = pd.DataFrame(rows, columns=cols)
df.to_csv(out / "outage_rows.csv", index=False, lineterminator="\n")
print("outage rows:", len(df), "wrapped lines merged:", merged, "total lines skipped:", skipped, "days:", df.report_date.nunique())
mw = df[["planned_mw", "forced_major_mw", "forced_minor_mw", "other_mw"]].sum(axis=1).groupby(df.report_date).sum()
gap = (mw - pd.Series(totals)).abs()
print("days checked against report total:", gap.notna().sum(), "days off by more than 1 MW:", (gap > 1).sum())

