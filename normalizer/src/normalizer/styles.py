"""Cell formats and series colors."""

# Series colors, in the order algorithms appear in the CSV header.
PALETTE = ["#4E79A7", "#F28E2B", "#E15759", "#76B7B2", "#59A14F",
           "#EDC948", "#B07AA1", "#FF9DA7", "#9C755F", "#BAB0AC"]


def make_formats(wb) -> dict:
    f = wb.add_format
    return {
        "title": f({"bold": True, "font_size": 16, "font_color": "#1F3864"}),
        "subtitle": f({"italic": True, "font_color": "#595959"}),
        "section": f({"bold": True, "font_size": 12, "font_color": "#1F3864", "bottom": 2}),
        "header": f({"bold": True, "bg_color": "#1F3864", "font_color": "#FFFFFF",
                     "border": 1, "text_wrap": True, "valign": "vcenter", "align": "center"}),
        "text": f({"border": 1}),
        "bold": f({"border": 1, "bold": True}),
        "int": f({"border": 1, "num_format": "#,##0"}),
        "ms": f({"border": 1, "num_format": '#,##0 "ms"'}),
        "ms_dec": f({"border": 1, "num_format": '#,##0.0 "ms"'}),
        "tput": f({"border": 1, "num_format": "#,##0.00"}),
        "ratio": f({"border": 1, "num_format": '0.00"x"'}),
        "skipped": f({"border": 1, "bg_color": "#D9D9D9", "pattern": 1}),
        "skipped_label": f({"border": 1, "bg_color": "#D9D9D9", "italic": True,
                            "font_color": "#7F7F7F", "align": "center"}),
        "reason": f({"border": 1, "bg_color": "#FFF2CC", "text_wrap": True, "valign": "top"}),
        "notes": f({"border": 1, "bg_color": "#FFF2CC", "text_wrap": True, "valign": "top"}),
        "best": f({"border": 1, "bold": True, "bg_color": "#E2EFDA", "num_format": '#,##0.0 "ms"'}),
        "hint": f({"italic": True, "font_color": "#7F7F7F"}),
    }
