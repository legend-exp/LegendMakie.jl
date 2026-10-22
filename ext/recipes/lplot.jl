# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

# Interactive compatibility boundary: resolve the current figure once.
function LegendMakie.lplot!(args...; kwargs...)
    fig = Makie.current_figure()
    isnothing(fig) && error("There is no current figure to plot into.")
    LegendMakie.lplot!(fig, args...; kwargs...)
end

function LegendMakie.lplot!(fig::Makie.Figure, h::StatsBase.Histogram{<:Real,1}; kwargs...)
    LegendMakie.lhist!(fig, h; kwargs...)
end

# Fallback method: use the supplied figure's axis.
function LegendMakie.lplot!(fig::Makie.Figure, args...; watermark::Bool = false, kwargs...)
    @info "No `LegendMakie` plot recipe found for this set of arguments. Using `Makie.plot!`"
    ax = Makie.current_axis(fig)
    isnothing(ax) && (ax = Makie.Axis(fig[1,1]))
    Makie.plot!(ax, args...; kwargs...)
    Makie.current_axis!(fig, ax)
    watermark && LegendMakie.add_watermarks!(fig, ax; kwargs...)
    fig
end
