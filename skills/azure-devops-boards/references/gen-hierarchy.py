#!/usr/bin/env python3
"""Generate hierarchy drawio diagram from JSON data.

Output defaults to {input_basename}.drawio in the current directory.
Override with --output FILE or use --stdout to print to stdout.

Usage:
    python3 gen-hierarchy.py INPUT_JSON

The input JSON schema (produced by extract-hierarchy.py):
{
  "project": "ProjectName",
  "extracted": "2026-02-14",
  "initiatives": [
    {
      "id": 36, "title": "Initiative title",
      "epics": [
        {
          "id": 37, "title": "Epic title",
          "features": [
            {"id": 38, "title": "Feature title", "area": "AreaName",
             "pbis": [{"id": 39, "title": "PBI title"}]}
          ],
          "orphan_pbis": [{"id": 63, "title": "Orphan PBI", "area": "Business"}]
        }
      ]
    }
  ]
}
"""
import argparse
import json
import os
import sys
import xml.etree.ElementTree as ET

# --- Layout constants ---
COL_W = 195
COL_GAP = 25
ROW_GAP = 20
COL_START_X = 270
PBI_H = 28
PBI_GAP = 6
FEAT_LABEL_LINE_H = 14  # height per line of feature title text
FEAT_LABEL_PAD = 6      # padding above/below feature title
FEAT_PAD_BOTTOM = 8
FEAT_GAP = 10
FEAT_INSET = 5
PBI_INSET = 8
CELL_PAD_TOP = 12
AREA_LABEL_X = 100
AREA_LABEL_W = 140
LANE_EXTEND_H = 30
LANE_EXTEND_V = 23
MIN_ROW_H = 90

# Styles
S_TITLE = "text;html=1;fontSize=18;fontStyle=1;align=center;verticalAlign=middle;"
S_SUBTITLE = "text;html=1;fontSize=11;fontStyle=2;align=center;verticalAlign=middle;fontColor=#666666;"
S_INITIATIVE = "rounded=1;whiteSpace=wrap;html=1;fontSize=13;fontStyle=1;fillColor=#e1d5e7;strokeColor=#9673a6;verticalAlign=middle;"
S_EPIC = "rounded=1;whiteSpace=wrap;html=1;fontSize=11;fontStyle=1;fillColor=#dae8fc;strokeColor=#6c8ebf;verticalAlign=middle;"
S_AREA = "rounded=1;whiteSpace=wrap;html=1;fontSize=12;fontStyle=1;fillColor=#d5e8d4;strokeColor=#82b366;verticalAlign=middle;"
S_AREA_LANE = "rounded=0;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;opacity=40;dashed=1;dashPattern=12 6;strokeWidth=2;"
S_EPIC_LANE = "rounded=0;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;opacity=40;dashed=1;dashPattern=12 6;strokeWidth=2;"
S_FEAT = "rounded=1;whiteSpace=wrap;html=1;fontSize=9;fontStyle=1;fillColor=#fff2cc;strokeColor=#d6b656;verticalAlign=top;dashed=1;strokeWidth=2;opacity=60;"
S_PBI = "rounded=0;whiteSpace=wrap;html=1;fontSize=8;fillColor=#f8cecc;strokeColor=#b85450;verticalAlign=middle;"
S_HEADER = "text;html=1;fontSize=12;fontStyle=5;align=center;verticalAlign=middle;fontColor=#333333;"
S_ROTATED_HEADER = "text;html=1;fontSize=12;fontStyle=5;align=center;verticalAlign=middle;fontColor=#333333;rotation=-90;"
S_LEGEND_BG = "rounded=1;whiteSpace=wrap;html=1;fillColor=#ffffff;strokeColor=#cccccc;"
S_LEGEND_TITLE = "text;html=1;fontSize=12;fontStyle=1;align=left;verticalAlign=middle;"
S_TEXT = "text;html=1;fontSize=10;align=left;verticalAlign=middle;"


