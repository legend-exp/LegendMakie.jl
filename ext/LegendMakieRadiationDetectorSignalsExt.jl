# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

module LegendMakieRadiationDetectorSignalsExt

    import LegendMakie
    import Makie

    import RadiationDetectorSignals

    import LegendMakie: waveformplot!

    Makie.@recipe WaveformPlot (wf,) begin 
        cycle = [:color]
        color = @inherit linecolor
        joinstyle = @inherit joinstyle
        linecap = @inherit linecap
        alpha = 1.0
        linewidth = 1
        linestyle = nothing
        label = nothing
    end
        
    function Makie.plot!(p::WaveformPlot{<:Tuple{<:RadiationDetectorSignals.RDWaveform}})
        wf = p.wf[]
        attr = Makie.Attributes(p)
        Makie.lines!(p, attr, wf.time, wf.signal)
        p
    end

end # module LegendMakieRadiationDetectorSignalsExt
