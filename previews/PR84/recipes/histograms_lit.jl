# # Histograms
#
# `lhist` draws a histogram in the LEGEND style: from values, from `x` and `y` values as a
# two-dimensional histogram, or from a `StatsBase.Histogram`. `lplot` of a one-dimensional
# histogram is the same as `lhist`.

using CairoMakie, LegendMakie
using Distributions, StatsBase
#md using Random; Random.seed!(42); nothing # hide

# ## Values
#
# `bins` is the number of bins or the bin edges.

values = vcat(randn(10_000), 3 .+ 0.5 .* randn(2_000))
lhist(values, bins = -5:0.1:5, xlabel = "Value", ylabel = "Counts", title = "Histogram of values")

# The axes can be logarithmic; logarithmic bin edges suit a logarithmic x axis.

energy = rand(Exponential(300), 100_000)
lhist(energy, bins = 10.0 .^ range(0, 4, length = 41), xlabel = "Energy (ADC)", ylabel = "Counts",
    xscale = log10, yscale = log10, title = "Energy distribution")

# A `StatsBase.Histogram` is drawn the same way, with `lhist` or `lplot`. Given a `label`,
# it appears in a legend.

h = fit(Histogram, values, -5:0.1:5)
lplot(h, label = "Data", xlabel = "Value", ylabel = "Counts", fill = true)

# ## Two dimensions
#
# `x` and `y` values give a two-dimensional histogram with a logarithmic color scale, as do
# `bins` per dimension. Time series of a parameter are shown this way.

time = repeat(0:99, inner = 100)
baseline = 2 .* randn(10_000) .+ 0.01 .* time
lhist(time, baseline, bins = (100, 50), xlabel = "Time (h)", ylabel = "Baseline (ADC)", title = "Baseline stability")

# A two-dimensional `StatsBase.Histogram` of many bins is best rasterized in vector formats.

h2 = fit(Histogram, (rand(100_000), randn(100_000)), (0:0.01:1, -4:0.05:4))
lhist(h2, rasterize = true, xlabel = "x", ylabel = "y", colorbarlabel = "Counts")