def feat_label_h(title, feat_id):
    """Calculate feature label height based on title length and wrapping."""
    # Feature box inner width minus padding draw.io applies
    text = f"#{feat_id} {title}"
    inner_w = COL_W - FEAT_INSET * 2 - 16  # 16px for draw.io internal padding
    # At fontSize=9 bold, average char width ~5.5px
    chars_per_line = max(inner_w / 5.5, 10)
    import math
    lines = math.ceil(len(text) / chars_per_line)
    return FEAT_LABEL_PAD + lines * FEAT_LABEL_LINE_H + FEAT_LABEL_PAD


def feat_height(num_pbis, label_h=None):
    """Height of a feature box containing N PBIs."""
    if label_h is None:
        label_h = FEAT_LABEL_PAD * 2 + FEAT_LABEL_LINE_H  # default 1 line
    return label_h + num_pbis * (PBI_H + PBI_GAP) - PBI_GAP + FEAT_PAD_BOTTOM


def discover_areas(initiative):
    """Discover unique area paths from work items, preserving order."""
    areas = []
    seen = set()
    for epic in initiative["epics"]:
        for feat in epic.get("features", []):
            area = feat["area"]
            if area not in seen:
                areas.append(area)
                seen.add(area)
        for opbi in epic.get("orphan_pbis", []):
            area = opbi["area"]
            if area not in seen:
                areas.append(area)
                seen.add(area)
    return areas if areas else ["(No area)"]


def build_grid(initiative, areas):
    """Build a mapping of (area, epic_idx) -> list of features and orphan PBIs."""
    grid = {}
    for ei, epic in enumerate(initiative["epics"]):
        for feat in epic.get("features", []):
            key = (feat["area"], ei)
            grid.setdefault(key, {"features": [], "orphans": []})
            grid[key]["features"].append(feat)
        for opbi in epic.get("orphan_pbis", []):
            key = (opbi["area"], ei)
            grid.setdefault(key, {"features": [], "orphans": []})
            grid[key]["orphans"].append(opbi)
    return grid


def calc_row_heights(areas, epics, grid):
    """Calculate the content height needed for each area row."""
    row_heights = {}
    for area in areas:
        max_h = 0
        for ei in range(len(epics)):
            h = 0
            cell = grid.get((area, ei), {"features": [], "orphans": []})
            for feat in cell["features"]:
                if h > 0:
                    h += FEAT_GAP
                lh = feat_label_h(feat["title"], feat["id"])
                h += feat_height(len(feat.get("pbis", [])), lh)
            for _ in cell["orphans"]:
                if h > 0:
                    h += FEAT_GAP
                h += PBI_H + FEAT_PAD_BOTTOM
            max_h = max(max_h, h)
        row_heights[area] = max(max_h + CELL_PAD_TOP * 2, MIN_ROW_H)
    return row_heights


