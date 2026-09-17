# # Fits, cuts and filter optimization
#
# The reports of [LegendSpecFits](https://github.com/legend-exp/LegendSpecFits.jl) are
# drawn by `lplot`: the fit of a distribution, the cuts derived from it, and the scans of
# the DSP filter optimization.

using CairoMakie, LegendMakie
using LegendSpecFits, Measurements, Unitful
using TypedTables, PropDicts
#md using Random; Random.seed!(42); nothing # hide

# ## Truncated Gaussian fit
#
# The fit of a truncated Gaussian to values, with the residuals of the fit.

x = 2.0 .+ 0.5 .* randn(10_000)
result, report = fit_single_trunc_gauss(x, (low = 0.0, high = 4.0, max = NaN))
lplot(report, xlabel = "x", title = "Truncated Gaussian fit")

# ## Window cuts
#
# A centered window cut keeps the values within a number of standard deviations of a
# Gaussian fit; the cut is drawn on the histogram.

result, report = get_centered_gaussian_window_cut(x, 0.0, 4.0, 3.0, n_bins = -1)
lplot(report, xlabel = "x", title = "Window cut")

# The quality cuts of several parameters of a table are fit at once; the report holds one
# panel per parameter.

t = Table(baseline_slope = randn(100_000), baseline_std = 3.0 .+ randn(100_000))
config = PropDict(
    :baseline_slope => PropDict(:min => -10.0, :max => 10.0, :sigma => 2.0,
        :kwargs => PropDict(:relative_cut => 0.01, :n_bins => -1, :fixed_center => false, :left => false)),
    :baseline_std => PropDict(:min => -10.0, :max => 20.0, :sigma => 2.0,
        :kwargs => PropDict(:relative_cut => 0.01, :n_bins => -1, :fixed_center => false, :left => true)),
)
result, report = qc_window_cut(t, config)
lplot(report, figsize = (600, 700), title = "Quality cuts")

# ## Filter optimization
#
# The scans of a filter parameter are reported as a grid and the figure of merit at each
# point, with the minimum marked. The noise as a function of the rise time of the trapezoidal
# filter:

enc_grid_rt = (1.5:0.5:16.0)u"μs"
enc = measurement.(1.0 .+ 0.02 .* (ustrip.(enc_grid_rt) .- 8).^2 .+ 0.1 .* rand(length(enc_grid_rt)), 0.05)
min_enc, idx = findmin(enc)
rt = measurement(enc_grid_rt[idx], step(enc_grid_rt))
lplot((; rt, min_enc, enc_grid_rt, enc), title = "ENC noise")

# The energy resolution as a function of the flat-top time:

e_grid_ft = (0.5:0.25:5.0)u"μs"
fwhm = measurement.(2.5 .+ 0.3 .* (ustrip.(e_grid_ft) .- 2.5).^2 .+ 0.1 .* rand(length(e_grid_ft)), NaN)u"keV"
min_fwhm, idx = findmin(fwhm)
ft = measurement(e_grid_ft[idx], step(e_grid_ft))
lplot((; ft, min_fwhm, e_grid_ft, fwhm), title = "FWHM")

# The survival fraction of the single-escape peak as a function of the window length of the
# Savitzky-Golay filter of the current:

a_grid_wl_sg = (30:32.0:350)u"ns"
sfs = measurement.(10 .+ 0.001 .* (ustrip.(a_grid_wl_sg) .- 150).^2 .+ rand(length(a_grid_wl_sg)), NaN) .* u"percent"
min_sf, idx = findmin(sfs)
wl = measurement(a_grid_wl_sg[idx], step(a_grid_wl_sg))
lplot((; wl, min_sf, a_grid_wl_sg, sfs), title = "A/E filter")

# The objective of the SiPM filter optimization as a function of the window length:

a_grid_wl_sg = (1.5:0.5:16.0)u"μs"
obj = measurement.(0.5 .+ 0.01 .* (ustrip.(a_grid_wl_sg) .- 6).^2 .+ 0.05 .* rand(length(a_grid_wl_sg)), 0.03)
min_obj, idx = findmin(obj)
wl = measurement(a_grid_wl_sg[idx], step(a_grid_wl_sg))
lplot((; wl, min_obj, gain = missing, res_1pe = missing, pos_1pe = missing, threshold = missing,
    a_grid_wl_sg, obj, report_simple = missing, report_fit = missing), title = "SiPM filter")
