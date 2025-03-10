# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

function LegendMakie.lhist!(
    h::StatsBase.Histogram{<:Any, 2};
    watermark::Bool = true, rasterize::Bool = false, 
    position::String = "outer top", final::Bool = true,
    colormap::Symbol = :magma, colorscale = Makie.log10, 
    title::AbstractString = "", titlesize = 18, titlegap = 2, titlealign = :right,
    xlabel = "", ylabel = "", xlims = extrema(first(h.edges)), ylims = extrema(last(h.edges)),
    xticks = Makie.WilkinsonTicks(6,k_min=5), yticks = Makie.WilkinsonTicks(6,k_min=4),
    kwargs...
)

    fig = Makie.current_figure()
    g = Makie.GridLayout(fig[1,1])

    #create plot
    ax = Makie.Axis(g[1,1],
        limits = (xlims, ylims);
        title, titlegap, titlesize, titlealign, xlabel, ylabel, xticks, yticks
    )

    hm = Makie.heatmap!(ax, h.edges..., replace(h.weights, 0 => NaN); colormap, colorscale)
    hm.rasterize = rasterize
    cb = if colorscale == Makie.log10
        Makie.Colorbar(g[1,2], hm, 
            tickformat = values -> Makie.rich.("10", Makie.superscript.(string.(Int.(log10.(values))))),
            ticks = exp10.(0:ceil(maximum(log10.(h.weights)))))
    else
        Makie.Colorbar(g[1,2], hm, minorticksvisible = false)
    end

    # add watermarks
    Makie.current_axis!(ax)
    watermark && LegendMakie.add_watermarks!(; position, final, kwargs...)

    fig
end

function LegendMakie.lhist!(
        h::StatsBase.Histogram{<:Any, 1}; 
        title::AbstractString = "", titlesize = 18, titlegap = 2,
        xlabel = "", ylabel = "", label = nothing, yscale = Makie.identity,
        xlims = extrema(first(h.edges)), xticks = Makie.WilkinsonTicks(6,k_min=5), 
        yticks = yscale == Makie.log10 ? Makie.LogTicks(Makie.WilkinsonTicks(5, k_min = 3)) : Makie.WilkinsonTicks(6, k_min=4), 
        ylims = (yscale == Makie.log10 ? 0.9 : 0, maximum(h.weights)*1.2),
        fill::Bool = false, color = LegendMakie.AchatBlue, linewidth = 2, legend_position = :rt,
        watermark::Bool = true, final::Bool = !isempty(title), kwargs...
    )

    fig = Makie.current_figure()

    #create plot
    ax = if isnothing(Makie.current_axis())
        Makie.Axis(fig[1,1],
            limits = (xlims, ylims);
            title, titlesize, titlegap, xlabel, ylabel, xticks, yticks, yscale
        )
    else
        Makie.current_axis()
    end


    fill && Makie.hist!(ax, StatsBase.midpoints(first(h.edges)), weights = replace(h.weights, 0 => (yscale == Makie.log10 ? 1e-10 : 0)), bins = first(h.edges), color = (color, 0.5))
    Makie.stephist!(ax, StatsBase.midpoints(first(h.edges)), weights = replace(h.weights, 0 => (yscale == Makie.log10 ? 1e-10 : 0)), bins = first(h.edges); label, color, linewidth)
    if legend_position != :none && !isnothing(label)
        Makie.axislegend(ax, position = legend_position)
    end
    Makie.current_axis!(ax)
    watermark && LegendMakie.add_watermarks!(; final, kwargs...)

    fig
end