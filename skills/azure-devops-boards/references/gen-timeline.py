#!/usr/bin/env python3
"""Generate timeline drawio diagram from JSON data.

X axis = iterations (sorted by start date), Y axis = area paths.
Only PBIs in iterations with start/finish dates are shown.

Output defaults to {input_basename}-timeline.drawio in the current directory.
Override with --output FILE or use --stdout to print to stdout.

Usage:
    python3 gen-timeline.py INPUT_JSON
"""
import argparse
import json
import os
import sys
import xml.etree.ElementTree as ET

# --- Layout constants ---
COL_W = 230
COL_GAP = 20
ROW_GAP = 20
COL_START_X = 270
PBI_H = 28
PBI_GAP = 6
PBI_INSET = 8
CELL_PAD_TOP = 12
CELL_PAD_BOTTOM = 12
AREA_LABEL_X = 100
AREA_LABEL_W = 140
LANE_EXTEND_H = 30
LANE_EXTEND_V = 23
MIN_ROW_H = 60
HEADER_H = 50

# Styles
S_TITLE = "text;html=1;fontSize=18;fontStyle=1;align=center;verticalAlign=middle;"
S_SUBTITLE = "text;html=1;fontSize=11;fontStyle=2;align=center;verticalAlign=middle;fontColor=#666666;"
S_HEADER = "text;html=1;fontSize=12;fontStyle=5;align=center;verticalAlign=middle;fontColor=#333333;"
S_ROTATED_HEADER = "text;html=1;fontSize=12;fontStyle=5;align=center;verticalAlign=middle;fontColor=#333333;rotation=-90;"
S_AREA = "rounded=1;whiteSpace=wrap;html=1;fontSize=12;fontStyle=1;fillColor=#d5e8d4;strokeColor=#82b366;verticalAlign=middle;"
S_AREA_LANE = "rounded=0;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;opacity=40;dashed=1;dashPattern=12 6;strokeWidth=2;"
S_ITER_LANE = "rounded=0;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;opacity=40;dashed=1;dashPattern=12 6;strokeWidth=2;"
S_PBI = "rounded=0;whiteSpace=wrap;html=1;fontSize=8;fillColor=#f8cecc;strokeColor=#b85450;verticalAlign=middle;"
S_LEGEND_BG = "rounded=1;whiteSpace=wrap;html=1;fillColor=#ffffff;strokeColor=#cccccc;"
S_LEGEND_TITLE = "text;html=1;fontSize=12;fontStyle=1;align=left;verticalAlign=middle;"
S_TEXT = "text;html=1;fontSize=10;align=left;verticalAlign=middle;"

# Iteration header colour palette by track
TRACK_COLOURS = [
    ("#dae8fc", "#6c8ebf"),  # Blue (default/first track)
    ("#e1d5e7", "#9673a6"),  # Purple (second track)
    ("#fff2cc", "#d6b656"),  # Yellow (third)
    ("#d5e8d4", "#82b366"),  # Green (fourth)
]


def iter_sort_key(path, iterations):
    """Sort key: (start_date, finish_date, path_name)."""
    info = iterations.get(path, {})
    return (info.get("start", ""), info.get("finish", ""), path)


def iter_label(path):
    """Extract short label from iteration path (last segment)."""
    return path.split("\\")[-1]


def iter_track(path):
    """Extract track name from iteration path (first segment)."""
    return path.split("\\")[0]


def format_date(iso_date):
    """Format '2026-01-16' as 'Jan 16'."""
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
              "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    parts = iso_date.split("-")
    month = months[int(parts[1]) - 1]
    day = int(parts[2])
    return f"{month} {day}"


def collect_scheduled_pbis(data):
    """Collect all PBIs that are in iterations with dates."""
    iterations = data.get("iterations", {})
    dated = {k for k, v in iterations.items() if "start" in v}

    pbis = []
    for init in data["initiatives"]:
        for epic in init["epics"]:
            for feat in epic.get("features", []):
                for pbi in feat.get("pbis", []):
                    if pbi.get("iteration") in dated:
                        pbis.append(pbi)
            for opbi in epic.get("orphan_pbis", []):
                if opbi.get("iteration") in dated:
                    pbis.append(opbi)
    return pbis


