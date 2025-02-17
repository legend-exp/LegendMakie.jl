# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

"""
    LegendMakie

Template for Julia packages.
"""
module LegendMakie

    import MakieCore
    import MakieCore: Theme

    include("utils.jl")
    include("legend_theme.jl")

    include("lmplot.jl")

    include("extdefs_rdsignals.jl")

    include("register_extdeps.jl")

    function __init__()
        _register_extension_deps(
            some_custom_waveform_plot => :RadiationDetectorSignals,
        )
    end

end # module
