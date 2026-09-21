#!/usr/bin/env python3
"""Run datalife/flow-analysis on a per-task or per-instance layout and save reports.

Run with the datalife-analyze-venv (has the `datalife` package, networkx 2.8.8, plotly).

Outputs (<output-dir>/<prefix>_*):
  _stat_summary.txt       DataLife get_stat_summary() (bytes = sum of access_size)
  _ranking_table_GB.csv   producer_consumer_ranking_table (edge bytes = sum frequency*access_size)
  _stage_edges.csv        edges collapsed to task names (instance suffix _<pid> stripped) and file names
  _critical_path.txt      nx.dag_longest_path by bytes
  _caterpillar_edges.csv  caterpillar tree edges
  _graph.pickle           networkx graph (pickle), plus _graph.gpickle when nx.write_gpickle exists
  _sankey.html            DataLife SankeyData rendered headless (with --sankey)
"""
import argparse, collections, os, pickle, re
import networkx as nx, pandas as pd
from datalife.analyze import DataLife, producer_consumer_ranking_table, get_critical_path

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("layout_dir"); ap.add_argument("--output-dir", required=True); ap.add_argument("--prefix", default="datalife")
    ap.add_argument("--sankey", action="store_true", help="also write a Sankey HTML (large for per-instance layouts)")
    a = ap.parse_args(); os.makedirs(a.output_dir, exist_ok=True); P = os.path.join(a.output_dir, a.prefix)
    dl = DataLife(a.prefix); dl.read_stats(a.layout_dir)
    summary = dl.get_stat_summary(); print(summary); open(P + "_stat_summary.txt", "w").write(summary.to_string() + "\n")
    g = dl.get_graph()
    print("graph:", g.number_of_nodes(), "nodes,", g.number_of_edges(), "edges, DAG:", nx.is_directed_acyclic_graph(g))
    rank = producer_consumer_ranking_table(g, unit="GB"); rank.to_csv(P + "_ranking_table_GB.csv", index=False)
    print("top edges (GB):"); print(rank.head(8).to_string(index=False))
    is_task = lambda n: g.nodes[n].get("ntype") == "task"
    stage = lambda n: re.sub(r"_\d+$", "", n) if is_task(n) else n
    agg = collections.Counter()
    for u, v, d in g.edges(data=True):
        agg[(stage(u), stage(v))] += d["value"]
    pd.DataFrame([dict(source=s, target=t, bytes=b, GB=b / 1e9) for (s, t), b in agg.items()]).sort_values("bytes", ascending=False).to_csv(P + "_stage_edges.csv", index=False)
    cp = get_critical_path(g, weight="value"); open(P + "_critical_path.txt", "w").write("\n".join(cp) + "\n"); print("critical path:", cp)
    try:
        ct = dl.caterpillar_tree(weight="value")
        pd.DataFrame([dict(source=u, target=v, **d) for u, v, d in ct.edges(data=True)]).to_csv(P + "_caterpillar_edges.csv", index=False)
        print("caterpillar tree:", ct.number_of_nodes(), "nodes", ct.number_of_edges(), "edges")
    except Exception as e:
        print("caterpillar tree failed:", type(e).__name__, e)
    pickle.dump(g, open(P + "_graph.pickle", "wb"))
    if hasattr(nx, "write_gpickle"):
        nx.write_gpickle(g, P + "_graph.gpickle")
    if a.sankey:
        from datalife.sankeydata import SankeyData
        import plotly.graph_objects as go
        sd = SankeyData(); sd.load_stat_all(dl.get_df_all()); sd.build_links()
        n = sd.nodes[["label", "color"]].to_dict("list"); l = sd.links.to_dict("list")
        go.Figure(data=[go.Sankey(node=n, link=l)]).write_html(P + "_sankey.html")
        print("sankey:", len(sd.nodes), "nodes,", len(sd.links), "links")
    print("written to", a.output_dir, "with prefix", a.prefix)

if __name__ == "__main__":
    main()