def generate_page(initiative, project, extracted_date, page_id):
    """Generate a single drawio diagram page for one initiative."""
    # Filter to only epics that have features or orphan PBIs
    epics = [e for e in initiative["epics"]
             if e.get("features") or e.get("orphan_pbis")]
    areas = discover_areas(initiative)
    grid = build_grid(initiative, areas)
    num_epics = len(epics)

    if num_epics == 0:
        num_epics = 1  # minimum 1 column

    grid_w = num_epics * (COL_W + COL_GAP) - COL_GAP
    row_heights = calc_row_heights(areas, epics, grid)

    # Calculate row Y positions
    GRID_Y = 223
    row_y = {}
    cy = GRID_Y
    for i, area in enumerate(areas):
        row_y[area] = cy
        cy += row_heights[area]
        if i < len(areas) - 1:
            cy += ROW_GAP
    total_grid_h = cy - GRID_Y

    # Legend position
    legend_h = 130
    legend_y = GRID_Y + total_grid_h + LANE_EXTEND_V + 22

    # Page dimensions
    page_w = max(COL_START_X + grid_w + 100, 1200)
    page_h = max(legend_y + legend_h + 50, 800)

    # Build XML
    diagram = ET.Element("diagram", name=initiative["title"], id=page_id)
    model = ET.SubElement(diagram, "mxGraphModel",
        dx="0", dy="0", grid="1", gridSize="10", guides="1", tooltips="1",
        connect="1", arrows="1", fold="1", page="1", pageScale="1",
        pageWidth=str(int(page_w)), pageHeight=str(int(page_h)),
        background="light-dark(#FFFFFF,#FFFFFF)", math="0", shadow="0")
    root_el = ET.SubElement(model, "root")
    ET.SubElement(root_el, "mxCell", id="0")
    ET.SubElement(root_el, "mxCell", id="1", parent="0")

    def cell(cid, value, style, x, y, w, h):
        el = ET.SubElement(root_el, "mxCell", id=cid, value=value, style=style, parent="1", vertex="1")
        geo = ET.SubElement(el, "mxGeometry", x=str(int(x)), y=str(int(y)), width=str(int(w)), height=str(int(h)))
        geo.set("as", "geometry")

    # Title
    cell("title",
         f"{project}: Work Item Hierarchy \u2014 Area Paths x Business Domains",
         S_TITLE, 300, 15, max(grid_w + 100, 900), 35)
    cell("subtitle",
         f"Area paths (rows) = system/component  |  Epics (columns) = ownership domain  |  Features = aggregation of PBIs  |  {extracted_date}",
         S_SUBTITLE, 250, 48, max(grid_w + 100, 1000), 25)

    # Initiative bar
    cell(f"init_{initiative['id']}",
         f"Initiative #{initiative['id']}: {initiative['title']}",
         S_INITIATIVE, COL_START_X, 80, grid_w, 30)

    # Epic header
    cell("epic_hdr", "Epics (Ownership Domains)", S_HEADER,
         COL_START_X, 115, grid_w, 20)

    # Epic column headers
    for i, epic in enumerate(epics):
        x = COL_START_X + i * (COL_W + COL_GAP)
        cell(f"epic_{epic['id']}", f"#{epic['id']} {epic['title']}", S_EPIC, x, 140, COL_W, 38)

    # Area rotated header
    cell("area_hdr", "Area Paths\n(Systems)", S_ROTATED_HEADER,
         15, GRID_Y + total_grid_h // 2 - 40, 80, 80)

    # Area lanes
    lane_left = COL_START_X - LANE_EXTEND_H
    lane_w = grid_w + LANE_EXTEND_H * 2
    for area in areas:
        y = row_y[area]
        h = row_heights[area]
        cell(f"area_{area.lower().replace(' ', '_')}", area, S_AREA,
             AREA_LABEL_X, y + h // 2 - 20, AREA_LABEL_W, 40)
        cell(f"lane_{area.lower().replace(' ', '_')}", "", S_AREA_LANE,
             lane_left, y, lane_w, h)

    # Epic column lanes
    elane_top = GRID_Y - LANE_EXTEND_V
    elane_h = total_grid_h + LANE_EXTEND_V * 2
    for i, epic in enumerate(epics):
        x = COL_START_X + i * (COL_W + COL_GAP)
        cell(f"elane_{epic['id']}", "", S_EPIC_LANE, x, elane_top, COL_W, elane_h)

    # Features and PBIs
    for ei, epic in enumerate(epics):
        col_x = COL_START_X + ei * (COL_W + COL_GAP)

        for area in areas:
            cell_data = grid.get((area, ei), {"features": [], "orphans": []})
            cell_y = row_y[area] + CELL_PAD_TOP

            # Features
            for feat in cell_data["features"]:
                pbis = feat.get("pbis", [])
                lh = feat_label_h(feat["title"], feat["id"])
                fh = feat_height(len(pbis), lh)
                fx = col_x + FEAT_INSET
                fw = COL_W - FEAT_INSET * 2

                cell(f"feat_{feat['id']}", f"#{feat['id']} {feat['title']}", S_FEAT,
                     fx, cell_y, fw, fh)

                for pi, pbi in enumerate(pbis):
                    px = fx + PBI_INSET
                    py = cell_y + lh + pi * (PBI_H + PBI_GAP)
                    pw = fw - PBI_INSET * 2
                    cell(f"pbi_{pbi['id']}", f"#{pbi['id']} {pbi['title']}", S_PBI,
                         px, py, pw, PBI_H)

                cell_y += fh + FEAT_GAP

            # Orphan PBIs
            for opbi in cell_data["orphans"]:
                px = col_x + FEAT_INSET + PBI_INSET
                py = cell_y + 5
                pw = COL_W - (FEAT_INSET + PBI_INSET) * 2
                cell(f"pbi_{opbi['id']}", f"#{opbi['id']} {opbi['title']}", S_PBI,
                     px, py, pw, PBI_H)
                cell_y += PBI_H + FEAT_PAD_BOTTOM + FEAT_GAP

    # Legend
    cell("legend_bg", "", S_LEGEND_BG, COL_START_X, legend_y, 800, legend_h)
    cell("legend_title", "Legend", S_LEGEND_TITLE, COL_START_X + 15, legend_y + 8, 100, 25)

    legend_items = [
        ("#e1d5e7", "#9673a6", "rounded=1", "Initiative \u2014 the top-level strategic goal"),
        ("#dae8fc", "#6c8ebf", "rounded=1", "Epic \u2014 ownership domain (who is responsible)"),
        ("#d5e8d4", "#82b366", "rounded=1", "Area Path \u2014 the system or component (where code runs)"),
        ("#fff2cc", "#d6b656", "rounded=1;dashed=1;strokeWidth=2;opacity=60", "Feature \u2014 aggregation of related PBIs under an Epic"),
        ("#f8cecc", "#b85450", "rounded=0", "PBI \u2014 deliverable work item, area path = who does the work"),
    ]
    for li, (fill, stroke, shape, desc) in enumerate(legend_items):
        ly = legend_y + 38 + li * 18
        swatch_style = f"whiteSpace=wrap;html=1;fillColor={fill};strokeColor={stroke};{shape};"
        cell(f"leg{li}", "", swatch_style, COL_START_X + 15, ly, 14, 14)
        cell(f"leg{li}t", desc, S_TEXT, COL_START_X + 38, ly, 420, 14)

    stats = {
        "page_w": int(page_w), "page_h": int(page_h),
        "epics": len(epics), "areas": len(areas),
        "features": sum(len(e.get("features", [])) for e in epics),
        "pbis": sum(len(f.get("pbis", [])) for e in epics for f in e.get("features", []))
              + sum(len(e.get("orphan_pbis", [])) for e in epics),
        "grid_h": total_grid_h, "legend_y": legend_y,
    }
    return diagram, stats


def main():
    parser = argparse.ArgumentParser(description="Generate hierarchy drawio from JSON")
    parser.add_argument("input", help="Input JSON file")
    parser.add_argument("--output", help="Output drawio file (default: {input}.drawio)")
    parser.add_argument("--stdout", action="store_true", help="Print to stdout instead of file")
    args = parser.parse_args()

    with open(args.input) as f:
        data = json.load(f)

    project = data.get("project", "Project")
    extracted = data.get("extracted", "")

    mxfile = ET.Element("mxfile", host="gen-hierarchy", pages=str(len(data["initiatives"])))

    for idx, initiative in enumerate(data["initiatives"]):
        page_id = f"page_{idx}"
        diagram, stats = generate_page(initiative, project, extracted, page_id)
        mxfile.append(diagram)
        print(f"Page '{initiative['title']}':", file=sys.stderr)
        print(f"  Size: {stats['page_w']}x{stats['page_h']}", file=sys.stderr)
        print(f"  Epics: {stats['epics']}, Areas: {stats['areas']}", file=sys.stderr)
        print(f"  Features: {stats['features']}, PBIs: {stats['pbis']}", file=sys.stderr)

    tree = ET.ElementTree(mxfile)
    ET.indent(tree, space="    ")

    if args.stdout:
        ET.indent(tree, space="    ")
        tree.write(sys.stdout, encoding="unicode", xml_declaration=False)
    else:
        out_file = args.output or os.path.splitext(args.input)[0] + ".drawio"
        tree.write(out_file, encoding="unicode", xml_declaration=False)
        print(f"\nGenerated {out_file}", file=sys.stderr)


if __name__ == "__main__":
    main()
