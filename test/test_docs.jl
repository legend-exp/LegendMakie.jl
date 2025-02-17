# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

using Test
using LegendMakie
import Documenter

Documenter.DocMeta.setdocmeta!(
    LegendMakie,
    :DocTestSetup,
    :(using LegendMakie);
    recursive=true,
)
Documenter.doctest(LegendMakie)
