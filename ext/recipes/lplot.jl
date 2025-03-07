# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

function round_wo_units(x::Unitful.RealOrRealQuantity; digits::Int=2)
    Unitful.unit(x) == Unitful.NoUnits ? round(x; digits) : round(Unitful.unit(x), x; digits)
end

function LegendMakie.default_xlims(report::NamedTuple{(:f_fit, :h, :μ, :σ, :gof)})
    Unitful.ustrip.((report.μ - 5*report.σ, report.μ + 5*report.σ))
end


# single fits
function LegendMakie.lplot!(
        report::NamedTuple{(:f_fit, :h, :μ, :σ, :gof)};
        title::AbstractString = "", show_residuals::Bool = true,
        ylims = (0,nothing), xlabel = "", xticks = Makie.automatic, 
        xlims = LegendMakie.default_xlims(report), 
        legend_position = :lt, watermark::Bool = true, final::Bool = !isempty(title), kwargs...
    )

    fig = Makie.current_figure()
    
    g = Makie.GridLayout(fig[1,1])
    ax = Makie.Axis(g[1,1], 
        title = title, titlefont = :bold, titlesize = 16pt, xlabel = xlabel,
        xticks = xticks, limits = (xlims, ylims), ylabel = "Normalized Counts",
    )
    
    # Create histogram
    Makie.plot!(ax, report.h, label = "Data")
    
    _x = range(extrema(xlims)..., length = 1000)
    Makie.lines!(_x, report.f_fit.(_x), color = :red, 
        label = "Normal Fit\nμ = $(round_wo_units(report.μ, digits=2))\nσ = $(round_wo_units(report.σ, digits=2))")
    
    if legend_position != :none 
        Makie.axislegend(ax, position = legend_position)
    end
    
    if !isempty(report.gof) && show_residuals

        ax.xticklabelsize = 0
        ax.xticksize = 0
        ax.xlabel = ""

        ax2 = Makie.Axis(g[2,1], xticks = xticks, yticks = -3:3:3, limits = (xlims,(-5,5)), xlabel = xlabel, ylabel = "Residuals (σ)")
        LegendMakie.residualplot!(ax2, (x = report.gof.bin_centers, residuals_norm = [ifelse(abs(r) < 1e-6, 0.0, r) for r in report.gof.residuals_norm]))

        # link axis and put plots together
        Makie.linkxaxes!(ax, ax2)
        Makie.rowgap!(g, 0)
        Makie.rowsize!(g, 1, Makie.Auto(3))

        # align ylabels
        yspace = maximum(Makie.tight_yticklabel_spacing!, (ax, ax2))
        ax.yticklabelspace = yspace
        ax2.yticklabelspace = yspace
    end

    # add watermarks
    Makie.current_axis!(ax)
    watermark && LegendMakie.add_watermarks!(; final, kwargs...)
    
    fig
end

