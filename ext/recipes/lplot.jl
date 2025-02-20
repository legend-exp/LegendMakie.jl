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