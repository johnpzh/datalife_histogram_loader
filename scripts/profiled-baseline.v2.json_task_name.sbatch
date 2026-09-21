#!/bin/bash
#SBATCH --job-name=1kg_datalife_json_format
#SBATCH --account=m5314
#SBATCH --qos=regular
#SBATCH --constraint=cpu
#SBATCH -N 2
#SBATCH --time=03:00:00
#SBATCH --output=/pscratch/sd/j/johnpzh/COLLAB_ROOT/datalife-playground/logs/R.%x.%j.out
#SBATCH --error=/pscratch/sd/j/johnpzh/COLLAB_ROOT/datalife-playground/logs/R.%x.%j.err
#SBATCH --chdir=/pscratch/sd/j/johnpzh/COLLAB_ROOT/datalife-playground/workdir
#SBATCH --exclusive
#SBATCH --export=ALL
#SBATCH --mail-type=ALL
#SBATCH --mail-user=zhen.peng@pnnl.gov

# --- Paths you already had ---
set -eo pipefail
awo_clear_inherited_datalife() {
  local library
  local retained=()
  local inherited=()
  IFS=': ' read -ra inherited <<< "${LD_PRELOAD:-}"
  for library in "${inherited[@]}"; do
    case "${library##*/}" in
      libmonitor*.so*) ;;
      *) [ -z "$library" ] || retained+=("$library") ;;
    esac
  done
  if [ "${#retained[@]}" -gt 0 ]; then
    export LD_PRELOAD="$(IFS=:; echo "${retained[*]}")"
  else
    unset LD_PRELOAD
  fi
}
awo_clear_inherited_datalife