function LegendMakie.lplot!(
        report::NamedTuple{(:v, :h, :f_fit, :f_components, :gof)};
        xlabel = "Energy (keV)", ylabel = "Counts / bin",
        title::AbstractString = "", legend_position = :lt,
        xlims = extrema(first(report.h.edges)), 
        ylims = let (_min, _max) = extrema(filter(x -> x > 0, report.h.weights))
            scale = (_max/_min)^(1/4)
            (_min / sqrt(scale), _max * scale)
        end,
        show_label::Bool = true, show_components::Bool = true, yticks = Makie.automatic,
        watermark::Bool = true, final::Bool = !isempty(title),
        show_residuals::Bool = true, row::Int = 1, col::Int = 1, kwargs...
    )

    
    fig = Makie.current_figure()

    # create plot
    g = Makie.GridLayout(fig[row,col])
    ax = Makie.Axis(g[1,1], 
        title = title, titlefont = :bold, titlesize = 16pt, 
        xlabel = xlabel, ylabel = ylabel, yticks = yticks,
        limits = (xlims, ylims),
        yscale = Makie.log10
    )

    Makie.hist!(ax, StatsBase.midpoints(first(report.h.edges)), weights = report.h.weights, bins = first(report.h.edges), color = LegendMakie.DiamondGrey, label = "Data", fillto = 1e-2)
    Makie.lines!(range(xlims..., length = 1000), x -> report.f_fit(x) * step(first(report.h.edges)), color = :black, label = ifelse(show_label, "Best Fit" * (!isempty(report.gof) ? " (p = $(round(report.gof.pvalue, digits=2)))" : ""), ""))
                
    if show_components
        for (idx, component) in enumerate(keys(report.f_components.funcs))
            Makie.lines!(
                range(extrema(first(report.h.edges))..., length = 1000), 
                x -> report.f_components.funcs[component](x) * step(first(report.h.edges)), 
                color = report.f_components.colors[component], 
                label = ifelse(show_label, report.f_components.labels[component], ""),
                linestyle = report.f_components.linestyles[component],
                linewidth = 4
            )
        end
    end

    if legend_position != :none 
        Makie.axislegend(ax, position = legend_position)
    end

    if !isempty(report.gof) && show_residuals

        ax.xticklabelsize = 0
        ax.xticksize = 0
        ax.xlabel = ""

        ax2 = Makie.Axis(g[2,1],
                xlabel = xlabel, ylabel = "Residuals (σ)",
                yticks = -3:3:3, limits = (xlims,(-5,5))
            )
        LegendMakie.residualplot!(ax2, (x = StatsBase.midpoints(first(report.h.edges)), residuals_norm = report.gof.residuals_norm))

        Makie.linkxaxes!(ax, ax2)
        Makie.rowgap!(g, 0)
        Makie.rowsize!(g, 1, Makie.Auto(3))

        # align ylabels
        yspace = maximum(Makie.tight_yticklabel_spacing!, (ax, ax2))
        ax.yticklabelspace = yspace
        ax2.yticklabelspace = yspace
    end

    # add watermarks
    Makie.current_axis!(ax)
    watermark && LegendMakie.add_watermarks!(; final, kwargs...)

    fig
end

# Ecal
function LegendMakie.lplot!(
        report::NamedTuple{(:f_calib, :h_cal, :h_uncal, :c, :peak_positions, :threshold)},
        cal_lines::Vector{<:Unitful.Energy} = typeof(1.0u"keV")[];
        e_unit = u"keV", title::AbstractString = "", xlabel = "Energy ($(e_unit))", ylabel = "Counts / $(round(step(first(report.h_cal.edges)), digits = 2)) keV",
        yscale = Makie.log10, xlims = (0,3000), ylims = (0.9, maximum(report.h_cal.weights)*1.2),
        xticks = 0:250:3000, legend_position = :rt,
        watermark::Bool = true, final::Bool = !isempty(title), kwargs...
    )

    fig = Makie.current_figure()
    ax = Makie.Axis(fig[1,1]; limits = (xlims, ylims), title, xticks, xlabel, ylabel, yscale)

    Makie.stephist!(ax, StatsBase.midpoints(first(report.h_cal.edges)), weights = replace(report.h_cal.weights, 0=>1e-10), bins = first(report.h_cal.edges), label = "e_fc")
    !isempty(cal_lines) && Makie.vlines!(ax, Unitful.ustrip.(e_unit, cal_lines), color = :red, label = "Th228 Calibration Lines")
    legend_position != :none && Makie.axislegend(ax, position = legend_position, framevisible = true, framecolor = :lightgray)
        
    Makie.current_axis!(ax)
    watermark && LegendMakie.add_watermarks!(; final, kwargs...)
    fig
end

function LegendMakie.lplot!(
        report::NamedTuple{(:h_calsimple, :h_uncal, :c, :fep_guess, :peakhists, :peakstats)};
        cal::Bool = true, title::AbstractString = "", yscale = Makie.log10, 
        final::Bool = !isempty(title), watermark::Bool = true, kwargs...
    )
    
    fig = Makie.current_figure()
    
    # select correct histogram
    h = LinearAlgebra.normalize(cal ? report.h_calsimple : report.h_uncal, mode = :density)
    fep_guess = cal ? 2614.5 : report.fep_guess

    # create main histogram plot
    ax = Makie.Axis(
        fig[1,1], 
        title = title, titlegap = 2,
        limits = (0, cal ? 3000 : 1.2*report.fep_guess, 0.99*minimum(filter(x -> x > 0, h.weights)), 1.2 * maximum(h.weights)*1.1),
        xticks = cal ? (0:300:3000) : (0:50000:1.2*report.fep_guess),
        xlabel = "Energy ($(cal ? "keV" : "ADC"))",
        ylabel = "Counts",
        yscale = yscale
    )
    
    Makie.stephist!(ax, StatsBase.midpoints(first(h.edges)), bins = first(h.edges), weights = h.weights, label = "Energy")
    Makie.vlines!(ax, [fep_guess], color = :red, label = "FEP Guess", linewidth = 1.5)
    Makie.axislegend(ax, position = :ct)
    
    # add watermarks
    Makie.current_axis!(ax)
    watermark && LegendMakie.add_watermarks!(; final, kwargs...)
    
    fig
