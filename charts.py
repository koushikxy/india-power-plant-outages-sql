from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

root = Path(__file__).parent
res = root / "results"
out = root / "screenshots"
out.mkdir(exist_ok=True)
INK, MUTED, GRID, BG = "#0b0b0b", "#52514e", "#e4e3df", "#fcfcfb"
BLUE, ORANGE, AQUA = "#2a78d6", "#eb6834", "#1baf7a"
plt.rcParams.update({"font.family": "Segoe UI", "font.size": 11, "text.color": INK, "axes.labelcolor": MUTED,
                     "xtick.color": MUTED, "ytick.color": MUTED, "axes.edgecolor": GRID,
                     "figure.facecolor": BG, "axes.facecolor": BG})


def style(ax):
    for s in ("top", "right", "left"):
        ax.spines[s].set_visible(False)
    ax.tick_params(length=0)


m = pd.read_csv(res / "q04_monthly_trend_yoy.csv")
m["month"] = pd.to_datetime(m["month"])
fig, ax = plt.subplots(figsize=(11, 5), dpi=130)
ax.plot(m.month, m.avg_mw_out / 1000, color=BLUE, lw=2, label="All units out")
ax.plot(m.month, m.avg_no_demand_mw / 1000, color=ORANGE, lw=2, label="Out because of no demand or no buyer")
ax.grid(axis="y", color=GRID)
ax.set_ylim(0, 60)
ax.set_ylabel("Average capacity out (GW)")
ax.legend(frameon=False, loc="upper left")
ax.set_title("Coal, lignite and nuclear capacity out of service, monthly average", loc="left", fontsize=14)
style(ax)
fig.tight_layout()
fig.savefig(out / "monthly_capacity_out.png")

c = pd.read_csv(res / "q03_by_reason_category.csv")
c = c[c.avg_mw_out > 0].iloc[::-1]
fig, ax = plt.subplots(figsize=(10, 4.2), dpi=130)
colors = [BLUE if x in ("Tube leakage", "Other equipment fault") else "#a9b7c9" for x in c.category]
ax.barh(c.category, c.avg_mw_out / 1000, color=colors, height=0.6)
for y, (v, p) in enumerate(zip(c.avg_mw_out, c.pct_of_mw_out)):
    ax.text(v / 1000 + 0.2, y, f"{v / 1000:.1f} GW  ({p}%)", va="center", color=INK)
ax.set_xlabel("Average capacity out on a report day (GW)")
ax.set_xlim(0, 16)
ax.set_title("Why units were out, Apr 2023 to Mar 2026 (breakdowns in blue)", loc="left", fontsize=14)
ax.grid(axis="x", color=GRID)
style(ax)
fig.tight_layout()
fig.savefig(out / "reasons.png")

s = pd.read_csv(res / "q09_state_ranking.csv").iloc[::-1]
fig, ax = plt.subplots(figsize=(10, 6), dpi=130)
ax.barh(s.state_name, s.breakdown_pct, color=AQUA, height=0.6)
for y, v in enumerate(s.breakdown_pct):
    ax.text(v + 0.15, y, f"{v}%", va="center", color=INK)
ax.set_xlabel("Capacity lost to breakdowns as % of the state's coal and lignite fleet")
ax.set_title("Breakdown losses by state, Apr 2023 to Mar 2026", loc="left", fontsize=14)
ax.grid(axis="x", color=GRID)
style(ax)
fig.tight_layout()
fig.savefig(out / "states.png")

tables = {
    "states": (0.04, 0.55, ["state_id  PK", "state_name", "region"]),
    "stations": (0.27, 0.55, ["station_id  PK", "station_name", "state_id  FK", "sector", "fuel_type"]),
    "units": (0.50, 0.55, ["unit_id  PK", "station_id  FK", "unit_no", "capacity_mw", "in_master"]),
    "outage_reports": (0.50, 0.04, ["report_id  PK", "report_date", "unit_id  FK", "planned_mw",
                                    "forced_major_mw", "forced_minor_mw", "other_mw", "outage_start",
                                    "expected_return", "reason_id  FK"]),
    "reasons": (0.77, 0.10, ["reason_id  PK", "reason_text", "category"]),
}
fig = plt.figure(figsize=(14, 7.6), dpi=100)
ax = fig.add_axes([0, 0, 1, 1])
ax.set_xlim(0, 1)
ax.set_ylim(0, 1)
ax.axis("off")
ax.text(0.04, 0.93, "Power plant outages in India: database schema", fontsize=22, color=INK)
ax.text(0.04, 0.885, "MySQL 8.4  ·  165,249 daily outage rows from CEA reports, Apr 2023 to Mar 2026",
        fontsize=13, color=MUTED)
W, LH = 0.19, 0.034
box = {}
for name, (x, y, cols) in tables.items():
    h = LH * (len(cols) + 1.3)
    ax.add_patch(plt.Rectangle((x, y), W, h, facecolor="white", edgecolor="#c9c8c2", lw=1.2))
    ax.add_patch(plt.Rectangle((x, y + h - LH * 1.2), W, LH * 1.2, facecolor=BLUE, edgecolor=BLUE))
    ax.text(x + 0.01, y + h - LH * 0.6, name, color="white", fontsize=13, va="center", weight="bold")
    for i, col in enumerate(cols):
        ax.text(x + 0.012, y + h - LH * (1.75 + i), col, fontsize=11.5, va="center",
                color=INK if ("PK" in col or "FK" in col) else MUTED)
    box[name] = (x, y, h)


def link(a, b, side_a, side_b):
    xa, ya, ha = box[a]
    xb, yb, hb = box[b]
    pa = {"r": (xa + W, ya + ha / 2), "l": (xa, ya + ha / 2), "b": (xa + W / 2, ya)}[side_a]
    pb = {"r": (xb + W, yb + hb / 2), "l": (xb, yb + hb / 2), "t": (xb + W / 2, yb + hb)}[side_b]
    ax.annotate("", xy=pa, xytext=pb, arrowprops=dict(arrowstyle="-|>", color=MUTED, lw=1.4))


link("states", "stations", "r", "l")
link("stations", "units", "r", "l")
link("units", "outage_reports", "b", "t")
link("reasons", "outage_reports", "l", "r")
ax.text(0.77, 0.62, "1 state : many stations\n1 station : many units\n1 unit : many daily rows\n1 reason : many daily rows",
        fontsize=12, color=MUTED, va="top", linespacing=1.6)
fig.savefig(out / "cover.png", facecolor=BG)
print("charts saved")
