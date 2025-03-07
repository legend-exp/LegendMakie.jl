# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

import LegendMakie: residualplot!

Makie.@recipe(ResidualPlot, report) do scene
    Makie.Attributes(
        color_1σ = :darkgrey,
        color_3σ = :lightgrey,
        color = :black,
        markersize = 8
    )
end

function Makie.plot!(p::ResidualPlot{<:Tuple{NamedTuple{(:x, :residuals_norm)}}})
    report = p.report[]
    xvalues = report.x
    res = report.residuals_norm
    Makie.hspan!(p, [-3], [3], color = p.color_3σ)
    Makie.hspan!(p, [-1], [1], color = p.color_1σ)
    Makie.scatter!(p, xvalues, res, color = p.color, markersize = p.markersize)
    p
end