end

# A/E
function LegendMakie.lplot!( 
        report::NamedTuple{(:par, :f_fit, :x, :y, :gof, :e_unit, :label_y, :label_fit)}; 
        title::AbstractString = "", show_residuals::Bool = true,
        xticks = 500:250:2250, xlims = (500,2300), ylims = nothing,
        legend_position = :rt, row::Int = 1, col::Int = 1, 
        watermark::Bool = false, final::Bool = !isempty(title), kwargs...
    )

    fig = Makie.current_figure()

    # create plot
    g = Makie.GridLayout(fig[row,col])
    ax = Makie.Axis(g[1,1], 
        title = title, titlefont = :bold, titlesize = 16pt, 
        xlabel = "E ($(report.e_unit))", ylabel = report.label_y * " (a.u.)", 
        xticks = xticks, limits = (xlims, ylims)
    )

    LegendMakie.aoecorrectionplot!(ax, report)
    if legend_position != :none 
        Makie.axislegend(ax, position = legend_position)
    end

    # add residuals
    if !isempty(report.gof) && show_residuals

        ax.xticklabelsize = 0
        ax.xticksize = 0
        ax.xlabel = ""

        ax2 = Makie.Axis(g[2,1],
            xlabel = "E ($(report.e_unit))", ylabel = "Residuals (σ)",
            xticks = xticks, yticks = -3:3:3, limits = (xlims,(-5,5))
        )
        LegendMakie.residualplot!(ax2, (x = report.x, residuals_norm = report.gof.residuals_norm))

        # link axis and put plots together
        Makie.linkxaxes!(ax, ax2)
        Makie.rowgap!(g, 0)
        Makie.rowsize!(g, 1, Makie.Auto(3))

        # align ylabels
        yspace = maximum(Makie.tight_yticklabel_spacing!, (ax, ax2))
        ax.yticklabelspace = yspace
        ax2.yticklabelspace = yspace
    end

    # add watermarks
    Makie.current_axis!(ax)
    watermark && LegendMakie.add_watermarks!(; final, kwargs...)

    fig 
end


function LegendMakie.lplot!( 
        report::NamedTuple{(:h_before, :h_after_low, :h_after_ds, :dep_h_before, :dep_h_after_low, :dep_h_after_ds, :sf, :n0, :lowcut, :highcut, :e_unit, :bin_width)}; 
        title::AbstractString = "", watermark::Bool = true, final::Bool = true, kwargs...
    )

    fig = Makie.current_figure()

    # create main histogram plot
    ax = Makie.Axis(fig[1,1],
        title = title, limits = ((0,2700), (1,maximum(report.h_before.weights) * 1.2)), yscale = Makie.log10,
        xlabel = "Energy (keV)", ylabel = "Counts / $(round(step(first(report.h_before.edges)), digits = 2)) keV", 
    )
    Makie.stephist!(ax, StatsBase.midpoints(first(report.h_before.edges)),    weights = report.h_before.weights,    bins = first(report.h_before.edges),    color = (LegendMakie.AchatBlue, 0.5),  label = "Before A/E")
    Makie.stephist!(ax, StatsBase.midpoints(first(report.h_after_low.edges)), weights = report.h_after_low.weights, bins = first(report.h_after_low.edges), color = (LegendMakie.BEGeOrange, 1), label = "After low A/E")
    Makie.stephist!(ax, StatsBase.midpoints(first(report.h_after_ds.edges)),  weights = report.h_after_ds.weights,  bins = first(report.h_after_ds.edges),  color = (LegendMakie.CoaxGreen, 0.5),  label = "After DS A/E")
    Makie.axislegend(ax, position = (0.96,1))

    # add inset
    ax_inset = Makie.Axis(fig[1,1],
        width = Makie.Relative(0.4),
        height = Makie.Relative(0.2),
        halign = 0.55,
        valign = 0.95, 
        yscale = Makie.log10,
        xlabel = "Energy (keV)",
        ylabel = "Counts",
        xticks = 1585:10:1645,
        xlabelsize = 12pt,
        ylabelsize = 12pt,
        xticklabelsize = 10pt,
        yticklabelsize = 10pt,
        yticks = (exp10.(0:10), "1" .* join.(fill.("0", 0:10))),
        limits = (extrema(first(report.dep_h_before.edges)), (0.9, max(100, maximum(report.dep_h_before.weights)) * 1.2))
    )
    Makie.stephist!(ax_inset, StatsBase.midpoints(first(report.dep_h_before.edges)),    weights = replace(report.dep_h_before.weights, 0 => 1e-10),    bins = first(report.dep_h_before.edges),    color = (LegendMakie.AchatBlue, 0.5),  label = "Before A/E")
    Makie.stephist!(ax_inset, StatsBase.midpoints(first(report.dep_h_after_low.edges)), weights = replace(report.dep_h_after_low.weights, 0 => 1e-10), bins = first(report.dep_h_after_low.edges), color = (LegendMakie.BEGeOrange, 1), label = "After low A/E")
    Makie.stephist!(ax_inset, StatsBase.midpoints(first(report.dep_h_after_ds.edges)),  weights = replace(report.dep_h_after_ds.weights, 0 => 1e-10),  bins = first(report.dep_h_after_ds.edges),  color = (LegendMakie.CoaxGreen, 0.5),  label = "After DS A/E")

    # add watermarks
    Makie.current_axis!(ax)
    watermark && LegendMakie.add_watermarks!(; final, kwargs...)

    fig
