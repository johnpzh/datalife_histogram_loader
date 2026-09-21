#!/usr/bin/env python3
"""Sort DataLife legacy histogram files (*_r_stat / *_w_stat) into the per-task
directory layout that datalife/flow-analysis expects.

  --mode task      -> <out>/<task>/<file>_<pid>_{r,w}_stat        (one dir per task; per-stage summary)
  --mode instance  -> <out>/<task>_<pid>/<file>_{r,w}_stat        (one dir per process; DFL graph)

The histograms carry no task name, so the task of a process is inferred from
the files it wrote or read, using an ordered rule list (first match wins):

  built-in default      the 1000-genome rules below (RULES)
  --rules FILE.json     [{"op": "w"|"r", "pattern": "<regex>", "task": "<name>"}, ...]
  --schema FILE.json    a dpm-classic/widget workflow schema (per task: "outputs" regexes and
                        "predecessors": {"<pred>": {"inputs": [regexes]}}); write rules are
                        derived from "outputs" (task order as in the file), read rules from "inputs"

Patterns are matched with re.fullmatch against the file base name. Put write
rules first: a process's outputs identify it best, while inputs are often
shared by several tasks. Read rules are the fallback for read-only helpers
(e.g. a grep child of sifting).

When a single file pattern is not enough (two tasks read the same input and
neither writes anything traced), a rule may add:
  "program": "<regex>"                     fullmatch on the timer's program name (python3, grep, ...)
  "all_of":  [{"op": .., "pattern": ..}]   every entry must match some file of that op   (AND)
  "none_of": [{"op": .., "pattern": ..}]   no entry may match any file of that op        (NOT)
"op"/"pattern" may then be omitted. Example, separating sifting's python
process from its grep child, both reading the annotation VCF:
  {"task": "sifting",      "all_of": [{"op":"r","pattern":".*annotation\\.vcf"}, {"op":"r","pattern":"sifting\\.py"}]}
  {"task": "sifting_grep", "op": "r", "pattern": ".*annotation\\.vcf", "program": "grep"}

Workflow for a new workflow:
  1. python sort_datalife_stats_by_task.py TRACES /dev/null --discover
     -> prints every distinct (program, read patterns, write patterns) signature
        with process counts; digits are replaced by <N> so instances collapse.
  2. write a rules JSON naming those signatures (one write rule per task; add
     read rules only for read-only processes), or reuse a workflow schema.
  3. python sort_datalife_stats_by_task.py TRACES OUT --rules my_rules.json --mode task
     (check the printed "processes per task"; anything unmatched lands in unknown/).

Only non-empty histograms are used (DataLife writes an empty _w_stat for every
opened file). Symlinks are used; the input directory is not modified.
"""
import argparse, collections, csv, json, os, re, shutil, sys

PAT = re.compile(r"^(?P<name>.+)_(?P<pid>\d+)_(?P<op>[rw])_stat$")
TIMER = re.compile(r"^monitor_timer\.(?P<pid>\d+)-(?P<host>[^.]+)\.datalife\.json$")

RULES = [  # default: 1000-genome (portable_1kg) — (op, regex, task), evaluated in order
    ("w", r"chr\d+n-\d+-\d+\.tar\.gz", "individuals"),
    ("w", r"chr\d+n\.tar\.gz", "individuals_merge"),
    ("w", r"sifted\.SIFT\.chr\d+\.txt", "sifting"),
    ("w", r"chr\d+-[A-Z]{3}-freq\.tar\.gz", "frequency"),
    ("w", r"chr\d+-[A-Z]{3}\.tar\.gz", "mutation_overlap"),
    ("r", r"ALL\.chr\d+\.phase3.*annotation\.vcf", "sifting"),
    ("r", r"SIFT\.chr\d+\.vcf", "sifting"),
]


def nonempty(path):
    with open(path) as fh:
        next(fh, None)
        return any(len(p := line.split()) >= 3 and int(p[1]) > 0 for line in fh)


def _cond(d):
    """{op, pattern} -> (op, compiled regex)."""
    if d["op"] not in ("r", "w"):
        sys.exit(f"rule op must be 'r' or 'w': {d}")
    return (d["op"], re.compile(d["pattern"]))


def load_rules(args):
    """Return the ordered rule list. Each rule is a dict:
       task     name to assign
       any_of   [(op, regex), ...]  at least one must match a file of that op (the basic op/pattern rule)
       all_of   [(op, regex), ...]  every entry must match some file of that op
       none_of  [(op, regex), ...]  no entry may match any file of that op
       program  compiled regex on the timer's program name (python3, grep, ...) or None
    """
    if args.rules:
        raw = json.load(open(args.rules))
    elif args.schema:
        schema = json.load(open(args.schema))
        raw = [{"op": "w", "pattern": rx, "task": task} for task, spec in schema.items() for rx in spec.get("outputs", [])]
        raw += [{"op": "r", "pattern": rx, "task": task} for task, spec in schema.items()
                for pred in spec.get("predecessors", {}).values() for rx in pred.get("inputs", [])]
    else:
        raw = [{"op": op, "pattern": rx, "task": task} for op, rx, task in RULES]
    rules = []
    for r in raw:
        rule = {"task": r["task"],
                "any_of": [_cond(r)] if "pattern" in r else [],
                "all_of": [_cond(c) for c in r.get("all_of", [])],
                "none_of": [_cond(c) for c in r.get("none_of", [])],
                "program": re.compile(r["program"]) if r.get("program") else None}
        if not (rule["any_of"] or rule["all_of"] or rule["program"]):
            sys.exit(f"rule needs at least one of op/pattern, all_of or program: {r}")
        rules.append(rule)
    return rules


