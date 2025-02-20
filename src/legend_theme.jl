# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).


"""
    const LegendTheme

Makie Theme based on the LEGEND-specific style guide.

"""
const LegendTheme = Theme(
    Axis = (
        xlabelfont = :regular,
        ylabelfont = :regular,
        xticklabelfont = :regular, 
        yticklabelfont = :regular,
        titlegap = 1,
        titlesize = 15pt,
        xlabelsize = 15pt,
        ylabelsize = 15pt,
        xticklabelsize = 12pt,
        yticklabelsize = 12pt,
        xgridvisible = false,
        ygridvisible = false
    ),
    Scatter = (
        color = :black, # seems to be ignored, defaulting to palette colors
        markersize = 10,
        strokewidth = 0,
    ),
    Errorbars = (
        color = :black, # seems to be ignored, defaulting to palette colors
        whiskerwidth = 6,
    ),
    Lines = (
        linewidth   = 4,
        linecap     = :round,
        joinstyle   = :round
    ),
    Colorbar = (
        minorticksvisible = true,
    ),
    Legend = (
        framevisible = false, 
        labelsize = 12pt,
        patchsize = (20, 10), 
        patchlabelgap = 10, 
        rowgap = 10, 
        colgap = 20
    ),
    fonts = (
        bold        = joinpath(dirname(pathof(LegendMakie)), "fonts", LegendFont * "-Bold.ttf"),
        bold_italic = joinpath(dirname(pathof(LegendMakie)), "fonts", LegendFont * "-BoldItalic.ttf"),
        italic      = joinpath(dirname(pathof(LegendMakie)), "fonts", LegendFont * "-Italic.ttf"),
        regular     = joinpath(dirname(pathof(LegendMakie)), "fonts", LegendFont * "-Regular.ttf")
    ),
    palette = (
        color = [ICPCBlue, PPCPurple, BEGeOrange, CoaxGreen],
        patchcolor = [(ICPCBlue,0.6), (PPCPurple,0.6), (BEGeOrange,0.6), (CoaxGreen,0.6)],
    ),
    font = :regular,
    fontsize = 12pt,
    figure_padding = 21,
    size = (600,400)
)

export LegendTheme