import csv
import os
import re
import shutil
import subprocess
from pathlib import Path

root = Path(__file__).parent
res = root / "results"
res.mkdir(exist_ok=True)
MYSQL = [os.environ.get("MYSQL") or shutil.which("mysql") or r"C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe",
         "--login-path=" + os.environ.get("MYSQL_LOGIN", "local")]
NAMES = ["q01_overview", "q02_by_fiscal_year", "q03_by_reason_category", "q04_monthly_trend_yoy",
         "q05_top_breakdown_reasons", "q06_breakdown_length", "q07_units_parked_90pct",
         "q08_by_sector", "q09_state_ranking", "q10_state_yoy", "q11_station_pareto",
         "q12_units_3x_sector_avg", "q13_by_unit_size", "q14_breakdown_start_hour",
         "q15_no_demand_by_column", "q16_no_demand_column_by_layout", "q17_mundra_long_outages",
         "q18_midnight_starts"]


def run(sql, db=True):
    args = MYSQL + ["--local-infile=1", "-B"] + (["-D", "power_outages"] if db else [])
    p = subprocess.run(args, input=sql, capture_output=True, text=True, encoding="utf-8", cwd=root)
    if p.returncode:
        raise SystemExit(p.stderr)
    return p.stdout


for f in ("schema.sql", "load.sql"):
    print(run((root / f).read_text(encoding="utf-8"), db=False))

(res / "index_test.txt").write_text(run((root / "index_test.sql").read_text(encoding="utf-8")), encoding="utf-8")

stmts = [s.strip() for s in re.split(r";\s*\n", (root / "analysis.sql").read_text(encoding="utf-8")) if s.strip()]
selects = [s for s in stmts if re.match(r"(SELECT|WITH)\b", s)]
for s in stmts:
    if not re.match(r"(SELECT|WITH)\b", s):
        run(s + ";")
for name, s in zip(NAMES, selects):
    lines = run(s + ";").splitlines()
    with open(res / f"{name}.csv", "w", newline="", encoding="utf-8") as fh:
        csv.writer(fh).writerows(line.split("\t") for line in lines)
    print(name, len(lines) - 1, "rows")