def classify(touched, rules, timer=None):
    def hit(t, cond):
        op, rx = cond
        return any(rx.fullmatch(n) for n in t[op])
    task = {}
    for pid, t in touched.items():
        prog = (timer or {}).get(pid, ("", "", ""))[1]
        task[pid] = "unknown"
        for rule in rules:
            if rule["program"] and not rule["program"].fullmatch(prog):
                continue
            if rule["any_of"] and not any(hit(t, c) for c in rule["any_of"]):
                continue
            if not all(hit(t, c) for c in rule["all_of"]):
                continue
            if any(hit(t, c) for c in rule["none_of"]):
                continue
            task[pid] = rule["task"]
            break
    return task


def read_timers(input_dir):
    """pid -> (host, program name, timer file name) from monitor_timer.<pid>-<host>.datalife.json."""
    timer = {}
    for f in os.listdir(input_dir):
        m = TIMER.match(f)
        if m:
            try:
                prog = next(iter(json.load(open(os.path.join(input_dir, f))).keys()))
            except Exception:
                prog = ""
            timer[m["pid"]] = (m["host"], prog, f)
    return timer


def discover(touched, timer):
    """Print distinct (program, read patterns, write patterns) signatures with counts."""
    generic = lambda n: re.sub(r"\d+", "<N>", n)
    sig = collections.Counter()
    for pid, t in touched.items():
        prog = timer.get(pid, ("", "", ""))[1]
        sig[(prog, tuple(sorted({generic(n) for n in t["r"]})), tuple(sorted({generic(n) for n in t["w"]})))] += 1
    print(f"{len(touched)} processes, {len(sig)} distinct signatures (digits replaced by <N>):\n")
    for (prog, reads, writes), c in sorted(sig.items(), key=lambda kv: -kv[1]):
        print(f"{c:5d} x {prog or '?'}")
        print(f"        reads : {list(reads)}")
        print(f"        writes: {list(writes)}\n")
    print("Next: write a rules JSON with one 'w' rule per task (outputs are the best identifier),")
    print("plus 'r' rules only for read-only processes; then rerun with --rules FILE.")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("input_dir"); ap.add_argument("output_dir")
    ap.add_argument("--mode", choices=["task", "instance"], default="task")
    ap.add_argument("--rules", help="JSON list of {op, pattern, task} rules (replaces the built-in 1KG rules)")
    ap.add_argument("--schema", help="dpm-classic/widget workflow schema JSON to derive rules from")
    ap.add_argument("--discover", action="store_true", help="print the read/write signatures found and exit")
    ap.add_argument("--copy", action="store_true", help="copy files instead of symlinking")
    ap.add_argument("--mapping-csv", help="also write a pid -> task table (pid, task, host, program, files read/written)")
    ap.add_argument("--mapping-only", action="store_true", help="write the mapping table only; do not create the layout")
    a = ap.parse_args()

    files = {}  # (pid, op, name) -> path
    for f in os.listdir(a.input_dir):
        m = PAT.match(f)
        if m and nonempty(os.path.join(a.input_dir, f)):
            files[(m["pid"], m["op"], m["name"])] = os.path.join(a.input_dir, f)
    touched = {}
    for (pid, op, name) in files:
        touched.setdefault(pid, {"r": set(), "w": set()})[op].add(name)
    timer = read_timers(a.input_dir)

    if a.discover:
        discover(touched, timer)
        return

    task = classify(touched, load_rules(a), timer)
    counts = dict(collections.Counter(task.values()))
    if a.mapping_csv:
        with open(a.mapping_csv, "w", newline="") as fh:
            w = csv.writer(fh)
            w.writerow(["pid", "task", "host", "program", "timer_file", "n_files_read", "n_files_written", "files_written", "files_read"])
            for pid in sorted(touched, key=lambda p: (task[p], int(p))):
                host, prog, tf = timer.get(pid, ("", "", ""))
                w.writerow([pid, task[pid], host, prog, tf, len(touched[pid]["r"]), len(touched[pid]["w"]),
                            " ".join(sorted(touched[pid]["w"])), " ".join(sorted(touched[pid]["r"]))])
        print("mapping written to", a.mapping_csv)
        if a.mapping_only:
            print("processes per task:", counts)
            return
    if os.path.isdir(a.output_dir):
        sys.exit(f"refusing to overwrite existing {a.output_dir}")
    for (pid, op, name), src in files.items():
        if a.mode == "task":
            d, dst = os.path.join(a.output_dir, task[pid]), f"{name}_{pid}_{op}_stat"
        else:
            d, dst = os.path.join(a.output_dir, f"{task[pid]}_{pid}"), f"{name}_{op}_stat"
        os.makedirs(d, exist_ok=True)
        (shutil.copy2 if a.copy else os.symlink)(os.path.realpath(src), os.path.join(d, dst))
    print("processes per task:", counts, "| histogram files linked:", len(files))
    if "unknown" in counts:
        print(f"note: {counts['unknown']} processes matched no rule and were placed under unknown/ "
              "(run with --discover to see their signatures)")


if __name__ == "__main__":
    main()
