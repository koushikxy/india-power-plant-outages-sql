from pathlib import Path
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Image, Table, TableStyle, KeepTogether

p = Path(__file__).parent
st = getSampleStyleSheet()
body = ParagraphStyle("b", parent=st["BodyText"], fontSize=10.5, leading=15, spaceAfter=6)
h1 = ParagraphStyle("h1", parent=st["Title"], fontSize=18, alignment=0, spaceAfter=4)
h2 = ParagraphStyle("h2", parent=st["Heading2"], fontSize=13, spaceBefore=10)
sub = ParagraphStyle("s", parent=body, textColor=colors.HexColor("#52514e"))


def img(name, w=17):
    from PIL import Image as I
    a, b = I.open(p / "screenshots" / name).size
    return Image(str(p / "screenshots" / name), width=w * cm, height=w * cm * b / a)


def table(rows):
    t = Table(rows, hAlign="LEFT")
    t.setStyle(TableStyle([("FONT", (0, 0), (-1, 0), "Helvetica-Bold"), ("FONTSIZE", (0, 0), (-1, -1), 9.5),
                           ("LINEBELOW", (0, 0), (-1, 0), 0.6, colors.grey),
                           ("ALIGN", (1, 0), (-1, -1), "RIGHT"), ("BOTTOMPADDING", (0, 0), (-1, -1), 4)]))
    return t


s = [Paragraph("Why are India's power plants out of service?", h1),
     Paragraph("CEA daily maintenance reports, April 2023 to March 2026. Koushik Maity", sub),
     Paragraph("CEA publishes a daily list of every coal, lignite and nuclear unit that is not running, with the "
               "reason. I cleaned 1,093 of these reports into 165,249 rows in MySQL to see how much capacity is out "
               "and why.", body),
     Paragraph("How much is out", h2),
     Paragraph("On an average day 40.3 GW was out, about 16% of the 254 GW of units in CEA's monitored list: "
               "40.1 GW in 2023-24, 37.2 GW in 2024-25 and 43.6 GW in 2025-26.", body),
     img("monthly_capacity_out.png", 16),
     Paragraph("Why", h2),
     Paragraph("I grouped 376 different reason texts with LIKE patterns. Breakdowns (tube leakage and other "
               "equipment faults) were 18.8 GW a day, 46.5% of all capacity out. Planned maintenance was 26.8%. "
               "Units that were not broken but had no schedule or no buyer were 21.9%.", body),
     img("reasons.png", 15.5),
     Paragraph("CEA's forced outage columns can't be compared across years. From the report layout change on "
               "15 April 2025, most reserve shutdowns moved from the Others column into the forced columns: "
               "no-demand capacity in Others fell from 5.8 to 0.8 GW a day and in the forced columns rose from 3.7 "
               "to 9.4 GW. Total no-demand capacity was 9.5, 6.7 and 10.2 GW a day.", body),
     Paragraph("By reason, breakdowns were 18.3, 17.0 and 21.0 GW a day. All five Mundra UMTPP units went out on "
               "1-3 July 2025 with different fault reasons and stayed out to March 2026. That looks like a single "
               "plant-wide shutdown rather than five separate faults. Without Mundra, breakdowns were 17.2, 16.4 "
               "and 17.9 GW a day, about the same in all three years.", body),
     KeepTogether([Paragraph("Who", h2),
                   table([["Sector", "Units", "Capacity (GW)", "Lost to breakdowns", "Lost to no demand"],
                          ["State", "234", "78.8", "9.5%", "4.6%"], ["Private", "239", "89.7", "7.7%", "4.4%"],
                          ["Central", "178", "76.9", "5.1%", "1.5%"]]),
                   Spacer(1, 8)]),
     Paragraph("Gujarat had the highest breakdown loss (13.3% of its coal and lignite capacity), then Tamil Nadu "
               "(11.2%). Mundra UMTPP alone was 8.5% of all breakdown losses in India. Without it Gujarat would be "
               "at about 7.0%. It takes 35 stations to reach half of all breakdown losses.", body),
     img("states.png", 14),
     Paragraph("Other results", h2),
     Paragraph("Water wall tube leakage was the most common breakdown (2,583 outages). 70.6% of breakdowns that "
               "started and ended in the period were listed in three or fewer daily reports. 30 units were listed "
               "on at least 90% of days, many of them without a power purchase agreement since 2013-2017. Units "
               "under 250 MW had 25.8 breakdowns each over three years, larger units about 21.", body),
     Paragraph("Limits", h2),
     Paragraph("The report is one snapshot a day, so outages shorter than a day can be missed. Sector and state "
               "capacity uses the 2023 and 2026 unit lists for all three years, without closed 0 MW units. The "
               "reason groups are my own: condenser tube leaks count as tube leakage, unscheduled annual "
               "maintenance and boiler inspection as planned, and accidents, strikes and 'others' as equipment "
               "faults. Plant outages are not consumer power cuts.", body)]
SimpleDocTemplate(str(p / "power_outages_report.pdf"), pagesize=A4, leftMargin=2 * cm, rightMargin=2 * cm,
                  topMargin=1.8 * cm, bottomMargin=1.8 * cm, title="Why are India's power plants out of service?",
                  author="Koushik Maity", creator="Koushik Maity", producer="").build(s)
print("ok")
