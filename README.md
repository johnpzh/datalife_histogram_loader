# datalife_histogram_loader

Tools for loading DataLife's legacy histogram traces (`*_r_stat` / `*_w_stat`
block histograms) and turning them into per-task I/O summaries. 

Please note that when the environment variable `DATALIFE_JSON_OUTPUT` is NOT set, DataLife will produce the legacy histogram traces, such as

```
/pscratch/sd/j/johnpzh/COLLAB_ROOT/workspace/workspace.58172555.test_loop0_1kg_baseline_2node_6000/ALL.chr1.250000.vcf Block no. Frequency Access size in byte
0 1 4096
1 1 4096
2 2 0
3 1 4096
4 2 4096
5 1 4096
6 2 4096
7 1 4096
8 2 4096
9 1 4096
10 2 4096
...
```

If `export DATALIFE_JSON_OUTPUT=1`, DataLife will produce the trace json files (`*_r_blk_trace.json` and `*_w_blk_trace.json`), such as

```
{
    "access_frequency": 464999,
    "data_volume": 1904627712,
    "file_name": "ALL.chr1.250000.vcf",
    "io_blk_range": [
        0,
        619986,
        -1,
        -2
    ],
    "pid": "502375",
    "task_name": "individuals"
}
```

This tool is used for the legacy histogram traces.


| Script                                     | Purpose                                                                                                                                                                |
| ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `scripts/sort_datalife_stats_by_task.py`   | Label every traced process with a workflow task (the histograms carry no task name) and lay the files out one directory per task, as `datalife/flow-analysis` expects. |
| `scripts/summarize_datalife_histograms.py` | Per-task, per-file and per-process I/O tables plus a stage-level Sankey diagram, computed directly from the histograms.                                                |
| `scripts/datalife_graph_reports.py`        | Run DataLife's own analyzer (`datalife/flow-analysis`) on a layout: stat summary, producer-consumer ranking, critical path, caterpillar tree, Sankey.                  |
| `rules/rules_1kg.json`                     | Task rules for the 1000-genome workflow; the template for other workflows.                                                                                             |




## Repository layout

```
scripts/   sort_datalife_stats_by_task.py, summarize_datalife_histograms.py, datalife_graph_reports.py,
           plus the 1KG profiling scripts (profiled-baseline.v2.json_task_name.sbatch, run_1kg_datalife_json_format.sh)
rules/     rules_1kg.json (task rules; template for other workflows)
requirements.txt
logs/, workdir/   output of the profiled 1KG run (Slurm logs, stage timing CSV)
```



## Requirements

