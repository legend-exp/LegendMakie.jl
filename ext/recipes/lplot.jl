# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

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