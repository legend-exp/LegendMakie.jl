# # A/E pulse shape discrimination
#
# The correction, calibration and cut of the A/E parameter, on a random A/E distribution
# with the energy dependence of the mean and width of the Compton continuum.

using CairoMakie, LegendMakie
using LegendSpecFits, Distributions, StatsBase, Unitful
#md using Random; Random.seed!(42) # hide

e_cal = rand(Exponential(300), 2_000_000) .+ 300
μA, μB, σA, σB = 1.01, 4e-6, 5e-3, 12.0
aoe_μ(E) = μA - μB * E
aoe_σ(E) = sqrt(σA^2 + σB^2 / E^2)
aoe = [(rand() < 0.2 ? -rand(Exponential(5 * aoe_σ(E))) : 0) + aoe_σ(E) * randn() + aoe_μ(E) for E in e_cal];

# ## A/E versus energy
#
# The two-dimensional histogram of A/E against the energy, with `lhist`.

h_aoe = fit(Histogram, (e_cal, aoe), (0:2:3000, 0.9:2e-3:1.1))
lhist(h_aoe, rasterize = true, xlabel = "Energy (keV)", ylabel = "A/E", title = "A/E vs. energy")

# ## Compton band fits
#
# The A/E distribution of every Compton band is fit with a Gaussian and a low tail;
# `fit_aoe_compton` reports one fit per band.

compton_bands = collect((550:50:2350)u"keV")
compton_window = 20u"keV"
peakhists = generate_aoe_compton_bands(aoe, e_cal * u"keV", compton_bands, compton_window)
result_bands, report_bands = fit_aoe_compton(peakhists.peakhists, peakhists.peakstats, compton_bands, uncertainty = true)
lplot(report_bands[first(compton_bands)], title = "A/E of the $(first(compton_bands)) Compton band")

# ## Energy dependence
#
# `fit_aoe_corrections` fits the mean and the width of the Compton bands as functions of
# the energy. The two reports are drawn side by side with `col`.

μs = [result_bands[band].μ for band in compton_bands]
σs = [result_bands[band].σ for band in compton_bands]
result_corr, report_corr = fit_aoe_corrections(compton_bands, μs, σs)
fig = lplot(report_corr.report_μ, col = 1, figsize = (1200, 420))
lplot!(report_corr.report_σ, col = 2)
fig

# `fit_aoe_compton_combined` fits every band at once with the energy dependence as the
# model; its report is drawn over the one of the single fits.

result_comb, report_comb = fit_aoe_compton_combined(peakhists.peakhists, peakhists.peakstats, compton_bands, result_corr, uncertainty = true)
fig = lplot(report_corr.report_μ, report_comb.report_μ, col = 1, figsize = (1200, 420))
lplot!(report_corr.report_σ, report_comb.report_σ, col = 2)
fig

# ## Charge trapping correction
#
# `ctc_aoe` corrects the corrected A/E for its dependence on the effective drift time in a
# peak; the report shows A/E before and after the correction against the drift time.
# `norm = true` shows the normalized A/E.

E0 = 550u"keV"
e_peak = fill(E0, 100_000)
aoe_corr = clamp.(vcat(-rand(Exponential(5.0), 20_000), zeros(80_000)) .+ randn(100_000), -49.0, 7.0)
qdrift_e = max.(0, randn(100_000) .+ 5)
aoe_corr .-= qdrift_e .* 0.1
aoe_corr .-= median(aoe_corr)
result_ctc, report_ctc = ctc_aoe(aoe_corr, e_peak, qdrift_e, [E0 - 10u"keV"])
lplot(report_ctc, figsize = (600, 600), title = "A/E charge trapping correction")

# ## Cut value
#
# `get_low_aoe_cut` finds the low A/E cut from the survival fraction of the double-escape
# peak; the report shows the A/E histogram with the cut.

aoe_cut = vcat(randn(50_000), randn(950_000) .- 3)
e_dep = vcat(randn(10_000) .+ 1593, rand(Exponential(2000), 990_000)) * u"keV"
result_cut, report_cut = get_low_aoe_cut(aoe_cut, e_dep)
lplot(report_cut, figsize = (750, 400), title = "Low A/E cut")

# ## Survival fractions
#
# `get_peaks_survival_fractions` reports the energy spectrum of every peak before and after
# the cut, with the survival fraction. A single peak is drawn on its own, or all of them
# as a grid.

aoe_sf = vcat(randn(30_000), randn(70_000) .- 10)
e_sf = 1.5u"keV" .* randn(100_000) .+ 2614.5u"keV"
result_sf, report_sf = get_peaks_survival_fractions(aoe_sf, e_sf, [2614.5u"keV"], [:Tl208FEP], [(35.0u"keV", 35.0u"keV")], -5.0)
lplot(report_sf[:Tl208FEP], sf_in_title = true, title = "Survival fraction")

#

lplot(report_sf, title = "Survival fractions")
