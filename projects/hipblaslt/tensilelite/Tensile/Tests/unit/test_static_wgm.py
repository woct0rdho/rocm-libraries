# Copyright Advanced Micro Devices, Inc., or its affiliates.
# SPDX-License-Identifier: MIT

from types import SimpleNamespace

import pytest
from rocisa.enum import RegisterType
from rocisa.label import LabelManager
from rocisa.register import RegisterPool

from Tensile.Components.WorkGroupMappingAlgos import DefaultWGM
from Tensile.KernelWriterAssembly import KernelWriterAssembly

pytestmark = pytest.mark.unit


def _default_wgm_assembly(work_group_mapping):
    writer = object.__new__(KernelWriterAssembly)
    writer.sgprPool = RegisterPool(
        0, RegisterType.Sgpr, defaultPreventOverflow=False, printRP=False
    )
    writer.vgprPool = RegisterPool(
        0, RegisterType.Vgpr, defaultPreventOverflow=False, printRP=False
    )
    writer.labels = LabelManager()
    writer.db = {"AssertOnSgprOverflow": False}
    writer.states = SimpleNamespace(
        overflowedResources=0,
        regCaps={"MaxSgpr": 102},
    )
    kernel = {
        "ClusterDim": [1, 1],
        "WavefrontSize": 32,
        "WorkGroupMapping": work_group_mapping,
        "WorkGroupMappingXCC": 1,
    }

    return str(DefaultWGM(writer, kernel, "WGM"))


def test_wgm8_emits_guarded_static_mapping():
    assembly = _default_wgm_assembly(8)

    assert "use static WGM fast path?" in assembly
    assert "nwg1 % WGM" in assembly
    assert assembly.count("label_WGMStaticFallback") == 3
    assert "static WGM quotient" in assembly


@pytest.mark.parametrize("work_group_mapping", [-8, 1, 4, 16])
def test_non_wgm8_omits_static_mapping(work_group_mapping):
    assembly = _default_wgm_assembly(work_group_mapping)

    assert "use static WGM fast path?" not in assembly
    assert "WGMStaticFallback" not in assembly
    assert "static WGM quotient" not in assembly
