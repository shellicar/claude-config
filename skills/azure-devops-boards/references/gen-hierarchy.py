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

Layout: Initiatives that share area paths are grouped horizontally.
Groups that don't share areas are stacked vertically to save space.
"""
import argparse
import json
import math
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
INIT_BAR_H = 30
SECTION_GAP = 50
TITLE_AREA_H = 75

# Section-internal Y offsets
SEC_INIT_Y = 0
SEC_EPIC_Y = INIT_BAR_H + 5       # 35
SEC_GRID_Y = INIT_BAR_H + 5 + 48  # 83

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
    text = f"#{feat_id} {title}"
    inner_w = COL_W - FEAT_INSET * 2 - 16  # 16px for draw.io internal padding
    # At fontSize=9 bold, average char width ~5.5px
    chars_per_line = max(inner_w / 5.5, 10)
    lines = math.ceil(len(text) / chars_per_line)
    return FEAT_LABEL_PAD + lines * FEAT_LABEL_LINE_H + FEAT_LABEL_PAD


def feat_height(num_pbis, label_h=None):
    """Height of a feature box containing N PBIs."""
    if label_h is None:
        label_h = FEAT_LABEL_PAD * 2 + FEAT_LABEL_LINE_H  # default 1 line
    return label_h + num_pbis * (PBI_H + PBI_GAP) - PBI_GAP + FEAT_PAD_BOTTOM


def get_initiative_areas(initiative):
    """Get set of areas used by an initiative."""
    areas = set()
    for epic in initiative["epics"]:
        for feat in epic.get("features", []):
            areas.add(feat["area"])
        for opbi in epic.get("orphan_pbis", []):
            areas.add(opbi["area"])
    return areas


def find_initiative_groups(initiatives):
    """Find connected components of initiatives based on shared areas.

    Two initiatives are in the same group if they share any area path
    (directly or transitively). Returns list of groups, each a list of
    initiatives, preserving original order.
    """
    n = len(initiatives)
    parent = list(range(n))

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(a, b):
        a, b = find(a), find(b)
        if a != b:
            parent[b] = a

    # Map area -> first initiative index that uses it
    area_to_init = {}
    for i, init in enumerate(initiatives):
        for area in get_initiative_areas(init):
            if area in area_to_init:
                union(i, area_to_init[area])
            else:
                area_to_init[area] = i

    # Collect groups preserving order
    groups = {}
    for i in range(n):
        root = find(i)
        groups.setdefault(root, []).append(initiatives[i])

    return list(groups.values())


def compute_section(group_initiatives):
    """Compute layout data for a group of initiatives."""
    # Discover areas for this group
    areas = []
    seen = set()
    for init in group_initiatives:
        for epic in init["epics"]:
            for feat in epic.get("features", []):
                if feat["area"] not in seen:
                    areas.append(feat["area"])
                    seen.add(feat["area"])
            for opbi in epic.get("orphan_pbis", []):
                if opbi["area"] not in seen:
                    areas.append(opbi["area"])
                    seen.add(opbi["area"])
    if not areas:
        areas = ["(No area)"]

    # Flatten epics within this group
    flat_epics = []
    init_ranges = {}
    gi = 0
    for init in group_initiatives:
        epics = [e for e in init["epics"]
                 if e.get("features") or e.get("orphan_pbis")]
        if not epics:
            continue
        start = gi
        for epic in epics:
            flat_epics.append((init, epic, gi))
            gi += 1
        init_ranges[init["id"]] = (start, gi - 1)

    num_epics = max(len(flat_epics), 1)
    grid_w = num_epics * (COL_W + COL_GAP) - COL_GAP

    # Build grid
    grid = {}
    for _init, epic, gi in flat_epics:
        for feat in epic.get("features", []):
            key = (feat["area"], gi)
            grid.setdefault(key, {"features": [], "orphans": []})
            grid[key]["features"].append(feat)
        for opbi in epic.get("orphan_pbis", []):
            key = (opbi["area"], gi)
            grid.setdefault(key, {"features": [], "orphans": []})
            grid[key]["orphans"].append(opbi)

    # Row heights
    row_heights = {}
    for area in areas:
        max_h = 0
        for ei in range(num_epics):
            h = 0
            c = grid.get((area, ei), {"features": [], "orphans": []})
            for feat in c["features"]:
                if h > 0:
                    h += FEAT_GAP
                lh = feat_label_h(feat["title"], feat["id"])
                h += feat_height(len(feat.get("pbis", [])), lh)
            for _ in c["orphans"]:
                if h > 0:
                    h += FEAT_GAP
                h += PBI_H + FEAT_PAD_BOTTOM
            max_h = max(max_h, h)
        row_heights[area] = max(max_h + CELL_PAD_TOP * 2, MIN_ROW_H)

    # Grid height
    grid_h = sum(row_heights[a] for a in areas) + ROW_GAP * max(len(areas) - 1, 0)

    return {
        "initiatives": group_initiatives,
        "areas": areas,
        "flat_epics": flat_epics,
        "init_ranges": init_ranges,
        "grid": grid,
        "grid_w": grid_w,
        "row_heights": row_heights,
        "grid_h": grid_h,
        "total_h": SEC_GRID_Y + grid_h,
    }


def render_section(cell_fn, sec, sec_y, si):
    """Render a section (group of initiatives) at the given Y offset."""
    flat_epics = sec["flat_epics"]
    areas = sec["areas"]
    grid = sec["grid"]
    init_ranges = sec["init_ranges"]
    row_heights = sec["row_heights"]
    grid_w = sec["grid_w"]
    grid_h = sec["grid_h"]

    # Initiative bars
    for init in sec["initiatives"]:
        iid = init["id"]
        if iid not in init_ranges:
            continue
        start_col, end_col = init_ranges[iid]
        x = COL_START_X + start_col * (COL_W + COL_GAP)
        w = (end_col - start_col + 1) * (COL_W + COL_GAP) - COL_GAP
        cell_fn(f"init_{iid}",
                f"Initiative #{iid}: {init['title']}",
                S_INITIATIVE, x, sec_y + SEC_INIT_Y, w, INIT_BAR_H)

    # Epic column headers
    for _init, epic, gi in flat_epics:
        x = COL_START_X + gi * (COL_W + COL_GAP)
        cell_fn(f"epic_{epic['id']}",
                f"#{epic['id']} {epic['title']}",
                S_EPIC, x, sec_y + SEC_EPIC_Y, COL_W, 38)

    # Calculate row Y positions within the grid
    grid_top = sec_y + SEC_GRID_Y
    row_y = {}
    cy = grid_top
    for i, area in enumerate(areas):
        row_y[area] = cy
        cy += row_heights[area]
        if i < len(areas) - 1:
            cy += ROW_GAP

    # Area labels and lanes
    lane_left = COL_START_X - LANE_EXTEND_H
    lane_w = grid_w + LANE_EXTEND_H * 2
    for area in areas:
        y = row_y[area]
        h = row_heights[area]
        area_key = area.lower().replace(' ', '_')
        cell_fn(f"s{si}_area_{area_key}", area, S_AREA,
                AREA_LABEL_X, y + h // 2 - 20, AREA_LABEL_W, 40)
        cell_fn(f"s{si}_lane_{area_key}", "", S_AREA_LANE,
                lane_left, y, lane_w, h)

    # Epic column lanes (span full grid height of this section)
    elane_top = grid_top - LANE_EXTEND_V
    elane_h = grid_h + LANE_EXTEND_V * 2
    for _init, epic, gi in flat_epics:
        x = COL_START_X + gi * (COL_W + COL_GAP)
        cell_fn(f"elane_{epic['id']}", "", S_EPIC_LANE, x, elane_top, COL_W, elane_h)

    # Features and PBIs
    for _init, epic, gi in flat_epics:
        col_x = COL_START_X + gi * (COL_W + COL_GAP)

        for area in areas:
            cell_data = grid.get((area, gi), {"features": [], "orphans": []})
            cell_y = row_y[area] + CELL_PAD_TOP

            for feat in cell_data["features"]:
                pbis = feat.get("pbis", [])
                lh = feat_label_h(feat["title"], feat["id"])
                fh = feat_height(len(pbis), lh)
                fx = col_x + FEAT_INSET
                fw = COL_W - FEAT_INSET * 2

                cell_fn(f"feat_{feat['id']}",
                        f"#{feat['id']} {feat['title']}",
                        S_FEAT, fx, cell_y, fw, fh)

                for pi, pbi in enumerate(pbis):
                    px = fx + PBI_INSET
                    py = cell_y + lh + pi * (PBI_H + PBI_GAP)
                    pw = fw - PBI_INSET * 2
                    cell_fn(f"pbi_{pbi['id']}",
                            f"#{pbi['id']} {pbi['title']}",
                            S_PBI, px, py, pw, PBI_H)

                cell_y += fh + FEAT_GAP

            for opbi in cell_data["orphans"]:
                px = col_x + FEAT_INSET + PBI_INSET
                py = cell_y + 5
                pw = COL_W - (FEAT_INSET + PBI_INSET) * 2
                cell_fn(f"pbi_{opbi['id']}",
                        f"#{opbi['id']} {opbi['title']}",
                        S_PBI, px, py, pw, PBI_H)
                cell_y += PBI_H + FEAT_PAD_BOTTOM + FEAT_GAP


def generate_diagram(data, project, extracted_date):
    """Generate a single drawio diagram with sections stacked vertically."""
    initiatives = data["initiatives"]
    groups = find_initiative_groups(initiatives)
    sections = [compute_section(g) for g in groups]

    # Filter out empty sections (no epics with content)
    sections = [s for s in sections if s["flat_epics"]]

    # Compute page width from widest section
    max_grid_w = max(s["grid_w"] for s in sections) if sections else COL_W
    page_w = max(COL_START_X + max_grid_w + 100, 1200)

    # Stack sections vertically
    section_y_list = []
    cy = TITLE_AREA_H
    for sec in sections:
        section_y_list.append(cy)
        cy += sec["total_h"] + SECTION_GAP

    # Legend
    legend_h = 130
    legend_y = cy
    page_h = max(legend_y + legend_h + 50, 800)

    # Total content height for rotated header positioning
    total_content_h = cy - TITLE_AREA_H

    # Build XML
    diagram = ET.Element("diagram", name=project, id="page_0")
    model = ET.SubElement(diagram, "mxGraphModel",
        dx="0", dy="0", grid="1", gridSize="10", guides="1", tooltips="1",
        connect="1", arrows="1", fold="1", page="1", pageScale="1",
        pageWidth=str(int(page_w)), pageHeight=str(int(page_h)),
        background="light-dark(#FFFFFF,#FFFFFF)", math="0", shadow="0")
    root_el = ET.SubElement(model, "root")
    ET.SubElement(root_el, "mxCell", id="0")
    ET.SubElement(root_el, "mxCell", id="1", parent="0")

    def cell(cid, value, style, x, y, w, h):
        el = ET.SubElement(root_el, "mxCell", id=cid, value=value,
                           style=style, parent="1", vertex="1")
        geo = ET.SubElement(el, "mxGeometry",
                            x=str(int(x)), y=str(int(y)),
                            width=str(int(w)), height=str(int(h)))
        geo.set("as", "geometry")

    # Title + subtitle
    cell("title",
         f"{project}: Work Item Hierarchy \u2014 Area Paths x Business Domains",
         S_TITLE, 300, 15, max(max_grid_w + 100, 900), 35)
    cell("subtitle",
         f"Area paths (rows) = system/component  |  Epics (columns) = ownership domain  "
         f"|  Features = aggregation of PBIs  |  {extracted_date}",
         S_SUBTITLE, 250, 48, max(max_grid_w + 100, 1000), 25)

    # Area rotated header (centered over full content)
    cell("area_hdr", "Area Paths\n(Systems)", S_ROTATED_HEADER,
         15, TITLE_AREA_H + total_content_h // 2 - 40, 80, 80)

    # Render each section
    for si, (sec, sec_y) in enumerate(zip(sections, section_y_list)):
        render_section(cell, sec, sec_y, si)

    # Legend
    cell("legend_bg", "", S_LEGEND_BG, COL_START_X, legend_y, 800, legend_h)
    cell("legend_title", "Legend", S_LEGEND_TITLE,
         COL_START_X + 15, legend_y + 8, 100, 25)

    legend_items = [
        ("#e1d5e7", "#9673a6", "rounded=1",
         "Initiative \u2014 the top-level strategic goal"),
        ("#dae8fc", "#6c8ebf", "rounded=1",
         "Epic \u2014 ownership domain (who is responsible)"),
        ("#d5e8d4", "#82b366", "rounded=1",
         "Area Path \u2014 the system or component (where code runs)"),
        ("#fff2cc", "#d6b656", "rounded=1;dashed=1;strokeWidth=2;opacity=60",
         "Feature \u2014 aggregation of related PBIs under an Epic"),
        ("#f8cecc", "#b85450", "rounded=0",
         "PBI \u2014 deliverable work item, area path = who does the work"),
    ]
    for li, (fill, stroke, shape, desc) in enumerate(legend_items):
        ly = legend_y + 38 + li * 18
        swatch_style = f"whiteSpace=wrap;html=1;fillColor={fill};strokeColor={stroke};{shape};"
        cell(f"leg{li}", "", swatch_style, COL_START_X + 15, ly, 14, 14)
        cell(f"leg{li}t", desc, S_TEXT, COL_START_X + 38, ly, 420, 14)

    # Stats
    total_epics = sum(len(s["flat_epics"]) for s in sections)
    all_areas = set()
    for s in sections:
        all_areas.update(s["areas"])
    total_features = sum(
        len(e.get("features", [])) for s in sections for _i, e, _g in s["flat_epics"]
    )
    total_pbis = sum(
        len(f.get("pbis", []))
        for s in sections for _i, e, _g in s["flat_epics"]
        for f in e.get("features", [])
    ) + sum(
        len(e.get("orphan_pbis", []))
        for s in sections for _i, e, _g in s["flat_epics"]
    )
    stats = {
        "page_w": int(page_w), "page_h": int(page_h),
        "groups": len(sections), "initiatives": sum(len(s["initiatives"]) for s in sections),
        "epics": total_epics, "areas": len(all_areas),
        "features": total_features, "pbis": total_pbis,
    }
    return diagram, stats, sections


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

    diagram, stats, sections = generate_diagram(data, project, extracted)

    mxfile = ET.Element("mxfile", host="gen-hierarchy", pages="1")
    mxfile.append(diagram)

    print(f"Single page '{project}':", file=sys.stderr)
    print(f"  Size: {stats['page_w']}x{stats['page_h']}", file=sys.stderr)
    print(f"  Groups: {stats['groups']}, Initiatives: {stats['initiatives']}", file=sys.stderr)
    print(f"  Epics: {stats['epics']}, Areas: {stats['areas']}", file=sys.stderr)
    print(f"  Features: {stats['features']}, PBIs: {stats['pbis']}", file=sys.stderr)
    for si, sec in enumerate(sections):
        names = ", ".join(i["title"] for i in sec["initiatives"])
        print(f"  Section {si + 1}: [{names}] — {len(sec['flat_epics'])} epics, "
              f"{len(sec['areas'])} areas, {sec['grid_w']}px wide", file=sys.stderr)

    tree = ET.ElementTree(mxfile)
    ET.indent(tree, space="    ")

    if args.stdout:
        tree.write(sys.stdout, encoding="unicode", xml_declaration=False)
    else:
        out_file = args.output or os.path.splitext(args.input)[0] + ".drawio"
        tree.write(out_file, encoding="unicode", xml_declaration=False)
        print(f"\nGenerated {out_file}", file=sys.stderr)


if __name__ == "__main__":
    main()