end


function LegendMakie.lplot!( 
        report::NamedTuple{(:par, :f_fit, :x, :y, :gof, :e_unit, :label_y, :label_fit)},
        com_report::NamedTuple{(:values, :label_y, :label_fit, :energy)};
        legend_position = :rt, row::Int = 1, col::Int = 1, kwargs...
    )

    fig = LegendMakie.lplot!(report, legend_position = :none, col = col; kwargs...)

    g = last(Makie.contents(fig[row,col]))
    ax = Makie.contents(g)[1]
    Makie.lines!(ax, com_report.energy, com_report.values, linewidth = 4, color = :red, linestyle = :dash, label = LaTeXStrings.latexstring("\\fontfamily{Roboto}" * com_report.label_fit))
    Makie.axislegend(ax, position = legend_position)

    fig
end

function LegendMakie.lplot!(
        report::NamedTuple{(:peak, :window, :fct, :bin_width, :bin_width_qdrift, :e_peak, :e_ctc, :qdrift_peak, :h_before, :h_after, :fwhm_before, :fwhm_after, :report_before, :report_after)};
        label_before = "Before correction", label_after = "After correction", title::AbstractString = "", watermark::Bool = true, 
        xlims = extrema(first(report.h_before.edges)), e_unit = u"keV", kwargs...
    )

    # Best results for figsize (600,600)
    fig = Makie.current_figure()

    g = Makie.GridLayout(fig[1,1])

    ax = Makie.Axis(g[1,1], limits = (xlims...,0,nothing), ylabel = "Counts / $(round(step(first(report.h_before.edges)), digits = 2))")
    Makie.plot!(ax, report.h_before, color = :darkgrey, label = label_before)
    Makie.plot!(ax, report.h_after, color = (:purple, 0.5), label = label_after)
    Makie.axislegend(position = :lt)

    ax2 = Makie.Axis(g[2,1], limits = (xlims...,0,1-1e-5), xticks = 2400:10:2630, yticks = 0:0.2:1, xlabel = "Energy ($e_unit)", ylabel = "Qdrift / E (a.u.)")
    k_before = KernelDensity.kde((Unitful.ustrip.(e_unit, report.e_peak), report.qdrift_peak ./ maximum(report.qdrift_peak)))
    k_after = KernelDensity.kde((Unitful.ustrip.(e_unit, report.e_ctc), report.qdrift_peak ./ maximum(report.qdrift_peak)))
    Makie.contourf!(ax2, k_before.x, k_before.y, k_before.density, levels = 15, colormap = :binary)
    Makie.contour!(ax2, k_before.x, k_before.y, k_before.density, levels = 15 - 1, color = :white)
    Makie.contour!(ax2, k_after.x, k_after.y, k_after.density, levels = 15 - 1, colormap = :plasma)
    Makie.lines!(ax2, [0], [0], label = label_before, color = :darkgrey)
    Makie.lines!(ax2, [0], [0], label = label_after, color = (:purple, 0.5))
    Makie.axislegend(position = :lb)

    ax3 = Makie.Axis(g[2,2], limits = (0,nothing,0,1-1e-5), xlabel = "Counts / 0.1")
    Makie.plot!(ax3, StatsBase.fit(StatsBase.Histogram, report.qdrift_peak ./ maximum(report.qdrift_peak), 0:0.01:1), color = :darkgrey, label = "Before correction", direction = :x)
    ax3.xticks = Makie.WilkinsonTicks(3, k_min = 3, k_max=4)

    # Formatting
    Makie.linkxaxes!(ax,ax2)
    Makie.hidexdecorations!(ax)
    Makie.rowgap!(g, 0)
    Makie.rowsize!(g, 1, Makie.Auto(0.5))
    Makie.linkyaxes!(ax2,ax3)
    Makie.hideydecorations!(ax3)
    Makie.colgap!(g, 0)
    Makie.colsize!(g, 2, Makie.Auto(0.5))
    xspace = maximum(Makie.tight_xticklabel_spacing!, (ax2, ax3))
    ax2.xticklabelspace = xspace
    ax3.xticklabelspace = xspace
    yspace = maximum(Makie.tight_yticklabel_spacing!, (ax, ax2))
    ax.yticklabelspace = yspace
    ax2.yticklabelspace = yspace

    # add general title
    if !isempty(title)
        Makie.Label(g[1,:,Makie.Top()], title, padding = (0,0,2,0), fontsize = 20, font = :bold)
    end

    # add watermarks
    Makie.current_axis!(ax3)
    watermark && LegendMakie.add_watermarks!(; kwargs...)

    fig
