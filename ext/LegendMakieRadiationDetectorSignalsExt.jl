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

    # A waveform, or several in one axis, with an entry in the legend for every label given
    function LegendMakie.lplot!(
            wfs::Union{RadiationDetectorSignals.RDWaveform, AbstractVector{<:RadiationDetectorSignals.RDWaveform}};
            xunit = Makie.Unitful.u"µs", xlabel = "Time ($xunit)", ylabel = "Signal", title::AbstractString = "", titlesize = 18,
            xlims = nothing, ylims = nothing, label = nothing, legend_position = :rt,
            watermark::Bool = true, final::Bool = !isempty(title), kwargs...
        )
        fig = Makie.current_figure()
        ax = Makie.Axis(fig[1,1],
            dim1_conversion = Makie.UnitfulConversion(xunit, units_in_label = false),
            limits = (xlims, ylims), titlefont = :bold;
            xlabel, ylabel, title, titlesize
        )
        wfs isa RadiationDetectorSignals.RDWaveform && (wfs = (wfs,))
        labels = label isa AbstractString ? (label,) : isnothing(label) ? fill(nothing, length(wfs)) : label
        length(labels) == length(wfs) || throw(ArgumentError("$(length(labels)) labels given for $(length(wfs)) waveforms"))
        for (wf, l) in zip(wfs, labels)
            waveformplot!(ax, wf; label = l, kwargs...)
        end
        isnothing(label) || legend_position == :none || Makie.axislegend(ax, position = legend_position)
        watermark && LegendMakie.add_watermarks!(; final)
        fig
    end

end # module LegendMakieRadiationDetectorSignalsExt
