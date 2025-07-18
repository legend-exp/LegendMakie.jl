# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

module LegendMakieRadiationDetectorSignalsExt

    import LegendMakie
    import Makie

    import RadiationDetectorSignals

    import LegendMakie: waveformplot!

    Makie.@recipe(WaveformPlot, wf) do scene
        Makie.Attributes(
            linewidth = 1,
            label = nothing,
        )
    end
        
    function Makie.plot!(p::WaveformPlot{<:Tuple{<:RadiationDetectorSignals.RDWaveform}})
        wf = p.wf[]
        attr = Makie.Attributes(p)
        Makie.lines!(p, attr, wf.time, wf.signal, label = p.label)
        p
    end

end # module LegendMakieRadiationDetectorSignalsExt