end


function LegendMakie.lplot!( 
        report::NamedTuple{(:peak, :window, :fct, :bin_width, :bin_width_qdrift, :aoe_peak, :aoe_ctc, :qdrift_peak, :h_before, :h_after, :σ_before, :σ_after, :report_before, :report_after)};
        label_before = "Before correction", label_after = "After correction", title::AbstractString = "", watermark::Bool = true, kwargs...
    )

    # Best results for figsize (600,600)
    fig = Makie.current_figure()
    
    g = Makie.GridLayout(fig[1,1])
    
    ax = Makie.Axis(g[1,1], limits = (-9,5,0,nothing), ylabel = "Counts / $(round(step(first(report.h_before.edges)), digits = 2))")
    Makie.plot!(ax, report.h_before, color = :darkgrey, label = label_before)
    Makie.plot!(ax, report.h_after, color = (:purple, 0.5), label = label_after)
    Makie.axislegend(position = :lt)
    
    ax2 = Makie.Axis(g[2,1], limits = (-9,5,0,11.5), xticks = -8:2:5, yticks = 0:2:10, xlabel = "A/E classifier", ylabel = "Qdrift / E")
    k_before = KernelDensity.kde((report.aoe_peak, report.qdrift_peak))
    k_after = KernelDensity.kde((report.aoe_ctc, report.qdrift_peak))
    Makie.contourf!(ax2, k_before.x, k_before.y, k_before.density, levels = 15, colormap = :binary)
    Makie.contour!(ax2, k_before.x, k_before.y, k_before.density, levels = 15 - 1, color = :white)
    Makie.contour!(ax2, k_after.x, k_after.y, k_after.density, levels = 15 - 1, colormap = :plasma)
    Makie.lines!(ax2, [0], [0], label = label_before, color = :darkgrey)
    Makie.lines!(ax2, [0], [0], label = label_after, color = (:purple, 0.5))
    Makie.axislegend(position = :lb)
     
    ax3 = Makie.Axis(g[2,2], limits = (0,nothing,0,11.5), xlabel = "Counts / 0.1")
    Makie.plot!(ax3, StatsBase.fit(StatsBase.Histogram, report.qdrift_peak, 0:0.1:11.5), color = :darkgrey, label = "Before correction", direction = :x)
    ax3.xticks = Makie.WilkinsonTicks(3, k_min = 3, k_max=4)
    
    # Formatting
    Makie.linkxaxes!(ax,ax2)
    Makie.hidexdecorations!(ax)
    Makie.rowgap!(g, 0)
    Makie.rowsize!(g, 1, Makie.Auto(0.5))
    Makie.linkyaxes!(ax2,ax3)
    Makie.hideydecorations!(ax3)
    Makie.colgap!(g, 0)
    Makie.colsize!(g, 2, Makie.Auto(0.5))
    xspace = maximum(Makie.tight_xticklabel_spacing!, (ax2, ax3))
    ax2.xticklabelspace = xspace
    ax3.xticklabelspace = xspace
    yspace = maximum(Makie.tight_yticklabel_spacing!, (ax, ax2))
    ax.yticklabelspace = yspace
    ax2.yticklabelspace = yspace

    # add general title
    if !isempty(title)
        Makie.Label(g[1,:,Makie.Top()], title, padding = (0,0,2,0), fontsize = 20, font = :bold)
    end
    
    # add watermarks
    Makie.current_axis!(ax3)
    watermark && LegendMakie.add_watermarks!(; kwargs...)
    
    fig
