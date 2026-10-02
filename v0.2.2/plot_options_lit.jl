# # Plot options
#
# The recipes of `LegendMakie` share the keyword arguments of this page. `lplot` and `lhist`
# open a new figure and draw into it; `lplot!` and `lhist!` draw into the current figure.

using CairoMakie, LegendMakie
#md using Random; Random.seed!(42); nothing # hide

# ## Figure
#
# `figsize` is the size of the figure in pixels, by default the size of the LEGEND theme, and
# `title` its title. `lsavefig` saves the current figure, or the figure given, in the format
# of the file name.

lhist(randn(10_000), bins = -4:0.1:4, xlabel = "x", title = "A title", figsize = (500, 300))

# ## Watermarks
#
# Every recipe marks its figure with [`LegendMakie.add_watermarks!`](@ref) unless `watermark = false`.
# A figure is marked `PRELIMINARY` until `final = true`; most recipes take a figure with a
# `title` as final.

lhist(randn(10_000), bins = -4:0.1:4, xlabel = "x", final = true)

# `legend_logo = true` draws the LEGEND logo instead of the Juleana one, `show_date = false`
# leaves out the month of the plot, and `position = "outer top"` puts the logo above the
# axis instead of beside it.

lhist(randn(10_000), bins = -4:0.1:4, xlabel = "x", legend_logo = true, show_date = false, position = "outer top")

# A figure that is neither preliminary nor final is `INTERNAL USE ONLY`, unless it is
# `approved`.

lhist(randn(10_000), bins = -4:0.1:4, xlabel = "x", preliminary = false)

# ## Production
#
# With the environment variable `LEGEND_DATA_CONFIG` set, the name of the data production,
# the directory of its configuration file, is written into the corner of the figure;
# `production = false` leaves it out.

ENV["LEGEND_DATA_CONFIG"] = joinpath(mkpath(joinpath(mktempdir(), "ref-v1.0.0")), "config.json")
lhist(randn(10_000), bins = -4:0.1:4, xlabel = "x")

#

lhist(randn(10_000), bins = -4:0.1:4, xlabel = "x", production = false)
