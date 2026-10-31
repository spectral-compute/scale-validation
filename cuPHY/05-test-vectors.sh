#!/usr/bin/env bash
# shellcheck disable=2317,2329
. "$(dirname "$0")"/../util/prelude.sh
source "$SCALE_VALIDATION/util/checks.sh"

# cuPHY's channel pipelines on the test vectors from 03-gen-vectors.sh, with the commands and pass
# criteria of upstream's cuPHY/test/cuphy_unit_test.sh (minus compute-sanitizer). The compact vector set
# has a few thousand vectors, so each pipeline runs on every CUPHY_TV_STRIDE-th of its vectors (all of
# them with CUPHY_TV_STRIDE=1).
STRIDE="${CUPHY_TV_STRIDE:-10}"
EX="$(realpath build/examples)"
TV="$(realpath tv)"
LOGS="$(realpath .)/tv-logs"
mkdir -p "${LOGS}"

# Every STRIDE-th vector whose name matches one of the patterns.
vectors() {
    local args=()
    for p in "$@"; do
        args+=(-o -name "${p}")
    done
    find -L "${TV}" -maxdepth 1 \( "${args[@]:1}" \) | sort | awk -v s="${STRIDE}" 'NR % s == 1 || s == 1'
}

# run <log> <command...>: run a pipeline, failing on a non-zero exit status or a reported mismatch.
run() {
    local log="$1"
    shift
    timeout 300 "$@" >"${log}" 2>&1 || {
        tail -20 "${log}"
        return 1
    }
    # PUSCH: mismatched code blocks/CRCs, or failed component checks.
    if grep -qE '(Mismatched|MismatchedCRC) (CBs|TBs) +[1-9]|(ChEst|ChEqCoef|SoftDemapper).*FAILED|ERR.*mismatch' "${log}"; then
        grep -E 'Mismatched|FAILED|mismatch' "${log}" | head -5
        return 1
    fi
    # PUCCH and the simplex decoder report "found <n>" mismatches.
    if grep -qP 'found\s*[1-9]' "${log}"; then
        grep -P 'found\s*[1-9]' "${log}" | head -5
        return 1
    fi
}

# pipeline <name> <command, with TV for the vector> -- <name patterns...>
pipeline() {
    local name="$1"
    shift
    local cmd=()
    while [[ "$1" != "--" ]]; do
        cmd+=("$1")
        shift
    done
    shift
    local tv
    for tv in $(vectors "$@"); do
        local b
        b="$(basename "${tv}" .h5)"
        check "${name} ${b}" run "${LOGS}/${name// /_}-${b}.log" "${cmd[@]/TV/${tv}}"
    done
}

PUSCH_TVS=('TVnr_*PUSCH_gNB_CUPHY*.h5')
PDSCH_TVS=('*PDSCH_gNB_CUPHY*.h5')

pipeline "SSB streams" "${EX}/ss/testSS" -i TV -- '*SSB_gNB_CUPHY*.h5'
pipeline "SSB graphs" "${EX}/ss/testSS" -i TV -m 1 -- '*SSB_gNB_CUPHY*.h5'
pipeline "PDCCH streams" "${EX}/pdcch/embed_pdcch_tf_signal" -i TV -- '*PDCCH_gNB_CUPHY*.h5'
pipeline "PDCCH graphs" "${EX}/pdcch/embed_pdcch_tf_signal" -i TV -m 1 -- '*PDCCH_gNB_CUPHY*.h5'
pipeline "PDSCH streams" "${EX}/pdsch_tx/cuphy_ex_pdsch_tx" TV 2 0 0 8 -- "${PDSCH_TVS[@]}"
# cuphy_ex_pdsch_tx only reads the graphs flag when it is the last argument, so this omits the TB
# alignment that upstream passes (which silently runs streams).
pipeline "PDSCH graphs" "${EX}/pdsch_tx/cuphy_ex_pdsch_tx" TV 2 0 1 -- "${PDSCH_TVS[@]}"
pipeline "CSI-RS streams" "${EX}/csi_rs/nzp_csi_rs_test" -i TV -- '*CSIRS_gNB_CUPHY*.h5'
pipeline "CSI-RS graphs" "${EX}/csi_rs/nzp_csi_rs_test" -i TV -m 1 -- '*CSIRS_gNB_CUPHY*.h5'
pipeline "PRACH streams" "${EX}/prach_receiver_multi_cell/prach_receiver_multi_cell" -i TV -r 1 -k -- '*PRACH_gNB_CUPHY*.h5'
pipeline "PRACH graphs" "${EX}/prach_receiver_multi_cell/prach_receiver_multi_cell" -i TV -r 1 -k -m 1 -- '*PRACH_gNB_CUPHY*.h5'
pipeline "PUCCH streams" "${EX}/pucch_rx_pipeline/cuphy_ex_pucch_rx_pipeline" -i TV -- 'TVnr_*PUCCH_F?_gNB_CUPHY_s*.h5'
pipeline "PUCCH graphs" "${EX}/pucch_rx_pipeline/cuphy_ex_pucch_rx_pipeline" -i TV -m 1 -- 'TVnr_*PUCCH_F?_gNB_CUPHY_s*.h5'
pipeline "ChEst" "${EX}/ch_est/cuphy_ex_ch_est" -i TV -- 'TVnr_*PUSCH_gNB_CUPHY*s0p*.h5'
pipeline "ChEq" "${EX}/channel_eq/cuphy_ex_channel_eq" -i TV -- 'TVnr_*PUSCH_gNB_CUPHY*s0p*.h5'
pipeline "PUSCH streams" "${EX}/pusch_rx_multi_pipe/cuphy_ex_pusch_rx_multi_pipe" -i TV -r 1 -m 0 -- "${PUSCH_TVS[@]}"
pipeline "PUSCH streams sub-slot" "${EX}/pusch_rx_multi_pipe/cuphy_ex_pusch_rx_multi_pipe" -i TV -r 1 -m 2 -- "${PUSCH_TVS[@]}"
pipeline "PUSCH graphs" "${EX}/pusch_rx_multi_pipe/cuphy_ex_pusch_rx_multi_pipe" -i TV -r 1 -m 1 -- "${PUSCH_TVS[@]}"
pipeline "SRS streams" "${EX}/srs_rx_pipeline/cuphy_ex_srs_rx_pipeline" -i TV -r 1 -- 'TVnr_*_SRS_gNB_CUPHY_*.h5'
pipeline "SRS graphs" "${EX}/srs_rx_pipeline/cuphy_ex_srs_rx_pipeline" -i TV -r 1 -m 1 -- 'TVnr_*_SRS_gNB_CUPHY_*.h5'
pipeline "BFW streams" "${EX}/bfc/cuphy_ex_bfc" -i TV -r 1 -m 0 -c -- 'TVnr_*_BFW_gNB_CUPHY*.h5'
pipeline "BFW graphs" "${EX}/bfc/cuphy_ex_bfc" -i TV -r 1 -m 1 -c -- 'TVnr_*_BFW_gNB_CUPHY*.h5'
pipeline "Simplex" "${EX}/simplex_decoder/cuphy_ex_simplex_decoder" -i TV -- 'TVnr_*SIMPLEX_gNB_CUPHY_s*.h5'

check_exit