end

# LQ plots
function LegendMakie.lplot!(
        report::NamedTuple{(:hist_dep, :hist_sb1, :hist_sb2, :hist_subtracted, :hist_corrected)};
        title::AbstractString = "", xlabel = "LQ (a.u.)", ylabel = "Counts", legend_position = :rt,
        xlims = nothing, ylims = (0, nothing), final::Bool = !isempty(title),
        watermark::Bool = true, kwargs...
    )
    
    fig = Makie.current_figure()
    ax = Makie.Axis(fig[1,1]; limits = (xlims, ylims), title, xlabel, ylabel)
    
    let h = report.hist_dep, h1 = report.hist_sb1, h2 = report.hist_sb2
    Makie.stephist!(ax, StatsBase.midpoints(first(h.edges)), bins = first(h.edges), weights = h.weights, label = "Peak")
    Makie.stephist!(ax, StatsBase.midpoints(first(h1.edges)), bins = first(h1.edges), weights = h1.weights, label = "Sideband 1")
    Makie.stephist!(ax, StatsBase.midpoints(first(h2.edges)), bins = first(h2.edges), weights = h2.weights, label = "Sideband 2")
    end
    
    legend_position != :none && Makie.axislegend(position = legend_position)
    
    watermark && LegendMakie.add_watermarks!(; final, kwargs...)
    fig
end

function LegendMakie.lplot!(
        report::NamedTuple{(:e_cal, :lq_class, :cut_value)};
        title::AbstractString = "", e_unit = Unitful.unit(first(report.e_cal)), 
        xlabel = "Energy ($e_unit)", ylabel = "Counts", yscale = Makie.log10,
        watermark::Bool = true, final::Bool = !isempty(title), kwargs...
    )
    
    # best results for figsize = (750,400)
    fig = Makie.current_figure()
    
    h = StatsBase.fit(StatsBase.Histogram, Unitful.ustrip.(e_unit, report.e_cal), 0:1:3000)
    ax = Makie.Axis(fig[1,1],
        limits = ((0,2700), (1,maximum(h.weights)*1.2));
        title, xlabel, ylabel = ylabel * " / $(e_unit)", yscale
    )

    Makie.stephist!(ax, Unitful.ustrip.(e_unit, report.e_cal), bins = 0:1:3000,  color = (LegendMakie.AchatBlue, 0.5),  label = "Before LQ")
    Makie.stephist!(ax, Unitful.ustrip.(e_unit, report.e_cal)[report.lq_class .> report.cut_value], bins = 0:1:3000, color = (LegendMakie.BEGeOrange, 1),  label = "Cut by LQ")
    Makie.stephist!(ax, Unitful.ustrip.(e_unit, report.e_cal)[report.lq_class .<= report.cut_value], bins = 0:1:3000, color = (LegendMakie.CoaxGreen, 0.7), label = "Surviving LQ")
    Makie.axislegend(ax, position = (0.96,1))

    # add inset
    h_in = StatsBase.fit(StatsBase.Histogram, Unitful.ustrip.(e_unit, report.e_cal), 1583:0.5:1640)
    ax_inset = Makie.Axis(fig[1,1],
        width = Makie.Relative(0.4),
        height = Makie.Relative(0.2),
        halign = 0.55,
        valign = 0.95, 
        yscale = yscale,
        xlabel = xlabel,
        ylabel = ylabel,
        xticks = 1585:10:1645,
        xlabelsize = 12pt,
        ylabelsize = 12pt,
        xticklabelsize = 10pt,
        yticklabelsize = 10pt,
        yticks = (exp10.(0:10), "1" .* join.(fill.("0", 0:10))),
        limits = (extrema(first(h_in.edges)), (0.9, max(100, maximum(h_in.weights)) * 1.2))
    )
    Makie.stephist!(ax_inset, Unitful.ustrip.(e_unit, report.e_cal), bins = 1583:0.5:1640,  color = (LegendMakie.AchatBlue, 0.5),  label = "Before A/E")
    Makie.stephist!(ax_inset, Unitful.ustrip.(e_unit, report.e_cal)[report.lq_class .> report.cut_value],  bins = 1583:0.5:1640, color = (LegendMakie.BEGeOrange, 1.0),  label = "Before A/E")
    Makie.stephist!(ax_inset, Unitful.ustrip.(e_unit, report.e_cal)[report.lq_class .<= report.cut_value], bins = 1583:0.5:1640, color = (LegendMakie.CoaxGreen, 0.7),  label = "Before A/E")

    Makie.current_axis!(ax)
    watermark && LegendMakie.add_watermarks!(final = true)
    
    fig
