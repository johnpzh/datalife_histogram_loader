#!/usr/bin/env python3
"""Summarize DataLife legacy histograms (*_r_stat / *_w_stat) with pandas.

Input (positional):
  * the flat DataLife output directory (files <file>_<pid>_{r,w}_stat plus
    monitor_timer.<pid>-<host>.datalife.json). Give --rules or --schema to label
    processes with tasks (same rule files as sort_datalife_stats_by_task.py);
    without rules every process is reported under task '.'.
  * or a per-task layout made by sort_datalife_stats_by_task.py --mode task
    (<layout>/<task>/<file>_<pid>_{r,w}_stat); the directory names are the tasks.

Outputs (in --output-dir):
  histogram_per_process_file.csv   one row per (task, pid, file, op) (+ host/program when timer files are found)
  histogram_per_task.csv           per task x op
  histogram_per_file.csv           per file x op
  stage_sankey.html                stage-level Sankey: tasks x file groups, link width = weighted GB

Columns: bytes_weighted = sum(frequency*access_size); bytes_unique = sum(access_size);
accesses = sum(frequency); unique_blocks = rows; reread_blocks = rows with frequency>1;
extent_bytes = (max block+1)*block_size (file-size proxy). Per task: processes = distinct
pids, files = distinct file names, stat_files = (pid, file) pairs, metrics summed.

File groups for the Sankey (first that applies):
  --groups FILE.json     [{"pattern": "<regex>", "group": "<label>"}, ...]   explicit labels
  --rules / --schema     labels derived from the rule patterns (e.g. chrNn-N-N.tar.gz)
  (default)              built-in 1KG groups
  fallback               file name with digit runs replaced by <N>
"""
import argparse, collections, os, re, sys, types
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sort_datalife_stats_by_task as sorter  # PAT, nonempty, read_timers, load_rules, classify

GROUPS_1KG = [
    (r"chr\d+n-\d+-\d+\.tar\.gz", "chrN chunk archives"),
    (r"chr\d+n\.tar\.gz", "chrN merged archives"),
    (r"chr\d+-[A-Z]{3}-freq\.tar\.gz", "chrN-POP-freq archives"),
    (r"chr\d+-[A-Z]{3}\.tar\.gz", "chrN-POP archives"),
    (r"ALL\.chr\d+\.250000\.vcf", "ALL.chrN.250000.vcf (input)"),
    (r"ALL\.chr\d+\.phase3.*annotation\.vcf", "annotation vcf (input)"),
    (r"sifted\.SIFT\.chr\d+\.txt", "sifted.SIFT.chrN.txt"),
    (r"SIFT\.chr\d+\.vcf", "SIFT.chrN.vcf"),
]


def readable(regex):
    """Turn a rule regex into a readable group label: chr\\d+n-\\d+-\\d+\\.tar\\.gz -> chrNn-N-N.tar.gz."""
    s = regex.strip("^$")
    s = re.sub(r"\\d\+", "N", s); s = re.sub(r"\[A-Z\]\{3\}", "POP", s); s = s.replace(".*", "*")
    s = re.sub(r"\\(.)", r"\1", s)
    return s


def build_groups(args):
    """Return [(compiled regex, label), ...] in priority order."""
    if args.groups:
        import json
        return [(re.compile(g["pattern"]), g["group"]) for g in json.load(open(args.groups))]
    if args.rules or args.schema:
        pats = []
        for rule in sorter.load_rules(args):
            for op, rx in rule["any_of"] + rule["all_of"] + rule["none_of"]:
                if rx.pattern not in [p.pattern for p, _ in pats]:
                    pats.append((rx, readable(rx.pattern)))
        return pats
    return [(re.compile(rx), label) for rx, label in GROUPS_1KG]


def group_of(name, groups):
    return next((label for rx, label in groups if rx.fullmatch(name)), re.sub(r"\d+", "<N>", name))


