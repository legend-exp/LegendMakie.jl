# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).


"""
    lplot(objs...)
    lplot!(objs...)

Plots `objs` via Makie in a LEGEND-specific form/style into a new plot.

"""
function lplot end
function lplot! end
export lplot, lplot!


"""
    lplot(objs...)
    lplot!(objs...)

Plots `objs` via Makie in a LEGEND-specific form/style into a new histogram.

"""
function lhist end
function lhist! end
export lhist, lhist!


"""
    lsavefig(filename)

Saves the current figure to a file with a given `filename`.

"""
function lsavefig end
export lsavefig


# recipes
function residualplot! end
function energycalibrationplot! end
function aoecorrectionplot! end
function parameterplot! end
function waveformplot! end

# watermark functions
function add_logo! end
function add_legend_logo! end
function add_juleana_logo! end
function add_text! end
function add_watermarks! end