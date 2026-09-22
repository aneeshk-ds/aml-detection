"""Regenerate docs/lineage.md from the dbt manifest.

Usage:
    dbt parse --profiles-dir .
    python3 scripts/render_lineage.py

Reads target/manifest.json so the diagram always matches the built DAG rather than a
hand drawing that can drift. Emits Mermaid, which GitHub renders natively.
"""
import collections
import json

LAYER_ORDER = ["staging", "intermediate", "detection", "graph", "scoring", "evaluation"]


def main():
    m = json.load(open("target/manifest.json", encoding="utf-8"))
    nodes = {k: v for k, v in m["nodes"].items() if v["resource_type"] == "model"}

    layer_of = {v["name"]: (v["fqn"][1] if len(v["fqn"]) > 2 else "other") for v in nodes.values()}
    edges = sorted({
        (nodes[dep]["name"], v["name"])
        for v in nodes.values()
        for dep in v["depends_on"]["nodes"]
        if dep in nodes
    })

    by_layer = collections.OrderedDict((l, []) for l in LAYER_ORDER)
    for name, layer in sorted(layer_of.items()):
        by_layer.setdefault(layer, []).append(name)

    out = ["# Model lineage", ""]
    out.append("Generated from `target/manifest.json`, so it matches the built DAG rather than a hand")
    out.append("drawing. %d models across %d layers, %d dependencies."
               % (len(nodes), len([l for l in by_layer if by_layer[l]]), len(edges)))
    out += ["", "Regenerate with `dbt parse` followed by `python3 scripts/render_lineage.py`.", ""]
    out += ["```mermaid", "graph LR"]
    for layer, names in by_layer.items():
        if not names:
            continue
        out.append("  subgraph %s" % layer)
        out += ["    %s[%s]" % (n, n) for n in names]
        out.append("  end")
    out += ["  %s --> %s" % (a, b) for a, b in edges]
    out.append("```")

    with open("docs/lineage.md", "w", encoding="utf-8") as fh:
        fh.write("\n".join(out) + "\n")
    print("wrote docs/lineage.md: %d models, %d edges" % (len(nodes), len(edges)))


if __name__ == "__main__":
    main()