end

function LegendMakie.lplot!(
        report::NamedTuple{(:e_cal, :edges, :dep_σ)};
        e_unit = Unitful.unit(first(report.e_cal)), 
        h = StatsBase.fit(StatsBase.Histogram, Unitful.ustrip.(e_unit, report.e_cal), 1500:1:1650),
        xlims = extrema(first(h.edges)), ylims = (0, maximum(h.weights)*1.2),
        title::AbstractString = "", xlabel = "Energy ($e_unit)", ylabel = "Counts / $(e_unit)",
        legend_position = :lt, watermark::Bool = true, final::Bool = !isempty(title), kwargs...
    )
    
    fig = Makie.current_figure()
    
    ax = Makie.Axis(fig[1,1], limits = (xlims, ylims); title, xlabel, ylabel)
    
    Makie.stephist!(ax, StatsBase.midpoints(first(h.edges)), weights = h.weights, bins = first(h.edges),
        label = "Energy Spectrum (σ: $(round(e_unit, report.dep_σ, digits=2)))")
    Makie.vlines!(ax, Unitful.ustrip.(e_unit, [report.edges.DEP_edge_left, report.edges.DEP_edge_right]), color = LegendMakie.BEGeOrange, label = "DEP region")
    Makie.vlines!(ax, Unitful.ustrip.(e_unit, [report.edges.sb1_edge, report.edges.sb2_edge]), color = LegendMakie.CoaxGreen, label = "Side bands")
    
    Makie.band!(ax, Unitful.ustrip.(e_unit, [report.edges.DEP_edge_left, report.edges.DEP_edge_right]), 0, maximum(h.weights)*1.2, color = (LegendMakie.BEGeOrange, 0.1))
    Makie.band!(ax, Unitful.ustrip.(e_unit, [min(report.edges.sb1_edge, report.edges.sb2_edge), report.edges.DEP_edge_left]), 0, maximum(h.weights)*1.2, color = (LegendMakie.CoaxGreen, 0.1))
    if report.edges.sb2_edge > report.edges.sb1_edge 
        Makie.band!(ax, Unitful.ustrip.(e_unit, [report.edges.DEP_edge_right, report.edges.sb2_edge]), 0, maximum(h.weights)*1.2, color = (LegendMakie.CoaxGreen, 0.1))
    end
    
    legend_position != :none && Makie.axislegend(ax, position = legend_position)
    
    Makie.current_axis!(ax)
    watermark && LegendMakie.add_watermarks!(; final, kwargs...)
    
    fig
end

