# # PMT calibration
#
# The single-photoelectron (1 p.e.) fit of a photomultiplier, on a random pulse-height spectrum
# of a pedestal, its exponential tail and the 1 p.e. and 2 p.e. peaks, as in the LED
# calibration of the muon-veto PMTs.

using CairoMakie, LegendMakie
using LegendSpecFits
#md using Random; Random.seed!(42); nothing # hide

# ## 1 p.e. fit
#
# `fit_pmt_spe` fits the spectrum above the valley between pedestal and 1 p.e. peak with an
# exponential for the pedestal tail and the 1 p.e. and 2 p.e. peaks. The report shows the data,
# the fit and its components, the 1 p.e. position, the range below the fit start and the
# residuals.

μ1, σ1 = 15.0, 5.5
x = vcat(abs.(randn(150_000) .* 0.3 .+ 0.8), -3 .* log.(rand(20_000)),
         randn(15_000) .* σ1 .+ μ1, randn(1_500) .* (sqrt(2) * σ1) .+ 2μ1)
result, report = fit_pmt_spe(x)
lplot(report, title = "PMT 1 p.e. fit")

# The same report on a linear scale and without the residuals, as in an overview of many
# PMTs:

lplot(report, title = "PMT 1 p.e. fit", yscale = Makie.identity, show_residuals = false)
