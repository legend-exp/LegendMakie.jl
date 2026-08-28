# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

"""
    LegendMakie

Template for Julia packages.
"""
module LegendMakie

    include("utils.jl")
    include("lplot.jl")
    include("register_extdeps.jl")
    include("plotting_structs.jl")

    function __init__()
        _register_extension_deps(
            lplot => :Makie,
            lplot! => :Makie,
            lhist => :Makie,
            lhist! => :Makie,
            lsavefig => :Makie
        )
    end

    export TimeSeriesHeatmapReport, EnergyHistReport, GainStabilityReport
end # module