function LegendMakie.lplot!(
        report::NamedTuple{(:lq_report, :drift_report, :lq_box, :drift_time_func, :dep_left, :dep_right)},
        e_cal, dt_eff, lq_e_corr, plot_type::Symbol = :whole;
        title::AbstractString = "", xlabel = "Drift time (a.u.)", ylabel = "LQ (a.u.)", 
        colorscale = plot_type == :whole ? Makie.log10 : Makie.identity,
        watermark::Bool = true, final::Bool = !isempty(title), kwargs...
    )
    
    # best results for figsize = (620,400)
    sel = isfinite.(e_cal) .&& (plot_type == :whole .|| report.dep_left .< e_cal .< report.dep_right)
    let l = report.lq_box.t_lower, r = report.lq_box.t_upper, b = report.lq_box.lq_lower, t = report.lq_box.lq_upper
        xlims = (2l-r, 2r-l)
        ylims = plot_type == :whole ? (9b-8t, 9t-8b) : (2b-t, 5t-4b)
        LegendMakie.lhist!(StatsBase.fit(StatsBase.Histogram, (dt_eff[sel], lq_e_corr[sel]), 
            (range(xlims..., length = (plot_type == :whole ? 200 : 50)), range(ylims..., length = (plot_type == :whole ? 200 : 50))));
            title, xlabel, ylabel, limits = (xlims, ylims), colorscale,
            colormap = :viridis, figsize = (620,400), watermark = false)
        Makie.lines!([l,l,r,r,l],[b,t,t,b,b], color = :red, linewidth = 3)
        Makie.lines!([2l-r,2r-l], report.drift_time_func.([2l-r,2r-l]), linewidth = 3, color = LegendMakie.BEGeOrange, label = "Linear fit")
    end
    Makie.axislegend(position = :lt, framevisible = true, framewidth = 1, framecolor = :lightgray)
    LegendMakie.add_watermarks!(; position = "outer top", final, kwargs...)
end


# SiPM
function LegendMakie.lplot!(
        report::NamedTuple{(:peakpos, :peakpos_cal, :h_uncal, :h_calsimple)};
        cal::Bool = true, title::AbstractString = "", yscale = Makie.log10,
        legend_position = :rt, final::Bool = !isempty(title), watermark::Bool = true, kwargs...
    )

    fig = Makie.current_figure()

    # select correct histogram
    h = LinearAlgebra.normalize(cal ? report.h_calsimple : report.h_uncal, mode = :density)

    # create main histogram plot
    ax = Makie.Axis(
        fig[1,1], 
        title = title, titlegap = 2,
        limits = (0, last(first(h.edges)), 0.99*minimum(filter(x -> x > 0, h.weights)), maximum(h.weights)*1.2),
        xticks = cal ? (0:0.5:last(first(h.edges))) : Makie.automatic,
        xlabel = "Peak Amplitudes ($(cal ? "P.E." : "ADC"))",
        ylabel = "Counts / $(round_wo_units(step(first(h.edges)), digits = 2)) $(cal ? "P.E." : "ADC")",
        yscale = yscale
    )

    Makie.stephist!(ax, StatsBase.midpoints(first(h.edges)), bins = first(h.edges), weights = h.weights, label = "Amps")
    Makie.vlines!(ax, cal ? report.peakpos_cal : report.peakpos, color = :red, label = "Peak Pos. Guess", linewidth = 1.5)
    legend_position != :none && Makie.axislegend(ax, framevisible = true, framewidth = 0, position = legend_position)

    # add watermarks
    Makie.current_axis!(ax)
    watermark && LegendMakie.add_watermarks!(; final, kwargs...)

    fig
end


# Dict of reports (vertical alignment)
function LegendMakie.lplot!(
        reports::Dict{<:Any, NamedTuple}; title::AbstractString = "", 
        watermark::Bool = true, final::Bool = true, kwargs...
    )

    fig = Makie.current_figure()

    isempty(reports) && throw(ArgumentError("Cannot plot empty dictionary."))
    
    for (i,(k,report)) in enumerate(reports)
        LegendMakie.lplot!(report, title = string(k), row = i, watermark = false; kwargs...)
    end

    # add general title
    if !isempty(title)
        Makie.Label(fig[1,:,Makie.Top()], title, padding = (0,0,35,0), fontsize = 24, font = :bold)
    end

    # add watermarks
    Makie.current_axis!(first(fig.content))
    watermark && LegendMakie.add_watermarks!(; final, kwargs...)

    fig
end

function LegendMakie.lplot!(h::StatsBase.Histogram{<:Real,1}; kwargs...)
    LegendMakie.lhist!(h; kwargs...)
end


# fallback method: use Makie.plot!
function LegendMakie.lplot!(args...; watermark::Bool = false, kwargs...)

    @info "No `LegendMakie` plot recipe found for this set of arguments. Using `Makie.plot!`"

    fig = Makie.current_figure()
    ax = isnothing(Makie.current_axis()) ? Makie.Axis(fig[1,1]) : Makie.current_axis()

    # use built-in method as fallback if existent, tweak appearance
    Makie.plot!(ax, args...; kwargs...)

    # add watermarks
    Makie.current_axis!(ax)
    watermark && LegendMakie.add_watermarks!(; kwargs...)

    fig
end