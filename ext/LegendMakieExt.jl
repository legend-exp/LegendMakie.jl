# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

module LegendMakieExt

    import Makie

    import LegendMakie


    function __init__()
        # maybe just use with_theme() in every plot recipe?
        @debug "Updating Makie theme to LEGEND theme"
        Makie.update_theme!(LegendMakie.LegendTheme)
    end

    function LegendMakie.lplot(args...; figsize = Makie.theme(:size), kwargs...)
        # create new Figure
        fig = Makie.Figure(size = figsize)
        LegendMakie.lplot!(args...; kwargs...)
        fig
    end

end