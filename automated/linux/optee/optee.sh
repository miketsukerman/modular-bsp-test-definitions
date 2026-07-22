#!/bin/bash
# shellcheck disable=SC2154
#
# optee.sh
#
# Advantech BSP QA – OP-TEE checks
# Ported from test_optee() in qa/test_board.sh
#
# Copyright (c) 2024 Advantech Co., Ltd. All rights reserved
#

# shellcheck source=../lib/adv-test-lib.sh
. "$(dirname "$0")/../lib/adv-test-lib.sh"

create_out_dir

: "${OPTEE_DEV:=/dev/tee0}"
: "${OPTEE_FULL_TEST:=0}"

if [ -n "${OPTEE_DEV}" ]; then
    verbose_log "L-OPTEE-DEV" "Checking OP-TEE device node ${OPTEE_DEV}"
    if chk_rw_cdev "${OPTEE_DEV}"; then
        report_pass "L-OPTEE-DEV"
    else
        report_fail "L-OPTEE-DEV"
        exit 0
    fi
fi

if chk_cmd xtest; then
    if [ "${OPTEE_FULL_TEST}" = "1" ]; then
        xt_args=""
    else
        xt_args="1001"
    fi

    verbose_log "L-OPTEE-XTEST-F" "Running xtest ${xt_args} (limited output below)"
    # xtest can produce large output; capture only the last 50 lines when verbose.
    if [ "${VERBOSE}" = "1" ]; then
        xtest_logf="${OUTPUT}/$(lava_id L-OPTEE-XTEST-F).log"
        # shellcheck disable=SC2086
        xtest ${xt_args} 2>&1 | tail -n 50 | tee -a "${xtest_logf}" >&2
        xtest_rc=${PIPESTATUS[0]}
    else
        # shellcheck disable=SC2086
        xtest ${xt_args} >/dev/null 2>&1
        xtest_rc=$?
    fi

    if [ "${xtest_rc}" -eq 0 ]; then
        report_pass "L-OPTEE-XTEST-F"
    else
        report_fail "L-OPTEE-XTEST-F"
    fi
else
    report_skip "L-OPTEE-XTEST-F"
fi
