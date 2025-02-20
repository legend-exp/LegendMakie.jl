# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).


function round_wo_units(x::Unitful.RealOrRealQuantity; digits::Int=2)
    Unitful.unit(x) == Unitful.NoUnits ? round(x; digits) : round(Unitful.unit(x), x; digits)
end

function LegendMakie.lplot!(
        report::NamedTuple{(:f_fit, :h, :μ, :σ, :gof)};
        title::AbstractString = "", show_residuals::Bool = true,
        xlabel = "", xticks = -4:2:4, xlims = (-5,5), ylims = (0,nothing),
        legend_position = :lt, watermark::Bool = true, kwargs...
    )

    fig = Makie.current_figure()
    
    g = Makie.GridLayout(fig[1,1])
    ax = Makie.Axis(g[1,1], 
        title = title, titlefont = :bold, titlesize = 16pt, xlabel = xlabel,
        xticks = xticks, limits = (xlims, ylims), ylabel = "Normalized Counts",
    )
    
    # Create histogram
    Makie.plot!(ax, report.h, label = "Data")
    
    _x = range(minimum(xlims), stop = maximum(xlims), length = 1000)
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

    all = Makie.Axis(g[:,:])
    Makie.hidedecorations!(all)
    Makie.hidespines!(all)
    Makie.current_axis!(all)
    
    watermark && LegendMakie.add_watermarks!(; kwargs...)
    
    fig
end


function LegendMakie.lplot!(
        report::NamedTuple{(:v, :h, :f_fit, :f_components, :gof)};
        xlabel = "", ylabel = "Counts / bin",
        title::AbstractString = "", legend_position = :lt,
        xlims = extrema(first(report.h.edges)), ylims = (0.9,maximum(report.h.weights) * 2),
        show_label::Bool = true, show_components::Bool = true, yticks = Makie.automatic,
        watermark::Bool = true, show_residuals::Bool = true, col::Int = 1, kwargs...
    )

    fig = Makie.current_figure()

    # create plot
    g = Makie.GridLayout(fig[1,col])
    ax = Makie.Axis(g[1,1], 
        title = title, titlefont = :bold, titlesize = 16pt, 
        xlabel = xlabel, ylabel = ylabel, yticks = yticks,
        limits = (xlims, ylims),
        yscale = Makie.log10
    )

    Makie.hist!(ax, StatsBase.midpoints(first(report.h.edges)), weights = report.h.weights, bins = first(report.h.edges), color = LegendMakie.DiamondGrey, label = "Data")
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

    all = Makie.Axis(g[:,:])
    Makie.hidedecorations!(all)
    Makie.hidespines!(all)
    Makie.current_axis!(all)

    # add watermarks
    watermark && LegendMakie.add_watermarks!(; kwargs...)

    fig
end


function LegendMakie.lplot!( 
        report::NamedTuple{(:par, :f_fit, :x, :y, :gof, :e_unit, :label_y, :label_fit)}; 
        title::AbstractString = "", show_residuals::Bool = true,
        xticks = 500:250:2250, xlims = (500,2300), ylims = nothing,
        legend_position = :rt, col = 1, watermark::Bool = false, kwargs...
    )

    fig = Makie.current_figure()

    # create plot
    g = Makie.GridLayout(fig[1,col])
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

    all = Makie.Axis(g[:,:])
    Makie.hidedecorations!(all)
    Makie.hidespines!(all)
    Makie.current_axis!(all)

    # add watermarks
    watermark && LegendMakie.add_watermarks!(; kwargs...)

    fig 
end


function LegendMakie.lplot!( 
        report::NamedTuple{(:par, :f_fit, :x, :y, :gof, :e_unit, :label_y, :label_fit)},
        com_report::NamedTuple{(:values, :label_y, :label_fit, :energy)};
        legend_position = :rt, col = 1, kwargs...
    )

    fig = LegendMakie.lplot!(report, legend_position = :none, col = col; kwargs...)

    g = last(Makie.contents(fig[1,col]))
    ax = Makie.contents(g)[1]
    Makie.lines!(ax, com_report.energy, com_report.values, linewidth = 4, color = :red, linestyle = :dash, label = LaTeXStrings.latexstring("\\fontfamily{Roboto}" * com_report.label_fit))
    Makie.axislegend(ax, position = legend_position)

    fig
end