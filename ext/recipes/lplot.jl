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
        legend_position = :lt, watermark::Bool = true, final::Bool = (title != ""), kwargs...
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
    
    Makie.axislegend(ax, position = legend_position)
    
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
        watermark::Bool = true, final::Bool = (title != ""),
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
        report::NamedTuple{(:h_calsimple, :h_uncal, :c, :fep_guess, :peakhists, :peakstats)};
        cal::Bool = true, title::AbstractString = "", yscale = Makie.log10, 
        final::Bool = (title != ""), watermark::Bool = true, kwargs...
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
        watermark::Bool = false, final::Bool = (title != ""), kwargs...
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
    if title != ""
        Makie.Label(g[1,:,Makie.Top()], title, padding = (0,0,2,0), fontsize = 20, font = :bold)
    end
    
    # add watermarks
    Makie.current_axis!(ax3)
    watermark && LegendMakie.add_watermarks!(; kwargs...)
    
    fig
end


# Dict of reports (vertical alignment)
function LegendMakie.lplot!(
        reports::Dict{Symbol, NamedTuple}; title::AbstractString = "", 
        watermark::Bool = true, final::Bool = true, kwargs...
    )

    fig = Makie.current_figure()

    isempty(reports) && throw(ArgumentError("Cannot plot empty dictionary."))
    
    for (i,(k,report)) in enumerate(reports)
        LegendMakie.lplot!(report, title = string(k), row = i, watermark = false; kwargs...)
    end

    # add general title
    if title != ""
        Makie.Label(fig[1,:,Makie.Top()], title, padding = (0,0,35,0), fontsize = 24, font = :bold)
    end

    # add watermarks
    Makie.current_axis!(first(fig.content))
    watermark && LegendMakie.add_watermarks!(; final, kwargs...)

    fig
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