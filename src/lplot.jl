# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).


"""
    lplot(objs...)
    lplot!(objs...)

Plots `objs` via Makie in a LEGEND-specific form/style into a new plot.

"""
function lplot end
function lplot! end
export lplot, lplot!


# recipes
function residualplot! end

# watermark functions
function add_logo! end
function add_legend_logo! end
function add_juleana_logo! end
function add_text! end
function add_watermarks! end