# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

"""
    const LegendTheme

Makie Theme based on the LEGEND-specific style guide.

"""
LegendTheme = missing
export LegendTheme

"""
    lplot(objs...)
    lplot!(objs...)

Plots `objs` via Makie in a LEGEND-specific form/style into a new plot.

"""
function lplot end
function lplot! end
export lplot, lplot!


"""
    lhist(values; bins = 100, kwargs...)
    lhist(x, y; bins = 100, kwargs...)
    lhist(histogram; kwargs...)
    lhist!(args...; kwargs...)

Plot a one- or two-dimensional histogram with the LEGEND style. `bins` may be a
bin count, explicit edges, or a pair of either for a two-dimensional histogram.

"""
function lhist end
function lhist! end
export lhist, lhist!

"""
    lgainstability(time, energy, pulser_energy; kwargs...)
    lgainstability!(time, energy, pulser_energy; kwargs...)

Plot the rolling gain variation of an energy estimator and a pulser reference.
"""
function lgainstability end
function lgainstability! end
export lgainstability, lgainstability!

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
function add_production! end