SCRIPT_DIR="/pscratch/sd/j/johnpzh/COLLAB_ROOT/portus-orchestrator/inputs/portable_1kg/bin"
NFS_ORIGIN_1KGENOME_DIR="/pscratch/sd/j/johnpzh/Data/1kgenome/1kgenome_dataset"
BEEGFS_ORIGIN_1KGENOME_DIR="/pscratch/sd/j/johnpzh/Data/1kgenome/1kgenome_dataset"
BEEGFS_WORKSPACE_ROOT="/pscratch/sd/j/johnpzh/COLLAB_ROOT/workspace"
LINUX_RESOURCE_DETECT="/pscratch/sd/j/johnpzh/COLLAB_ROOT/portus-orchestrator/inputs/portable_1kg/helpers/resource_detect.sh"
PREPARE_DATA_SH="/pscratch/sd/j/johnpzh/COLLAB_ROOT/portus-orchestrator/inputs/portable_1kg/helpers/prepare_data.sh"
SIZE_37G_IN_BYTES=38089130668
SIZE_37G_IN_KB=37346388
PREV_PWD=$(readlink -f .)
DATASET_DIR_NAME="workspace.${SLURM_JOBID}.${SLURM_JOB_NAME}"
export WF_FINAL_OUTPUT_CONTRACT='{"required_patterns": ["chr1-SAS.tar.gz", "chr1-SAS-freq.tar.gz", "chr1-EAS.tar.gz", "chr1-EAS-freq.tar.gz", "chr1-GBR.tar.gz", "chr1-GBR-freq.tar.gz", "chr1-AMR.tar.gz", "chr1-AMR-freq.tar.gz", "chr1-AFR.tar.gz", "chr1-AFR-freq.tar.gz", "chr1-EUR.tar.gz", "chr1-EUR-freq.tar.gz", "chr1-ALL.tar.gz", "chr1-ALL-freq.tar.gz", "chr2-SAS.tar.gz", "chr2-SAS-freq.tar.gz", "chr2-EAS.tar.gz", "chr2-EAS-freq.tar.gz", "chr2-GBR.tar.gz", "chr2-GBR-freq.tar.gz", "chr2-AMR.tar.gz", "chr2-AMR-freq.tar.gz", "chr2-AFR.tar.gz", "chr2-AFR-freq.tar.gz", "chr2-EUR.tar.gz", "chr2-EUR-freq.tar.gz", "chr2-ALL.tar.gz", "chr2-ALL-freq.tar.gz", "chr3-SAS.tar.gz", "chr3-SAS-freq.tar.gz", "chr3-EAS.tar.gz", "chr3-EAS-freq.tar.gz", "chr3-GBR.tar.gz", "chr3-GBR-freq.tar.gz", "chr3-AMR.tar.gz", "chr3-AMR-freq.tar.gz", "chr3-AFR.tar.gz", "chr3-AFR-freq.tar.gz", "chr3-EUR.tar.gz", "chr3-EUR-freq.tar.gz", "chr3-ALL.tar.gz", "chr3-ALL-freq.tar.gz", "chr4-SAS.tar.gz", "chr4-SAS-freq.tar.gz", "chr4-EAS.tar.gz", "chr4-EAS-freq.tar.gz", "chr4-GBR.tar.gz", "chr4-GBR-freq.tar.gz", "chr4-AMR.tar.gz", "chr4-AMR-freq.tar.gz", "chr4-AFR.tar.gz", "chr4-AFR-freq.tar.gz", "chr4-EUR.tar.gz", "chr4-EUR-freq.tar.gz", "chr4-ALL.tar.gz", "chr4-ALL-freq.tar.gz", "chr5-SAS.tar.gz", "chr5-SAS-freq.tar.gz", "chr5-EAS.tar.gz", "chr5-EAS-freq.tar.gz", "chr5-GBR.tar.gz", "chr5-GBR-freq.tar.gz", "chr5-AMR.tar.gz", "chr5-AMR-freq.tar.gz", "chr5-AFR.tar.gz", "chr5-AFR-freq.tar.gz", "chr5-EUR.tar.gz", "chr5-EUR-freq.tar.gz", "chr5-ALL.tar.gz", "chr5-ALL-freq.tar.gz", "chr6-SAS.tar.gz", "chr6-SAS-freq.tar.gz", "chr6-EAS.tar.gz", "chr6-EAS-freq.tar.gz", "chr6-GBR.tar.gz", "chr6-GBR-freq.tar.gz", "chr6-AMR.tar.gz", "chr6-AMR-freq.tar.gz", "chr6-AFR.tar.gz", "chr6-AFR-freq.tar.gz", "chr6-EUR.tar.gz", "chr6-EUR-freq.tar.gz", "chr6-ALL.tar.gz", "chr6-ALL-freq.tar.gz", "chr7-SAS.tar.gz", "chr7-SAS-freq.tar.gz", "chr7-EAS.tar.gz", "chr7-EAS-freq.tar.gz", "chr7-GBR.tar.gz", "chr7-GBR-freq.tar.gz", "chr7-AMR.tar.gz", "chr7-AMR-freq.tar.gz", "chr7-AFR.tar.gz", "chr7-AFR-freq.tar.gz", "chr7-EUR.tar.gz", "chr7-EUR-freq.tar.gz", "chr7-ALL.tar.gz", "chr7-ALL-freq.tar.gz", "chr8-SAS.tar.gz", "chr8-SAS-freq.tar.gz", "chr8-EAS.tar.gz", "chr8-EAS-freq.tar.gz", "chr8-GBR.tar.gz", "chr8-GBR-freq.tar.gz", "chr8-AMR.tar.gz", "chr8-AMR-freq.tar.gz", "chr8-AFR.tar.gz", "chr8-AFR-freq.tar.gz", "chr8-EUR.tar.gz", "chr8-EUR-freq.tar.gz", "chr8-ALL.tar.gz", "chr8-ALL-freq.tar.gz", "chr9-SAS.tar.gz", "chr9-SAS-freq.tar.gz", "chr9-EAS.tar.gz", "chr9-EAS-freq.tar.gz", "chr9-GBR.tar.gz", "chr9-GBR-freq.tar.gz", "chr9-AMR.tar.gz", "chr9-AMR-freq.tar.gz", "chr9-AFR.tar.gz", "chr9-AFR-freq.tar.gz", "chr9-EUR.tar.gz", "chr9-EUR-freq.tar.gz", "chr9-ALL.tar.gz", "chr9-ALL-freq.tar.gz", "chr10-SAS.tar.gz", "chr10-SAS-freq.tar.gz", "chr10-EAS.tar.gz", "chr10-EAS-freq.tar.gz", "chr10-GBR.tar.gz", "chr10-GBR-freq.tar.gz", "chr10-AMR.tar.gz", "chr10-AMR-freq.tar.gz", "chr10-AFR.tar.gz", "chr10-AFR-freq.tar.gz", "chr10-EUR.tar.gz", "chr10-EUR-freq.tar.gz", "chr10-ALL.tar.gz", "chr10-ALL-freq.tar.gz"], "output_root": "${CURRENT_DIR}"}'

