# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

module LegendMakieRadiationDetectorSignalsExt

    import LegendMakie
    import Makie

    import RadiationDetectorSignals

    import LegendMakie: waveformplot!

    Makie.@recipe(WaveformPlot, wf) do scene
        Makie.Attributes(
            linewidth = 1,
        )
    end
        
    # Needed for creatings legend using Makie recipes
    # https://discourse.julialang.org/t/makie-defining-legend-output-for-a-makie-recipe/121567
    function Makie.get_plots(p::WaveformPlot)
        return p.plots
    end

    function Makie.plot!(p::WaveformPlot{<:Tuple{<:RadiationDetectorSignals.RDWaveform}})
        wf = p.wf[]
        Makie.lines!(p, wf.time, wf.signal; p.attributes...)
        p
    end

end # module LegendMakieRadiationDetectorSignalsExt
