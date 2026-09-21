set -eu

export BASELINE_RESOURCE_ARGS=(--cpus-per-task=4)
export PROFILE_SCRIPT="/pscratch/sd/j/johnpzh/COLLAB_ROOT/datalife-playground/scripts/profiled-baseline.v2.json_task_name.sbatch"
export DATALIFE_OUTPUT_PATH="/pscratch/sd/j/johnpzh/COLLAB_ROOT/baseline-traces-v2-json"
export DATALIFE_FILE_PATTERNS='*.gz, *.tar.gz, *.vcf, sift*'
# export DATALIFE_JSON_OUTPUT=1  # enable json output !!! for profiling, comment this out.
export WF_ENABLE_DATALIFE_MONITORING=1
unset WF_DATALIFE_PROFILE_WAVES WF_DATALIFE_PROFILE_LAUNCHES

sbatch --test-only "${BASELINE_RESOURCE_ARGS[@]}" "$PROFILE_SCRIPT"
set -x
sbatch "${BASELINE_RESOURCE_ARGS[@]}" "$PROFILE_SCRIPT"
set +x  