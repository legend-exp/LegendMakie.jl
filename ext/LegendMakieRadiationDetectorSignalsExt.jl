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

    # example waveforms of the filter optimization crosscheck: one column per event class,
    # waveforms on top, filter outputs at the legacy (dashed) and the new (solid) optimum below
    function LegendMakie.lplot!(
            report::NamedTuple{(:classes, :wvfs, :flt_legacy, :flt_new), <:Tuple{AbstractVector{Symbol},
                AbstractVector{<:RadiationDetectorSignals.RDWaveform}, AbstractVector{<:RadiationDetectorSignals.RDWaveform},
                AbstractVector{<:RadiationDetectorSignals.RDWaveform}}};
            xunit = Makie.Unitful.u"µs", title::AbstractString = "", titlesize = 18,
            watermark::Bool = true, final::Bool = !isempty(title), kwargs...
        )

        axes(report.classes) == axes(report.wvfs) == axes(report.flt_legacy) == axes(report.flt_new) || throw(DimensionMismatch(
            "classes, wvfs, flt_legacy and flt_new must share axes"))

        fig = Makie.current_figure()
        g = Makie.GridLayout(fig[1,1])
        colors = Makie.wong_colors()

        ax_flt = nothing
        for (col, class) in enumerate(unique(report.classes))
            ax_wf = Makie.Axis(g[1, col], title = replace(string(class), "_" => " "), titlefont = :bold,
                dim1_conversion = Makie.UnitfulConversion(xunit, units_in_label = false),
                ylabel = col == 1 ? "Waveform" : "")
            ax_flt = Makie.Axis(g[2, col], xlabel = "Time ($xunit)",
                dim1_conversion = Makie.UnitfulConversion(xunit, units_in_label = false),
                ylabel = col == 1 ? "Filter output" : "")
            members = [i for i in eachindex(report.classes) if report.classes[i] == class]
            for (k, i) in enumerate(members)
                color = colors[mod1(k, length(colors))]
                waveformplot!(ax_wf, report.wvfs[i]; color)
                waveformplot!(ax_flt, report.flt_legacy[i]; color, linestyle = :dash, label = k == 1 ? "Legacy" : nothing)
                waveformplot!(ax_flt, report.flt_new[i]; color, label = k == 1 ? "New" : nothing)
            end
            Makie.linkxaxes!(ax_wf, ax_flt)
            Makie.hidexdecorations!(ax_wf, grid = false)
            col == 1 && Makie.axislegend(ax_flt, position = :rt)
        end

        if !isempty(title)
            Makie.Label(g[1, :, Makie.Top()], title, padding = (0, 0, 25, 0), fontsize = titlesize, font = :bold)
        end

        Makie.current_axis!(ax_flt)
        watermark && LegendMakie.add_watermarks!(; final, kwargs...)
        fig
    end

end # module LegendMakieRadiationDetectorSignalsExt