def collect(args):
    """Yield (task, path, name, pid, op); tasks from subdirectories, or from rules on a flat directory."""
    root = args.input_dir
    subdirs = [d for d in sorted(os.listdir(root)) if os.path.isdir(os.path.join(root, d))]
    if subdirs:  # per-task layout
        for task in subdirs:
            for f in sorted(os.listdir(os.path.join(root, task))):
                m = sorter.PAT.match(f)
                if m:
                    yield task, os.path.join(root, task, f), m["name"], m["pid"], m["op"]
        return
    files = {}
    for f in sorted(os.listdir(root)):
        m = sorter.PAT.match(f)
        if m and sorter.nonempty(os.path.join(root, f)):
            files[(m["pid"], m["op"], m["name"])] = os.path.join(root, f)
    if args.rules or args.schema:
        touched = {}
        for (pid, op, name) in files:
            touched.setdefault(pid, {"r": set(), "w": set()})[op].add(name)
        task = sorter.classify(touched, sorter.load_rules(args), sorter.read_timers(root))
    else:
        task = collections.defaultdict(lambda: ".")
        print("note: flat directory without --rules/--schema: all processes reported under task '.'", file=sys.stderr)
    for (pid, op, name), path in files.items():
        yield task[pid], path, name, pid, op


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("input_dir", help="flat DataLife output directory or a per-task layout")
    ap.add_argument("--output-dir", required=True)
    ap.add_argument("--rules", help="rules JSON (see sort_datalife_stats_by_task.py); labels a flat directory and derives Sankey groups")
    ap.add_argument("--schema", help="dpm-classic/widget workflow schema JSON (alternative to --rules)")
    ap.add_argument("--groups", help="explicit Sankey file groups: [{pattern, group}, ...]")
    ap.add_argument("--timers-dir", help="directory with monitor_timer.*.datalife.json (default: input_dir)")
    ap.add_argument("--block-size", type=int, default=4096)
    ap.add_argument("--no-sankey", action="store_true")
    a = ap.parse_args(); os.makedirs(a.output_dir, exist_ok=True)

    timers = sorter.read_timers(a.timers_dir or a.input_dir)
    rows = []
    for task, path, name, pid, op in collect(a):
        df = pd.read_csv(path, sep=" ", names=["block", "frequency", "access_size"], skiprows=1)
        df = df[df.frequency > 0]
        if df.empty:
            continue
        host, prog, _ = timers.get(pid, ("", "", ""))
        rows.append(dict(task=task, pid=int(pid), host=host, program=prog, file=name, op="read" if op == "r" else "write",
                         bytes_weighted=int((df.frequency * df.access_size).sum()), bytes_unique=int(df.access_size.sum()),
                         accesses=int(df.frequency.sum()), unique_blocks=int(len(df)), reread_blocks=int((df.frequency > 1).sum()),
                         extent_bytes=int((df.block.max() + 1) * a.block_size), mean_access_size=float(df.access_size.mean())))
    if not rows:
        sys.exit("no non-empty *_r_stat/*_w_stat files found")
    d = pd.DataFrame(rows).sort_values(["task", "pid", "file", "op"])
    d.to_csv(os.path.join(a.output_dir, "histogram_per_process_file.csv"), index=False)

    per_task = d.groupby(["task", "op"]).agg(processes=("pid", "nunique"), files=("file", "nunique"), stat_files=("file", "size"),
                                            bytes_weighted=("bytes_weighted", "sum"), bytes_unique=("bytes_unique", "sum"),
                                            accesses=("accesses", "sum"), unique_blocks=("unique_blocks", "sum"),
                                            reread_blocks=("reread_blocks", "sum")).reset_index()
    per_task["GB_weighted"] = per_task.bytes_weighted / 1e9
    per_task.to_csv(os.path.join(a.output_dir, "histogram_per_task.csv"), index=False)

    per_file = d.groupby(["file", "op"]).agg(processes=("pid", "nunique"), tasks=("task", lambda s: " ".join(sorted(set(s)))),
                                            bytes_weighted=("bytes_weighted", "sum"), bytes_unique=("bytes_unique", "sum"),
                                            extent_bytes=("extent_bytes", "max")).reset_index()
    per_file.to_csv(os.path.join(a.output_dir, "histogram_per_file.csv"), index=False)

    print(per_task.to_string(index=False))
    print(f"\ntotals: read {int(d[d.op=='read'].bytes_weighted.sum())} B, write {int(d[d.op=='write'].bytes_weighted.sum())} B (weighted)")

    if not a.no_sankey:
        groups = build_groups(a)
        edges = collections.Counter()
        for r in d.itertuples():
            g = group_of(r.file, groups)
            edges[(g, r.task) if r.op == "read" else (r.task, g)] += r.bytes_weighted
        labels = sorted({k for e in edges for k in e}); idx = {l: i for i, l in enumerate(labels)}
        print("\nstage edges (GB):"); [print(f"  {s:>34} -> {t:<34} {v/1e9:9.3f}") for (s, t), v in sorted(edges.items(), key=lambda kv: -kv[1])]
        try:
            import plotly.graph_objects as go
            fig = go.Figure(go.Sankey(node=dict(label=labels, pad=15),
                                      link=dict(source=[idx[s] for s, t in edges], target=[idx[t] for s, t in edges],
                                                value=[v / 1e9 for v in edges.values()], label=[f"{v/1e9:.3f} GB" for v in edges.values()])))
            fig.update_layout(title=f"Stage-level data flow from DataLife histograms ({a.input_dir}); link width = GB (frequency x access_size)")
            fig.write_html(os.path.join(a.output_dir, "stage_sankey.html"))
        except ImportError:
            print("plotly not installed: skipping stage_sankey.html")
    print("\nwritten to", a.output_dir)


if __name__ == "__main__":
    main()
