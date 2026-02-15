#!/usr/bin/env python3
"""Extract work item hierarchy from Azure DevOps into JSON.

Usage:
    cd output/
    python3 extract-hierarchy.py --org ORG --project PROJECT --initiatives ID[,ID,...]

Output defaults to {project}-hierarchy.json in the current directory.
Override with --output FILE or use --stdout to print to stdout.

Examples:
    python3 extract-hierarchy.py --org flightrac --project Flightrac --initiatives 36
    python3 extract-hierarchy.py --org eagersautomotive --project EagersProject --initiatives 100,"My Initiative"
    python3 extract-hierarchy.py --org flightrac --project Flightrac --initiatives 36 --output custom.json
"""
import argparse
import json
import subprocess
import sys
from datetime import date

RESOURCE_ID = "499b84ac-1321-427f-aa17-267ca6975798"


def az_rest_get(uri):
    """GET via az rest, return parsed JSON."""
    result = subprocess.run(
        ["az", "rest", "--method", "GET", "--uri", uri, "--resource", RESOURCE_ID],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        print(f"GET failed:\n{result.stderr.strip()}", file=sys.stderr)
        sys.exit(1)
    return json.loads(result.stdout)


def get_work_items(ids, org_url, expand_relations=False):
    """Batch-get work items by ID (max 200 per call)."""
    if not ids:
        return []
    ids_str = ",".join(str(i) for i in ids)
    uri = f"{org_url}/_apis/wit/workitems?ids={ids_str}&api-version=7.1"
    if expand_relations:
        uri += "&$expand=relations"
    data = az_rest_get(uri)
    return data.get("value", [])


def get_child_ids(item):
    """Extract child work item IDs from forward hierarchy relations."""
    return [
        int(r["url"].split("/")[-1])
        for r in (item.get("relations") or [])
        if r.get("rel") == "System.LinkTypes.Hierarchy-Forward"
    ]


def resolve_id(name_or_id, project, org_url):
    """Resolve a work item by numeric ID or title search."""
    try:
        return int(name_or_id)
    except ValueError:
        escaped = name_or_id.replace("'", "''")
        wiql = (
            f"SELECT [System.Id] FROM WorkItems "
            f"WHERE [System.Title] = '{escaped}' "
            f"AND [System.State] <> 'Removed'"
        )
        result = subprocess.run(
            ["az", "rest", "--method", "POST",
             "--uri", f"{org_url}/{project}/_apis/wit/wiql?api-version=7.1",
             "--resource", RESOURCE_ID,
             "--headers", "Content-Type=application/json",
             "--body", json.dumps({"query": wiql})],
            capture_output=True, text=True,
        )
        if result.returncode != 0:
            print(f"WIQL search failed:\n{result.stderr.strip()}", file=sys.stderr)
            sys.exit(1)
        data = json.loads(result.stdout)
        items = data.get("workItems", [])
        if not items:
            print(f"Error: No work item found with title '{name_or_id}'", file=sys.stderr)
            sys.exit(1)
        if len(items) > 1:
            print(f"Warning: Multiple matches for '{name_or_id}', using first (#{items[0]['id']})", file=sys.stderr)
        return items[0]["id"]


def strip_project(area_path, project):
    """Strip project prefix from area path: 'Project\\Area' -> 'Area'."""
    prefix = project + "\\"
    return area_path[len(prefix):] if area_path.startswith(prefix) else area_path


def collect_iterations(initiatives):
    """Collect unique iteration paths from all PBIs across initiatives."""
    iterations = set()
    for init in initiatives:
        for epic in init["epics"]:
            for feat in epic.get("features", []):
                for pbi in feat.get("pbis", []):
                    iterations.add(pbi.get("iteration", ""))
            for opbi in epic.get("orphan_pbis", []):
                iterations.add(opbi.get("iteration", ""))
    iterations.discard("")
    return sorted(iterations)


def fetch_iteration_dates(iteration_paths, project, org_url):
    """Fetch start/finish dates for iteration paths from classification nodes API."""
    uri = f"{org_url}/{project}/_apis/wit/classificationNodes/Iterations?$depth=10&api-version=7.1"
    data = az_rest_get(uri)

    # Flatten the iteration tree into a path -> node map
    nodes = {}

    def walk(node, prefix=""):
        name = node.get("name", "")
        path = f"{prefix}\\{name}" if prefix else name
        attrs = node.get("attributes", {})
        nodes[path] = {
            "start": attrs.get("startDate"),
            "finish": attrs.get("finishDate"),
        }
        for child in node.get("children", []):
            walk(child, path)

    for child in data.get("children", []):
        walk(child)

    # Match requested paths to nodes
    result = {}
    for ip in iteration_paths:
        node = nodes.get(ip, {})
        entry = {"path": ip}
        if node.get("start"):
            entry["start"] = node["start"][:10]  # "2026-01-01T00:00:00Z" -> "2026-01-01"
        if node.get("finish"):
            entry["finish"] = node["finish"][:10]
        result[ip] = entry

    return result


def extract(root_id, project, org_url):
    """Walk hierarchy: root -> epics -> features -> PBIs."""
    # Level 0: root
    roots = get_work_items([root_id], org_url, expand_relations=True)
    if not roots:
        print(f"Error: Work item #{root_id} not found", file=sys.stderr)
        sys.exit(1)
    root = roots[0]
    root_title = root["fields"]["System.Title"]
    print(f"  #{root_id}: {root_title}", file=sys.stderr)

    # Level 1: epics
    epic_ids = get_child_ids(root)
    if not epic_ids:
        print(f"    No children found", file=sys.stderr)
        return {"id": root_id, "title": root_title, "epics": []}

    epic_items = get_work_items(epic_ids, org_url, expand_relations=True)
    print(f"    {len(epic_items)} epics", file=sys.stderr)

    # Level 2: features + orphans
    level2_ids = []
    level2_parent = {}
    for epic in epic_items:
        for cid in get_child_ids(epic):
            level2_ids.append(cid)
            level2_parent[cid] = epic["id"]

    level2_items = get_work_items(level2_ids, org_url, expand_relations=True) if level2_ids else []
    level2_items = [i for i in level2_items if i["fields"]["System.State"] != "Removed"]
    features = [i for i in level2_items if i["fields"]["System.WorkItemType"] == "Feature"]
    orphans = [i for i in level2_items if i["fields"]["System.WorkItemType"] != "Feature"]
    print(f"    {len(features)} features, {len(orphans)} orphan items", file=sys.stderr)

    # Level 3: PBIs
    level3_ids = []
    level3_parent = {}
    for feat in features:
        for cid in get_child_ids(feat):
            level3_ids.append(cid)
            level3_parent[cid] = feat["id"]

    level3_items = get_work_items(level3_ids, org_url) if level3_ids else []
    level3_items = [i for i in level3_items if i["fields"]["System.State"] != "Removed"]
    print(f"    {len(level3_items)} PBIs", file=sys.stderr)

    # Group by parent
    pbis_by_feat = {}
    for pbi in level3_items:
        pid = level3_parent.get(pbi["id"])
        if pid is not None:
            pbis_by_feat.setdefault(pid, []).append(pbi)

    feats_by_epic = {}
    for feat in features:
        pid = level2_parent.get(feat["id"])
        if pid is not None:
            feats_by_epic.setdefault(pid, []).append(feat)

    orphans_by_epic = {}
    for orph in orphans:
        pid = level2_parent.get(orph["id"])
        if pid is not None:
            orphans_by_epic.setdefault(pid, []).append(orph)

    # Assemble
    epics_out = []
    for epic in epic_items:
        eid = epic["id"]

        feats_out = []
        for feat in feats_by_epic.get(eid, []):
            fid = feat["id"]
            feat_area = strip_project(feat["fields"]["System.AreaPath"], project)
            pbis_out = []
            pbi_areas = []
            for p in pbis_by_feat.get(fid, []):
                pbi_area = strip_project(p["fields"]["System.AreaPath"], project)
                pbi_iteration = strip_project(p["fields"]["System.IterationPath"], project)
                pbis_out.append({"id": p["id"], "title": p["fields"]["System.Title"], "area": pbi_area, "iteration": pbi_iteration})
                if pbi_area != project:
                    pbi_areas.append(pbi_area)
            # If feature is on root area, resolve from PBI areas
            if feat_area == project and pbi_areas:
                from collections import Counter
                feat_area = Counter(pbi_areas).most_common(1)[0][0]
            feats_out.append({
                "id": fid,
                "title": feat["fields"]["System.Title"],
                "area": feat_area,
                "pbis": pbis_out,
            })

        orphans_out = [
            {
                "id": o["id"],
                "title": o["fields"]["System.Title"],
                "area": strip_project(o["fields"]["System.AreaPath"], project),
                "iteration": strip_project(o["fields"]["System.IterationPath"], project),
            }
            for o in orphans_by_epic.get(eid, [])
        ]

        epics_out.append({
            "id": eid,
            "title": epic["fields"]["System.Title"],
            "features": feats_out,
            "orphan_pbis": orphans_out,
        })

    return {"id": root_id, "title": root_title, "epics": epics_out}


def main():
    parser = argparse.ArgumentParser(description="Extract work item hierarchy from Azure DevOps")
    parser.add_argument("--org", required=True, help="Org name or URL")
    parser.add_argument("--project", required=True, help="Project name")
    parser.add_argument("--initiatives", required=True, help="Comma-separated initiative IDs or titles")
    parser.add_argument("--output", help="Output JSON file (default: {project}-hierarchy.json)")
    parser.add_argument("--stdout", action="store_true", help="Print to stdout instead of file")
    args = parser.parse_args()

    org_url = args.org if args.org.startswith("https://") else f"https://dev.azure.com/{args.org}"
    print(f"Extracting from {org_url}/{args.project}", file=sys.stderr)

    initiatives = []
    for ref in [s.strip() for s in args.initiatives.split(",")]:
        item_id = resolve_id(ref, args.project, org_url)
        result = extract(item_id, args.project, org_url)
        if result:
            initiatives.append(result)

    # Fetch iteration dates for all discovered iteration paths
    iteration_paths = collect_iterations(initiatives)
    iteration_dates = fetch_iteration_dates(iteration_paths, args.project, org_url)
    print(f"  {len(iteration_dates)} iterations with dates", file=sys.stderr)

    output = {
        "project": args.project,
        "org": args.org,
        "extracted": str(date.today()),
        "iterations": iteration_dates,
        "initiatives": initiatives,
    }

    text = json.dumps(output, indent=2) + "\n"
    if args.stdout:
        sys.stdout.write(text)
    else:
        out_file = args.output or f"{args.project.lower()}-hierarchy.json"
        with open(out_file, "w") as f:
            f.write(text)
        print(f"Written to {out_file}", file=sys.stderr)


if __name__ == "__main__":
    main()
