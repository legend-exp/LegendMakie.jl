# # LQ pulse shape discrimination
#
# The drift time correction, normalization and cut of the LQ parameter, on a random energy
# spectrum with a Cauchy-distributed LQ that drifts with the effective drift time.

using CairoMakie, LegendMakie
using LegendSpecFits, Distributions, Unitful
#md using Random; Random.seed!(42) # hide

e_cal = filter(x -> x <= 2650u"keV", vcat(rand(Exponential(700), 97_000)u"keV",
    2614.5u"keV" .+ 2u"keV" .* randn(2_000), 2103.5u"keV" .+ 1.85u"keV" .* randn(500), 1593.5u"keV" .+ 1.7u"keV" .* randn(500)))
dt_eff = rand(length(e_cal)) * 10 .+ 3
lq_e_corr = filter(x -> -20 < x < 20, clamp.(rand(Cauchy(1.0, 0.5), 2 * length(e_cal)), -20, 20))[eachindex(e_cal)] .+ dt_eff .* 0.01;

# ## Drift time correction
#
# `lq_ctc_correction` fits the dependence of LQ on the drift time in the double-escape
# peak. The report is drawn with the values it was made from, for the whole spectrum or
# for the double-escape peak only.

drift_result, drift_report = lq_ctc_correction(lq_e_corr, dt_eff, e_cal, 1593.5u"keV", 1.5u"keV")
lplot(drift_report, e_cal, dt_eff, lq_e_corr, :whole, title = "LQ drift time correction", figsize = (620, 400))

#

lplot(drift_report, e_cal, dt_eff, lq_e_corr, :DEP, title = "LQ in the double-escape peak", figsize = (620, 400))

# ## Normalization
#
# `lq_norm` normalizes LQ to the width of its distribution in the double-escape peak, with
# the sidebands subtracted. The report holds the histograms of the peak and the sidebands
# and the width of the peak in energy.

result, report = lq_norm(1593.5u"keV", 1.5u"keV", e_cal, lq_e_corr)
lplot(report.temp_hists, title = "LQ sideband subtraction")

#

lplot((; e_cal, edges = report.edges, dep_σ = report.dep_σ), title = "Double-escape peak")

# ## Cut
#
# The LQ classifier against the energy with the cut value.

lplot((; e_cal, lq_class = lq_e_corr, cut_value = 3.0), figsize = (750, 400), title = "LQ cut")
