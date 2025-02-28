# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

function LegendMakie.lhist!(
    h::StatsBase.Histogram{<:Any, 2};
    watermark::Bool = true, rasterize::Bool = false, 
    position::String = "outer top", final::Bool = true,
    colormap::Symbol = :magma, colorscale = Makie.log10, 
    title::AbstractString = "", xlabel = "", ylabel = "", 
    xticks = Makie.automatic, yticks = Makie.automatic,
    xlims = extrema(first(h.edges)), ylims = extrema(last(h.edges)),
    kwargs...
)

    fig = Makie.current_figure()
    g = Makie.GridLayout(fig[1,1])

    #create plot
    ax = Makie.Axis(g[1,1],
        title = title,
        titlesize = 18,
        titlegap = 2,
        titlealign = :right,
        limits = (xlims, ylims);
        xlabel, ylabel, xticks, yticks
    )

    hm = Makie.heatmap!(ax, h.edges..., replace(h.weights, 0 => NaN); colormap, colorscale)
    hm.rasterize = rasterize
    cb = Makie.Colorbar(g[1,2], hm, 
        tickformat = values -> Makie.rich.("10", Makie.superscript.(string.(Int.(log10.(values))))),
        ticks = exp10.(0:ceil(maximum(log10.(h.weights))))
    )

    # add watermarks
    Makie.current_axis!(ax)
    watermark && LegendMakie.add_watermarks!(; position, final, kwargs...)

    fig
end
