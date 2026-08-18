################################################################################
# Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT
################################################################################
"""StreamK partial-workspace store ordering with GroupLoadStore enabled."""

import os
import re

import pytest

from config_harness import emit_kernels_from_config

pytestmark = pytest.mark.unit

_ARCH = "gfx942"
_CONFIG = os.path.join(
    os.path.dirname(__file__),
    "data",
    "test_data",
    "_designed",
    "gfx942",
    "streamk_group_load_store.yaml",
)


def test_streamk_group_load_store_updates_each_workspace_offset_before_store():
    results = emit_kernels_from_config(_CONFIG, limit=1, arch=_ARCH)
    assert len(results) == 1

    base, source, error = results[0]
    assert error == 0, f"Kernel {base!r} failed to emit with error {error}"
    assert "GLS1" in source, f"Kernel {base!r} did not retain GroupLoadStore"

    lines = source.splitlines()
    partials_start = next(
        i for i, line in enumerate(lines) if line.startswith("label_SK_Partials")
    )
    workspace_stores = [
        i
        for i in range(partials_start, len(lines))
        if "buffer_store" in lines[i] and "sgprSrdWS" in lines[i]
    ]
    assert len(workspace_stores) >= 2, "Fixture did not emit multiple partial stores"

    first_store = lines[workspace_stores[0]]
    offset_match = re.search(r"\], (s(?:\[[^]]+\]|\d+)) offen", first_store)
    assert offset_match, f"Could not identify workspace soffset in {first_store!r}"
    offset = offset_match.group(1)
    offset_update = f"s_add_u32 {offset}, {offset},"

    for previous, current in zip(workspace_stores, workspace_stores[1:]):
        between = lines[previous + 1 : current]
        assert any(offset_update in line for line in between), (
            "Consecutive StreamK partial stores reused the workspace soffset "
            "without executing its update"
        )
