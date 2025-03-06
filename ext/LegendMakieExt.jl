# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

module LegendMakieExt

    import LegendMakie

    import Dates
    import FileIO
    import Format
    import KernelDensity
    import LaTeXStrings
    import LinearAlgebra
    import Makie
    import MathTeXEngine
    import StatsBase
    import Unitful
    
    import LegendMakie: pt
    import Unitful: @u_str

    include("recipes/recipes.jl")
    include("recipes/lplot.jl")
    include("recipes/lhist.jl")
    include("recipes/watermarks.jl")

    function __init__()
        # maybe just use with_theme() in every plot recipe?
        @debug "Updating Makie theme to LEGEND theme"
        Makie.update_theme!(LegendMakie.LegendTheme)

        # add Roboto as possible LaTeXString font
        MathTeXEngine.default_font_families["Roboto"] = MathTeXEngine.FontFamily(
            Dict(
                :regular    => joinpath(dirname(pathof(LegendMakie)), "fonts", "Roboto-Regular.ttf"),
                :italic     => joinpath(dirname(pathof(LegendMakie)), "fonts", "Roboto-Italic.ttf"),
                :bold       => joinpath(dirname(pathof(LegendMakie)), "fonts", "Roboto-Bold.ttf"),
                :bolditalic => joinpath(dirname(pathof(LegendMakie)), "fonts", "Roboto-BoldItalic.ttf"),
                :math       => MathTeXEngine.default_font_families["NewComputerModern"].fonts[:math]
            ), special_chars = MathTeXEngine._symbol_to_new_computer_modern
        )
    end

    function LegendMakie.lplot(args...; figsize = Makie.theme(:size), kwargs...)
        # create new Figure
        fig = Makie.Figure(size = figsize)
        LegendMakie.lplot!(args...; kwargs...)
        fig
    end

    function LegendMakie.lhist(args...; figsize = Makie.theme(:size), kwargs...)
        # create new Figure
        fig = Makie.Figure(size = figsize)
        LegendMakie.lhist!(args...; kwargs...)
        fig
    end

    function LegendMakie.lsavefig(name::AbstractString; kwargs...)
        fig = Makie.current_figure()
        isnothing(fig) && throw(MethodError("No figure to save to file."))
        LegendMakie.lsavefig(fig, name; kwargs...)
    end

    function LegendMakie.lsavefig(fig::Makie.Figure, name::AbstractString; kwargs...)
        FileIO.save(name, fig; kwargs...)
    end
end