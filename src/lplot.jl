# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

"""
    const LegendTheme

Makie Theme based on the LEGEND-specific style guide.

"""
LegendTheme = missing
export LegendTheme

"""
    lplot(objs...)
    lplot!(fig, objs...)
    lplot!(objs...)

Plot `objs` in the LEGEND style. `lplot` creates a figure; `lplot!(fig, ...)`
uses the supplied figure. The form without a target uses the current figure
and is intended for interactive use. Pass explicit targets for concurrent tasks.

"""
function lplot end
function lplot! end
export lplot, lplot!


"""
    lhist(values; bins = 100, kwargs...)
    lhist(x, y; bins = 100, kwargs...)
    lhist(histogram; kwargs...)
    lhist!(fig, args...; kwargs...)
    lhist!(args...; kwargs...)

Plot a one- or two-dimensional histogram with the LEGEND style. `bins` may be a
bin count, explicit edges, or a pair of either for a two-dimensional histogram.
`lhist!(fig, ...)` plots into `fig`; without it, the current figure is used (interactive use only).

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
"""
    add_watermarks!(fig, ax; legend_logo = false, juleana_logo = true, show_date = true, position = "outer right",
        preliminary = true, approved = false, final = false, production = true)

Mark the figure `fig`: the Juleana logo, or the LEGEND logo with `legend_logo`, with the month
of the plot unless `show_date = false`, at `position` (`"outer right"` or `"outer top"`) of the
axis `ax`; the tag `PRELIMINARY`, or `INTERNAL USE ONLY` when `preliminary = false` and not
`approved`, and no tag when `final`; and, with `production` and the environment variable
`LEGEND_DATA_CONFIG` set, the name of the data production, the directory of its configuration
file. Every recipe calls it unless `watermark = false` and passes these keywords on.
Without `fig` and `ax`, the current figure and axis are used (interactive use only).
"""
function add_watermarks! end
function add_production! end