def discover_areas(pbis):
    """Discover unique area paths from PBIs, sorted alphabetically."""
    return sorted(set(p["area"] for p in pbis))


def build_grid(pbis, iter_order, areas):
    """Build mapping of (area, iter_idx) -> list of PBIs."""
    iter_idx = {path: i for i, path in enumerate(iter_order)}
    grid = {}
    for pbi in pbis:
        ai = pbi["area"]
        ii = iter_idx.get(pbi["iteration"])
        if ii is not None and ai in areas:
            key = (ai, ii)
            grid.setdefault(key, []).append(pbi)
    return grid


def calc_row_heights(areas, num_iters, grid):
    """Calculate height needed for each area row."""
    row_heights = {}
    for area in areas:
        max_pbis = 0
        for ii in range(num_iters):
            n = len(grid.get((area, ii), []))
            max_pbis = max(max_pbis, n)
        content_h = CELL_PAD_TOP + max_pbis * (PBI_H + PBI_GAP) - PBI_GAP + CELL_PAD_BOTTOM if max_pbis > 0 else 0
        row_heights[area] = max(content_h, MIN_ROW_H)
    return row_heights


def generate_page(data, page_id):
    """Generate timeline drawio page."""
    project = data.get("project", "Project")
    extracted = data.get("extracted", "")
    iterations = data.get("iterations", {})

    pbis = collect_scheduled_pbis(data)
    if not pbis:
        print("  No scheduled PBIs found", file=sys.stderr)
        return None, None

    areas = discover_areas(pbis)

    # Get dated iterations and sort
    dated_paths = [k for k, v in iterations.items() if "start" in v]
    iter_order = sorted(dated_paths, key=lambda p: iter_sort_key(p, iterations))

    num_iters = len(iter_order)
    grid = build_grid(pbis, iter_order, areas)
    row_heights = calc_row_heights(areas, num_iters, grid)

    # Track colours
    tracks = []
    seen_tracks = {}
    for path in iter_order:
        t = iter_track(path)
        if t not in seen_tracks:
            seen_tracks[t] = len(seen_tracks)
        tracks.append(seen_tracks[t])

    grid_w = num_iters * (COL_W + COL_GAP) - COL_GAP

    # Row Y positions
    GRID_Y = 180
    row_y = {}
    cy = GRID_Y
    for i, area in enumerate(areas):
        row_y[area] = cy
        cy += row_heights[area]
        if i < len(areas) - 1:
            cy += ROW_GAP
    total_grid_h = cy - GRID_Y

    # Legend
    legend_h = 100
    legend_y = GRID_Y + total_grid_h + LANE_EXTEND_V + 22

    # Page dimensions
    page_w = max(COL_START_X + grid_w + 100, 1200)
    page_h = max(legend_y + legend_h + 50, 800)

    # Build XML
    diagram = ET.Element("diagram", name=f"{project} Timeline", id=page_id)
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
         f"{project}: Timeline View \u2014 Area Paths x Iterations",
         S_TITLE, 300, 15, max(grid_w + 100, 900), 35)
    cell("subtitle",
         f"Area paths (rows) = system/component  |  Iterations (columns) = scheduled time period  |  Only PBIs in dated iterations shown  |  {extracted}",
         S_SUBTITLE, 250, 48, max(grid_w + 100, 1000), 25)

    # Iteration axis header
    cell("iter_hdr", "Iterations (Scheduled Work)", S_HEADER,
         COL_START_X, 80, grid_w, 20)

    # Area rotated header
    cell("area_hdr", "Area Paths\n(Systems)", S_ROTATED_HEADER,
         15, GRID_Y + total_grid_h // 2 - 40, 80, 80)

    # Iteration column headers
    for i, path in enumerate(iter_order):
        x = COL_START_X + i * (COL_W + COL_GAP)
        info = iterations[path]
        label = iter_label(path)
        date_range = f"{format_date(info['start'])} \u2013 {format_date(info['finish'])}"
        value = f'{label}<br><font style="font-size:8px;font-weight:normal">{date_range}</font>'
        tidx = tracks[i] % len(TRACK_COLOURS)
        fill, stroke = TRACK_COLOURS[tidx]
        style = f"rounded=1;whiteSpace=wrap;html=1;fontSize=10;fontStyle=1;fillColor={fill};strokeColor={stroke};verticalAlign=middle;"
        cell(f"iter_{i}", value, style, x, 105, COL_W, HEADER_H)

    # Iteration column lanes
    lane_top = GRID_Y - LANE_EXTEND_V
    lane_h = total_grid_h + LANE_EXTEND_V * 2
    for i in range(num_iters):
        x = COL_START_X + i * (COL_W + COL_GAP)
        cell(f"ilane_{i}", "", S_ITER_LANE, x, lane_top, COL_W, lane_h)

    # Area row labels and lanes
    area_lane_left = COL_START_X - LANE_EXTEND_H
    area_lane_w = grid_w + LANE_EXTEND_H * 2
    for area in areas:
        y = row_y[area]
        h = row_heights[area]
        safe = area.lower().replace(" ", "_").replace("\\", "_")
        cell(f"area_{safe}", area, S_AREA,
             AREA_LABEL_X, y + h // 2 - 20, AREA_LABEL_W, 40)
        cell(f"lane_{safe}", "", S_AREA_LANE,
             area_lane_left, y, area_lane_w, h)

    # PBIs
    for ii, path in enumerate(iter_order):
        col_x = COL_START_X + ii * (COL_W + COL_GAP)
        pw = COL_W - PBI_INSET * 2

        for area in areas:
            cell_pbis = grid.get((area, ii), [])
            for pi, pbi in enumerate(cell_pbis):
                px = col_x + PBI_INSET
                py = row_y[area] + CELL_PAD_TOP + pi * (PBI_H + PBI_GAP)
                cell(f"pbi_{pbi['id']}", f"#{pbi['id']} {pbi['title']}", S_PBI,
                     px, py, pw, PBI_H)

    # Legend
    cell("legend_bg", "", S_LEGEND_BG, COL_START_X, legend_y, 800, legend_h)
    cell("legend_title", "Legend", S_LEGEND_TITLE, COL_START_X + 15, legend_y + 8, 100, 25)

    legend_items = [
        ("#d5e8d4", "#82b366", "rounded=1", "Area Path \u2014 the system or component"),
        ("#f8cecc", "#b85450", "rounded=0", "PBI \u2014 deliverable work item"),
    ]

    for li, (fill, stroke, shape, desc) in enumerate(legend_items):
        ly = legend_y + 38 + li * 18
        swatch_style = f"whiteSpace=wrap;html=1;fillColor={fill};strokeColor={stroke};{shape};"
        cell(f"leg{li}", "", swatch_style, COL_START_X + 15, ly, 14, 14)
        cell(f"leg{li}t", desc, S_TEXT, COL_START_X + 38, ly, 420, 14)

    stats = {
        "page_w": int(page_w), "page_h": int(page_h),
        "iterations": num_iters, "areas": len(areas),
        "pbis": len(pbis), "grid_h": total_grid_h,
    }
    return diagram, stats


def main():
    parser = argparse.ArgumentParser(description="Generate timeline drawio from JSON")
    parser.add_argument("input", help="Input JSON file")
    parser.add_argument("--output", help="Output drawio file (default: {input}-timeline.drawio)")
    parser.add_argument("--stdout", action="store_true", help="Print to stdout instead of file")
    args = parser.parse_args()

    with open(args.input) as f:
        data = json.load(f)

    mxfile = ET.Element("mxfile", host="gen-timeline", pages="1")

    diagram, stats = generate_page(data, "timeline_page")
    if diagram is None:
        print("No scheduled work found.", file=sys.stderr)
        sys.exit(1)

    mxfile.append(diagram)
    print(f"Timeline:", file=sys.stderr)
    print(f"  Size: {stats['page_w']}x{stats['page_h']}", file=sys.stderr)
    print(f"  Iterations: {stats['iterations']}, Areas: {stats['areas']}", file=sys.stderr)
    print(f"  PBIs: {stats['pbis']}", file=sys.stderr)

    tree = ET.ElementTree(mxfile)
    ET.indent(tree, space="    ")

    if args.stdout:
        tree.write(sys.stdout, encoding="unicode", xml_declaration=False)
    else:
        out_file = args.output or os.path.splitext(args.input)[0] + "-timeline.drawio"
        tree.write(out_file, encoding="unicode", xml_declaration=False)
        print(f"\nGenerated {out_file}", file=sys.stderr)


if __name__ == "__main__":
    main()