# The collaborator declares this directory to be shared across the allocation.
mkdir -p "${BEEGFS_WORKSPACE_ROOT}"

# --- DATALIFE monitor config ---
MONITOR_LIB="/pscratch/sd/j/johnpzh/COLLAB_ROOT/datalife-install/lib/libmonitor.so"
export DATALIFE_OUTPUT_PATH="${DATALIFE_OUTPUT_PATH:-/pscratch/sd/j/johnpzh/COLLAB_ROOT/baseline-traces-v2-json}"
export DATALIFE_FILE_PATTERNS="*.gz, *.tar.gz, *.vcf, sift*"
export DATALIFE_JSON_OUTPUT="${DATALIFE_JSON_OUTPUT:-1}"  # enable json output !!!
if [ -n "$MONITOR_LIB" ] && [ -r "$MONITOR_LIB" ]; then
  mkdir -p "$DATALIFE_OUTPUT_PATH"
  rm -rf "$DATALIFE_OUTPUT_PATH"/*
else
  echo ">>> DataLife monitor not configured; running uninstrumented." >&2
fi

# --- Toolchains and prepared Python environment ---
# no environment modules configured for this platform

ENV_DIR="/pscratch/sd/j/johnpzh/COLLAB_ROOT/portus-orchestrator/.venv"
if [ ! -x "$ENV_DIR/bin/python" ] || [ ! -x "$ENV_DIR/bin/python3" ]; then
  echo "Prepared Python interpreter missing: $ENV_DIR/bin/python or python3; run doctor before submission." >&2
  exit 2
fi
# Both conda and uv/venv expose bin/python. Do not install into this directory.
export PATH="$ENV_DIR/bin:$PATH"
export PYTHONNOUSERSITE=1
export PYTHONDONTWRITEBYTECODE=1
unset PYTHONHOME PYTHONPATH
export LIBSTDCPP14="/usr/lib64/gcc/x86_64-suse-linux/14/../../../../lib64/libstdc++.so.6"
export LD_LIBRARY_PATH="/usr/lib64/gcc/x86_64-suse-linux/14/../../../../lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
"$ENV_DIR/bin/python3" "/pscratch/sd/j/johnpzh/COLLAB_ROOT/portus-orchestrator/inputs/portable_1kg/helpers/validate_python_env.py" || exit 2

# Build the LD_PRELOAD chain from whichever components are configured and
# readable. With no monitor library the workflow runs uninstrumented; task
# arguments and scientific programs are identical either way.
WF_PRELOAD_PARTS=()
if [ -n "${LIBSTDCPP14:-}" ] && [ -r "${LIBSTDCPP14}" ]; then
  WF_PRELOAD_PARTS+=("$LIBSTDCPP14")
fi
if [ -n "${MONITOR_LIB:-}" ] && [ -r "${MONITOR_LIB}" ]; then
  WF_PRELOAD_PARTS+=("$MONITOR_LIB")
fi
if [ "${#WF_PRELOAD_PARTS[@]}" -gt 0 ]; then
  WF_SRUN_EXPORT="ALL,LD_PRELOAD=$(IFS=:; echo "${WF_PRELOAD_PARTS[*]}")"
else
  WF_SRUN_EXPORT="ALL"
fi
export WF_SRUN_EXPORT

# Which libstdc++ will Python actually use?
python - <<'PY'
import ctypes, ctypes.util
lib = ctypes.util.find_library("stdc++")
print("find_library stdc++ =>", lib)
try:
    h = ctypes.CDLL("libstdc++.so.6")
    print("Loaded:", h._name)
except OSError as e:
    print("Failed to load libstdc++:", e)
PY

# Report the interpreter used by the workflow.

echo ">>> DEBUG: PATH=$PATH"
echo ">>> DEBUG: which python → $(which python) ($(python --version 2>&1))"
echo ">>> DEBUG: which python3 → $(which python3) ($(python3 --version))"

##############
# Preparation
##############

CHROMOSOMES=10
NUM_NODES=$SLURM_JOB_NUM_NODES

ITERATION=$(( $CHROMOSOMES / $NUM_NODES -1 ))

# if ITERATION is 0, set to 1
if [ "$ITERATION" -lt "0" ]
then
    echo "ITERATION is 0, set to 1"
    ITERATION=1
fi

PROBLEM_SIZE=300 # the maximum number of tasks within a stage !!!need to modify as needed!!!
# the `SBATCH -N -n` needs to modify as well !!!

# NUM_TASKS_PER_NODE=$((($SLURM_NTASKS/$SLURM_JOB_NUM_NODES))
# NUM_TASKS_PER_NODE=$(((PROBLEM_SIZE+NUM_TASKS_PER_NODE)/NUM_NODES)) # (fixed) This is the max number of cores per node
#NUM_NODES=$(((PROBLEM_SIZE+NUM_TASKS_PER_NODE-1)/NUM_TASKS_PER_NODE))
# echo "PROBLEM SIZE: $PROBLEM_SIZE SLURM_NTASKS_PER_NODE: $SLURM_NTASKS_PER_NODE NUM_NODES: $NUM_NODES"
echo "PROBLEM_SIZE: $PROBLEM_SIZE NUM_NODES: $NUM_NODES"

NODE_NAMES=`echo $SLURM_JOB_NODELIST | scontrol show hostnames`
list=()
while read -ra tmp; do
    list+=("${tmp[@]}")
done <<< "$NODE_NAMES"

BASELINE_TASK_PIDS=()

host_list=$(echo "$NODE_NAMES" | tr '\n' ',')
echo "host_list: $host_list"
# readarray -t host_list <<< "$NODE_NAMES"

# set -x

#########
# Tasks
#########

function START_INDIVIDUALS() {
    # set -x

    counter=0
    t_count=1

    for i in $(seq 0 9)
    do
        for j in $(seq 0 29)
	    do
	    # echo "$i $j"
            if [ "$counter" -lt "$PROBLEM_SIZE" ]
            then
                node_idx=$(($i % $NUM_NODES))
                running_node=${list[$node_idx]}
                # echo "running node: $running_node t$i"
                let ii=i+1
                # No need to change. This is the smallest input allowed.
                set -x
                srun --export="$WF_SRUN_EXPORT,DATALIFE_TASK_NAME=individuals" -w $running_node -n1 -N1 --exclusive $SCRIPT_DIR/individuals.py $CURRENT_DIR/ALL.chr${ii}.250000.vcf $ii $((1+j*200)) $((201+j*200)) 6000 &
                BASELINE_TASK_PIDS+=("$!")
                set +x
                counter=$(($counter + 1))
                # echo "counter: $counter"
            fi
	    done
    done
    # sleep 3

}

START_INDIVIDUALS_MERGE() {
    for i in $(seq 0 9)
    do
        node_idx=$(($i % $NUM_NODES))
        running_node=${list[$node_idx]}
        let ii=i+1
        # 10 merge tasks in total
        set -x
        srun --export="$WF_SRUN_EXPORT,DATALIFE_TASK_NAME=individuals_merge" -w $running_node -n1 -N1 --exclusive $SCRIPT_DIR/individuals_merge.py $ii $CURRENT_DIR/chr${ii}n-1-201.tar.gz $CURRENT_DIR/chr${ii}n-201-401.tar.gz $CURRENT_DIR/chr${ii}n-401-601.tar.gz $CURRENT_DIR/chr${ii}n-601-801.tar.gz $CURRENT_DIR/chr${ii}n-801-1001.tar.gz $CURRENT_DIR/chr${ii}n-1001-1201.tar.gz $CURRENT_DIR/chr${ii}n-1201-1401.tar.gz $CURRENT_DIR/chr${ii}n-1401-1601.tar.gz $CURRENT_DIR/chr${ii}n-1601-1801.tar.gz $CURRENT_DIR/chr${ii}n-1801-2001.tar.gz $CURRENT_DIR/chr${ii}n-2001-2201.tar.gz $CURRENT_DIR/chr${ii}n-2201-2401.tar.gz $CURRENT_DIR/chr${ii}n-2401-2601.tar.gz $CURRENT_DIR/chr${ii}n-2601-2801.tar.gz $CURRENT_DIR/chr${ii}n-2801-3001.tar.gz $CURRENT_DIR/chr${ii}n-3001-3201.tar.gz $CURRENT_DIR/chr${ii}n-3201-3401.tar.gz $CURRENT_DIR/chr${ii}n-3401-3601.tar.gz $CURRENT_DIR/chr${ii}n-3601-3801.tar.gz $CURRENT_DIR/chr${ii}n-3801-4001.tar.gz $CURRENT_DIR/chr${ii}n-4001-4201.tar.gz $CURRENT_DIR/chr${ii}n-4201-4401.tar.gz $CURRENT_DIR/chr${ii}n-4401-4601.tar.gz $CURRENT_DIR/chr${ii}n-4601-4801.tar.gz $CURRENT_DIR/chr${ii}n-4801-5001.tar.gz $CURRENT_DIR/chr${ii}n-5001-5201.tar.gz $CURRENT_DIR/chr${ii}n-5201-5401.tar.gz $CURRENT_DIR/chr${ii}n-5401-5601.tar.gz $CURRENT_DIR/chr${ii}n-5601-5801.tar.gz $CURRENT_DIR/chr${ii}n-5801-6001.tar.gz &
                BASELINE_TASK_PIDS+=("$!")
        set +x
    done
}

START_SIFTING() {
    for i in $(seq 0 9)
    do
        node_idx=$(($i % $NUM_NODES))
        running_node=${list[$node_idx]}
        # 10 sifting tasks in total
        let ii=i+1
        set -x
        srun --export="$WF_SRUN_EXPORT,DATALIFE_TASK_NAME=sifting" -w $running_node -n1 -N1 --exclusive $SCRIPT_DIR/sifting.py $CURRENT_DIR/ALL.chr${ii}.phase3_shapeit2_mvncall_integrated_v5.20130502.sites.annotation.vcf $ii &
                BASELINE_TASK_PIDS+=("$!")
        set +x
    done
}

START_MUTATION_OVERLAP() {
    FNAMES=("SAS EAS GBR AMR AFR EUR ALL")
    for i in $(seq 0 9)
    do
        node_idx=$(($i % $NUM_NODES))
        running_node=${list[$node_idx]}
        for j in $FNAMES
        do
            let ii=i+1
            set -x
            srun --export="$WF_SRUN_EXPORT,DATALIFE_TASK_NAME=mutation_overlap" -w $running_node -n1 -N1 --exclusive $SCRIPT_DIR/mutation_overlap.py -c $ii -pop $j &
                BASELINE_TASK_PIDS+=("$!")
            set +x
        done
    done
}

START_FREQUENCY() {
    FNAMES=("SAS EAS GBR AMR AFR EUR ALL")
    for i in $(seq 0 9)
    do
        node_idx=$(($i % $NUM_NODES))
        running_node=${list[$node_idx]}
        for j in $FNAMES
        do
            let ii=i+1
            set -x
            srun --export="$WF_SRUN_EXPORT,DATALIFE_TASK_NAME=frequency" -w $running_node -n1 -N1 --exclusive $SCRIPT_DIR/frequency.py -c $ii -pop $j &
                BASELINE_TASK_PIDS+=("$!")
            set +x
        done
    done
}


############
# Utilities
############



function GET_STORAGE_OPTIONS() {
    # workspace_root is explicitly declared shared storage by the collaborator.
    # Filesystem names describe provenance, not eligibility or staging semantics.
    if [ ! -d "${BEEGFS_WORKSPACE_ROOT}" ] || [ ! -w "${BEEGFS_WORKSPACE_ROOT}" ]; then
        echo "Shared workspace is not writable: ${BEEGFS_WORKSPACE_ROOT}" >&2
        return 2
    fi
    local available_kb
    available_kb=$(df -Pk "${BEEGFS_WORKSPACE_ROOT}" | awk 'NR==2 {print $4}')
    if ! [[ "${available_kb}" =~ ^[0-9]+$ ]] || [ "${available_kb}" -le "${SIZE_37G_IN_KB}" ]; then
        echo "Insufficient free space in shared workspace: ${BEEGFS_WORKSPACE_ROOT}" >&2
        return 2
    fi
    local filesystem_type
    filesystem_type=$(df -PT "${BEEGFS_WORKSPACE_ROOT}" | awk 'NR==2 {print $2}')
    STORAGE_OPTIONS="${BEEGFS_WORKSPACE_ROOT},${filesystem_type:-unknown}"
}

wait_for_baseline_tasks() {
    local pid
    local failed=0
    for pid in "${BASELINE_TASK_PIDS[@]}"; do
        if ! wait "$pid"; then failed=1; fi
    done
    BASELINE_TASK_PIDS=()
    if [ "$failed" -ne 0 ]; then
        echo "One or more baseline tasks failed; results retained for diagnosis." >&2
        return 1
    fi
}

prepare_node_runtime_caches() {
  WF_NODE_RUNTIME_ROOT="/tmp/awo-runtime-${UID}/${SLURM_JOB_ID:-${SLURM_JOBID:-manual-$$}}"
  export WF_NODE_RUNTIME_ROOT
  export MPLBACKEND=Agg
  export MPLCONFIGDIR="${WF_NODE_RUNTIME_ROOT}/mplconfig"
  export XDG_CACHE_HOME="${WF_NODE_RUNTIME_ROOT}/xdg-cache"
  local node
  local pid
  local failed=0
  local pids=()
  for node in "${list[@]}"; do
    srun --chdir=/tmp --export=ALL -w "$node" -n1 -N1 --cpus-per-task=1 --exclusive bash -c '
      set -e
      mkdir -p "$MPLCONFIGDIR" "$XDG_CACHE_HOME"
      python3 -c "import importlib.util; importlib.import_module(\"matplotlib.font_manager\") if importlib.util.find_spec(\"matplotlib\") else None"
    ' &
    pids+=("$!")
  done
  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then failed=1; fi
  done
  return "$failed"
}



function CLEANUP() {

    start_time=$(date +%s.%N)

    # rm -rf chr*-freq* 
    # rm -rf chr*.tar.gz
    # find . -depth -type d -name "output_no_sift" -exec rm -rf {} \;
    # find . -depth -type d -name "plots_no_sift" -exec rm -rf {} \;

    # CURRENT_DIR contains either copied local data or created symlinks.
    cd "${PREV_PWD}"
    set -x
    rm -rf "${CURRENT_DIR}"
    set +x

    end_time=$(date +%s.%N)
    exe_time=$(echo "${end_time} - ${start_time}" | bc -l)
    echo
    echo "Removed results. (${exe_time} secs)"
    echo
}

################
# Main workflow
################

hostname;date;

# echo "Making directory at $CURRENT_DIR ..."
# srun -n$NUM_NODES -w $host_list --exclusive mkdir -p $CURRENT_DIR

prepare_data_time_list=()
individuals_time_list=()
merge_sifting_time_list=()
mutation_frequency_time_list=()
workflow_time_list=()
total_time_list=()
col_header="Tasks"

## Get Storage options
GET_STORAGE_OPTIONS
echo 
echo "STORAGE_OPTIONS:"
echo "${STORAGE_OPTIONS}"
echo 

prepare_node_runtime_caches

TT_TIME_START=$(date +%s.%N)

for option in "${STORAGE_OPTIONS}"; do
    IFS="," read -ra tmp_opt <<< "${option}"
    root_path=${tmp_opt[0]}
    root_type=${tmp_opt[1]}

    total_time_start=$SECONDS
    # Prepare the data
    
    CURRENT_DIR="${root_path}/${DATASET_DIR_NAME}"

    ORIGIN_1KGENOME_DIR="${BEEGFS_ORIGIN_1KGENOME_DIR}"
    export CURRENT_DIR root_type SIZE_37G_IN_BYTES ORIGIN_1KGENOME_DIR
    export WF_STORAGE_SHARED=1
    start_time=$SECONDS
    bash "${PREPARE_DATA_SH}"
    duration=$(($SECONDS - $start_time))
    echo "prepare_data : $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed ($duration secs)."
    prepare_data_time_list+=(${duration})

    col_header+=",${root_type}(${root_path})"


    workflow_start_time=$SECONDS

    #
    # Run the workflow
    #
    cd "${CURRENT_DIR}"

    # start_time=$SECONDS
    # STAGE_IN_INDIVIDUALS
    # wait
    # duration=$(($SECONDS - $start_time))
    # echo "data stage-in for individuals : $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed ($duration secs)."


    # Stage 1 : Individuals
    echo
    echo "Start individuals CHROMOSOME on ${CURRENT_DIR}"
    echo
    start_time=$SECONDS
    START_INDIVIDUALS
    wait_for_baseline_tasks
    duration=$(($SECONDS - $start_time))
    echo "individuals : $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed ($duration secs)."
    individuals_time_list+=(${duration})

    # Stage 2 : Individuals merge + Sifting
    start_time=$SECONDS
    echo
    echo "Start individuals_merge and sifting on ${CURRENT_DIR}"
    echo 
    START_INDIVIDUALS_MERGE
    START_SIFTING
    wait_for_baseline_tasks
    duration=$(($SECONDS - $start_time))
    echo "individuals_merge+sifting : $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed ($duration secs)."
    merge_sifting_time_list+=(${duration})


    # Stage 3 : Mutation overlap + Frequency
    start_time=$SECONDS
    echo
    echo "Start mutation_overlap and frequency on ${CURRENT_DIR}"
    echo
    START_MUTATION_OVERLAP
    START_FREQUENCY
    wait_for_baseline_tasks
    duration=$(($SECONDS - $start_time))
    echo "mutation_overlap+frequency : $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed ($duration secs)."
    mutation_frequency_time_list+=(${duration})


    duration=$(($SECONDS - $workflow_start_time))
    echo "All_tasks_done : $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed ($duration secs)."
    workflow_time_list+=(${duration})

    # set -x
    # check output
    # echo "Checking all output ----------------"
    # srun -n$NUM_NODES -w $host_list --exclusive du -h $CURRENT_DIR

    duration=$(($SECONDS - $total_time_start))
    echo "All_tasks+Prepare_data : $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed ($duration secs)."
    total_time_list+=(${duration})

    echo "Results retained in ${CURRENT_DIR}"
done

##############################
# DATALIFE log collection
##############################
hostname; date;
sacct -j "$SLURM_JOB_ID" --format=JobID,JobName%30,Partition,Account,State,Elapsed,ExitCode,AllocCPUS,AllocNodes

# # Collect DATALIFE and blk_trace outputs
TEST_LOG_FOLDER="$DATALIFE_OUTPUT_PATH"
mkdir -p "$TEST_LOG_FOLDER"

mv "$CURRENT_DIR"/*datalife.json "$TEST_LOG_FOLDER" 2>/dev/null || true
mv "$CURRENT_DIR"/*blk_trace.json "$TEST_LOG_FOLDER" 2>/dev/null || true

# Change back PWD
cd "${PREV_PWD}"

###########################
# Save performance numbers
###########################

# Save the times
collect_file="${PREV_PWD}/R.${SLURM_JOB_NAME}.${SLURM_JOBID}.all_times.csv"
:> ${collect_file}
echo "${col_header}" >> ${collect_file}

echo -n "individuals(s)" >> ${collect_file}
for time in "${individuals_time_list[@]}"; do
    echo -n ",${time}" >> ${collect_file}
done
echo >> ${collect_file}

echo -n "individuals_merge+sifting(s)" >> ${collect_file}
for time in "${merge_sifting_time_list[@]}"; do
    echo -n ",${time}" >> ${collect_file}
done
echo >> ${collect_file}

echo -n "mutation_overlap+frequency(s)" >> ${collect_file}
for time in "${mutation_frequency_time_list[@]}"; do
    echo -n ",${time}" >> ${collect_file}
done
echo >> ${collect_file}

echo -n "all_tasks(s)" >> ${collect_file}
for time in "${workflow_time_list[@]}"; do
    echo -n ",${time}" >> ${collect_file}
done
echo >> ${collect_file}

echo -n "prepare_data(s)" >> ${collect_file}
for time in "${prepare_data_time_list[@]}"; do
    echo -n ",${time}" >> ${collect_file}
done
echo >> ${collect_file}

echo -n "all_tasks+prep_data(s)" >> ${collect_file}
for time in "${total_time_list[@]}"; do
    echo -n ",${time}" >> ${collect_file}
done
echo >> ${collect_file}

echo 
echo "Saved to ${collect_file}"
echo 

TT_TIME_END=$(date +%s.%N)
TT_TIME_EXE=$(echo "${TT_TIME_END} - ${TT_TIME_START}" | bc -l)
echo
echo "TT_TIME_EXE(s): ${TT_TIME_EXE}"
echo

# # Also copy Slurm stdout/err
# mv "$PREV_PWD"/R.*"$SLURM_JOB_NAME"*"$SLURM_JOB_ID".err "$TEST_LOG_FOLDER" 2>/dev/null || true
# mv "$PREV_PWD"/R.*"$SLURM_JOB_NAME"*"$SLURM_JOB_ID".out "$TEST_LOG_FOLDER" 2>/dev/null || true