- Python 3.10+; `pip install -r requirements.txt` (pandas, plotly for the
Sankey HTML, networkx<=2.8.8).
- `datalife_graph_reports.py` additionally needs the `datalife` package ([https://github.com/pnnl/datalife](https://github.com/pnnl/datalife)): `pip install -e <datalife checkout>/flow-analysis` (pins `networkx<=2.8.8`,  
so use a dedicated virtual environment).

```bash
cd datalife_histogram_loader
# Create the Python virtual environment
uv venv --python 3.11
# Activate
source .venv/bin/activate
V="$PWD/.venv/bin/python"
S="$PWD/scripts"
# Install requirements
uv pip install -r requirements.txt
# Install DataLife datalife-analyze.py
uv pip install -e <datalife checkout>/flow-analysis
```



## Input

A DataLife output directory containing, per (file, process):

```
<file>_<pid>_r_stat / _w_stat              block histogram: header line, then rows "block frequency access_size"
<file>_<pid>_r_trace_stat / _w_trace_stat  access order (ignored)
monitor_timer.<pid>-<host>.datalife.json   per-process timers: seconds spent inside each intercepted I/O call
                                           (read, write, open, close, ...), call counts and bytes
```

DataLife writes a `_w_stat` for every opened file even when nothing was
written; empty histograms are skipped automatically.

## Usage



### 1. Sort processes into tasks

```bash
$V $S/sort_datalife_stats_by_task.py INPUT_DIR OUTPUT_DIR [options]
```


| Option                  | Meaning                                                                                                                            |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `--discover`            | Print the distinct (program, files read, files written) signatures with process counts and exit. Run this first on a new workflow. |
| `--rules FILE.json`     | Task rules (see below). Default: built-in 1KG rules.                                                                               |
| `--schema FILE.json`    | Derive rules from a dpm-classic/widget workflow schema instead.                                                                    |
| `--mode task` (default) | `OUTPUT_DIR/<task>/<file>_<pid>_{r,w}_stat` -> per-task summary.                                                                   |
| `--mode instance`       | `OUTPUT_DIR/<task>_<pid>/<file>_{r,w}_stat` -> dataflow graph in datalife/flow-analysis (files become shared nodes).               |
| `--mapping-csv FILE`    | Also write the process -> task table (pid, task, host, program, files read/written).                                               |
| `--mapping-only`        | Write only that table, no layout.                                                                                                  |
| `--copy`                | Copy instead of symlink.                                                                                                           |


Layouts are symlinks; the input is never modified. An existing `OUTPUT_DIR`
is not overwritten. Processes matching no rule go to `unknown/`.

#### Rules file

An ordered JSON list; the first rule whose conditions all hold assigns the task.

```json
[
  {"op": "w", "pattern": "chr\\d+n-\\d+-\\d+\\.tar\\.gz", "task": "individuals"},
  {"task": "sifting", "op": "w", "pattern": "sifted\\.SIFT\\.chr\\d+\\.txt"},
  {"task": "sifting", "op": "r", "pattern": ".*annotation\\.vcf", "program": "grep"}
]
```


| Key                             | Meaning                                                                             |
| ------------------------------- | ----------------------------------------------------------------------------------- |
| `op` + `pattern`                | some file the process wrote (`w`) or read (`r`) fully matches the regex (base name) |
| `all_of: [{op, pattern}, ...]`  | every listed condition must hold                                                    |
| `none_of: [{op, pattern}, ...]` | none may hold                                                                       |
| `program`                       | regex on the program name from the timer file (`python3`, `grep`, ...)              |
| `_comment`                      | ignored                                                                             |


Put write rules first: outputs identify a task, inputs are often shared by
several tasks. Add read rules only for read-only helper processes. JSON needs
backslashes doubled. Full example: `rules/rules_1kg.json`.

### 2. Summarize

```bash
$V $S/summarize_datalife_histograms.py INPUT_DIR --output-dir OUT [--rules FILE.json | --schema FILE.json] [options]
```

`INPUT_DIR` is either the flat DataLife directory (give `--rules`/`--schema`
to label tasks; otherwise everything is task `.`) or a per-task layout from
step 1 (add `--timers-dir <flat dir>` to fill host/program).


| Option               | Meaning                                                                                            |
| -------------------- | -------------------------------------------------------------------------------------------------- |
| `--groups FILE.json` | Sankey file groups `[{"pattern": regex, "group": label}]`; default: derived from the rule patterns |
| `--no-sankey`        | skip the HTML                                                                                      |
| `--block-size N`     | default 4096                                                                                       |


Outputs in `OUT/`:


| File                             | Content                                                  |
| -------------------------------- | -------------------------------------------------------- |
| `histogram_per_task.csv`         | one row per task x op                                    |
| `histogram_per_file.csv`         | one row per file x op, with the tasks that touched it    |
| `histogram_per_process_file.csv` | one row per (task, pid, file, op), with host and program |
| `stage_sankey.html`              | tasks x file groups, link width = `bytes_accessed` in GB |


#### Column reference

Every `_r_stat` / `_w_stat` file is one histogram: one process, one file,
one operation. Its rows are `block frequency access_size`: `block` is the
block index (4096-byte blocks by default, `--block-size`), `frequency` is how
many times that block was accessed, and `access_size` is how many bytes of
the block were touched. Rows with `frequency` 0 are ignored.

Metrics computed per histogram (`histogram_per_process_file.csv`):

| Column | How it is computed | Meaning |
| --- | --- | --- |
| `unique_blocks` | number of rows | distinct blocks of the file this process touched |
| `accesses` | sum(`frequency`) | number of block accesses; a block read three times counts three |
| `reread_blocks` | number of rows with `frequency` > 1 | blocks touched more than once |
| `bytes_unique` | sum(`access_size`) | footprint: bytes of the distinct blocks touched, each block counted once (equals the file size for a complete read or write of the file) |
| `bytes_accessed` | sum(`frequency` x `access_size`) | bytes moved through I/O calls, repeated accesses counted every time; always >= `bytes_unique`, and the difference is re-read/re-written data. This is the number DataLife's graph edges and the Sankey links use. (Called `bytes_weighted` in earlier versions.) |
| `extent_bytes` | (max `block` + 1) x block size | file-size proxy from the highest block touched |
| `mean_access_size` | mean(`access_size`) | average bytes touched per block row |

Aggregates:

| File | Grouping | Columns |
| --- | --- | --- |
| `histogram_per_task.csv` | task x op | `processes` = distinct pids, `files` = distinct file names, `stat_files` = number of histograms (pid, file pairs); `bytes_accessed`, `bytes_unique`, `accesses`, `unique_blocks`, `reread_blocks` = sums over those histograms |
| `histogram_per_file.csv` | file x op | `processes` = distinct pids, `tasks` = tasks that touched the file (space-separated); `bytes_accessed`, `bytes_unique` = sums; `extent_bytes` = max |

Example: `individuals_merge,read` has `bytes_unique` 21,143,276 (exactly the
size of the 300 chunk archives it reads, the same number as
`individuals,write`) but `bytes_accessed` 64,260,712 because tar re-reads
each archive about three times.

Units are bytes; divide by 1e9 for GB. The sums are a lower bound of the true
volume (see "Things to keep in mind").

### 3. DataLife's own analyzer (optional)

```bash
$V $S/datalife_graph_reports.py LAYOUT_DIR --output-dir OUT --prefix NAME [--sankey]
```

`LAYOUT_DIR` is the `OUTPUT_DIR` created by step 1: a directory with one
subdirectory per task (`--mode task`) or per process (`--mode instance`).
DataLife's analyzer treats every subdirectory as one task, which is why the
layout is needed; a flat DataLife directory also works but yields a single
task named `.`. Use a `--mode instance` layout for a connected dataflow graph
(with `--mode task` the file nodes keep their pid suffix and stages do not
connect).

Writes `NAME_stat_summary.txt`, `NAME_ranking_table_GB.csv`,
`NAME_stage_edges.csv`, `NAME_critical_path.txt`, `NAME_caterpillar_edges.csv`,
`NAME_graph.pickle` (and `.gpickle`), optionally `NAME_sankey.html`.

## Step-by-step example: 1000-genome

Traces: `/pscratch/sd/j/johnpzh/COLLAB_ROOT/baseline-traces` (two nodes, ten chromosomes). Rules: `rules/rules_1kg.json`.

```bash
cd /pscratch/sd/j/johnpzh/COLLAB_ROOT                        # $V and $S as set in "Requirements"
RULES=$PWD/datalife_histogram_loader/rules/rules_1kg.json
```

**Step 1. See what is in the traces** (no rules needed):

```bash
$V $S/sort_datalife_stats_by_task.py baseline-traces /dev/null --discover
```

```
470 processes, 18 distinct signatures (digits replaced by <N>):
  300 x python3   reads : ['ALL.chr<N>.<N>.vcf']              writes: ['chr<N>n-<N>-<N>.tar.gz']
   10 x python3   reads : ['chr<N>n-<N>-<N>.tar.gz']           writes: ['chr<N>n.tar.gz']
   10 x python3   reads : ['ALL.chr<N>.phase<N>...annotation.vcf', 'SIFT.chr<N>.vcf', 'sifting.py']  writes: ['sifted.SIFT.chr<N>.txt']
   10 x grep      reads : ['ALL.chr<N>.phase<N>...annotation.vcf']  writes: []
   10 x python3   reads : ['chr<N>n.tar.gz', 'sifted.SIFT.chr<N>.txt']  writes: ['chr<N>-AFR.tar.gz']      (x7 populations)
   10 x python3   reads : ['chr<N>n.tar.gz', 'sifted.SIFT.chr<N>.txt']  writes: ['chr<N>-AFR-freq.tar.gz'] (x7 populations)
```

These signatures are what `rules_1kg.json` encodes (population codes collapsed with `[A-Z]{3}`).

**Step 2. Label processes and build the per-task layout:**

```bash
$V $S/sort_datalife_stats_by_task.py baseline-traces baseline-traces-by-task \
    --rules $RULES --mode task \
    --mapping-csv baseline-traces-summary/pid_task_map.csv     # optional, see below
```

```
processes per task: {'individuals': 300, 'individuals_merge': 10, 'sifting': 20, 'mutation_overlap': 70, 'frequency': 70} | histogram files linked: 1380
```

`baseline-traces-by-task/<task>/` now holds the symlinked histograms (this is
the `LAYOUT_DIR` for step 4). If that directory already exists from an
earlier run, remove it first or use another name.

`--mapping-csv` is optional. The sorter **writes** this table; it is not an
input, and no script reads it. It lists every process with its assigned task,
host, program and the files it read/wrote, so use it to check that your rules
labeled the processes correctly. For a new workflow it is produced the same
way, by running the sorter with your own rules file.

**Step 3. Summarize** (straight from the flat directory; the layout is not required):

```bash
$V $S/summarize_datalife_histograms.py baseline-traces --output-dir baseline-traces-summary --rules $RULES
```

```
             task    op  processes  files  stat_files  bytes_accessed  bytes_unique  accesses  unique_blocks  reread_blocks
        frequency  read         70     20         140       195935810     165960172     48531          40621           7091
        frequency write         70     70          70       173210908     173093293     42333          42289             44
      individuals  read        300     10         300    571396915200  380932423680 139501800       93001380       46500420
      individuals write        300    300         300        21143276      21143276      5318           5318              0
individuals_merge  read         10    300         300        64260712      21143276     27324           5318            300
individuals_merge write         10     10          10        15508404      15508404      3791           3791              0
 mutation_overlap  read         70     20         140       195935810     165960172     48531          40621           7091
 mutation_overlap write         70     70          70        20189118      20189118      4963           4963              0
          sifting  read         20     21          40     16542230020   12596208056   4038760        3075296         963428
          sifting write         10     10          10         8224105       8224105      2012           2012              0

totals: read 588395277552 B, write 238275811 B (bytes_accessed)
stage edges (GB):   ALL.chrN.250000.vcf -> individuals 571.397,  ALL.chrN.phase3*annotation.vcf -> sifting 16.465, ...
```

Open `baseline-traces-summary/stage_sankey.html` in a browser for the diagram.

**Step 4 (optional). DataLife's own analyzer:**

```bash
# DataLife's CLI on the per-task layout: 5 tasks, 1380 stat files, bytes = sum(access_size)
"$(dirname "$V")"/datalife-analyze.py -i baseline-traces-by-task
# per-process layout (LAYOUT_DIR for the graph reports), then the reports
$V $S/sort_datalife_stats_by_task.py baseline-traces baseline-traces-by-instance --rules $RULES --mode instance
$V $S/datalife_graph_reports.py baseline-traces-by-instance --output-dir baseline-traces-summary --prefix datalife_instance
```

The critical path by bytes comes out as `ALL.chr9.250000.vcf -> individuals -> chr9n-3001-3201.tar.gz -> individuals_merge -> chr9n.tar.gz -> frequency -> chr9-ALL-freq.tar.gz`.

## Things to keep in mind

- Histogram byte sums are a **lower bound** (roughly 75% of the true volume
for large sequential reads); exact bytes are in the timer JSON. Say
"bytes accessed according to the histograms", not "file size", when quoting them.
- If two tasks read the same file, a read rule cannot separate them; use their
writes, `all_of`/`none_of` on the read set, or `program`. Two read-only
tasks with identical programs and inputs cannot be told apart from traces.
- Re-running the sorter needs a fresh `OUTPUT_DIR`; the summarizer overwrites  
its output files.
- DataLife measures I/O time, not task time: the timer file's `monitor.read/write/open/close`
entries are seconds spent inside those calls; no file records how long a task ran.



## Open Questions:

1. It seems that DataLife profiling histogram data don't have task time.

