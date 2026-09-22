# # Energy calibration
#
# The steps of the energy calibration of a germanium detector with a ²²⁸Th source, from the
# uncalibrated energy spectrum to the resolution curve. The spectrum here is a
# random one: an exponential background with the three ²⁰⁸Tl peaks used for the calibration.

using CairoMakie, LegendMakie
using LegendSpecFits, Distributions, Unitful
#md using Random; Random.seed!(42) # hide

e_uncal = filter(x -> x <= 265_000, vcat(rand(Exponential(70_000), 97_000),
    261_450 .+ 200 .* randn(2_000), 210_350 .+ 185 .* randn(500), 159_300 .+ 170 .* randn(500)))
lines = [:Tl208DEP, :Tl208SEP, :Tl208FEP]
energies = [1592.513, 2103.512, 2614.511]u"keV";

# ## Peak search
#
# `autocal_energy` finds the calibration peaks in the uncalibrated spectrum; the report
# shows the spectrum with the peaks found and the calibration lines.

result_autocal, report_autocal = autocal_energy(e_uncal, energies, α = 0.01, rtol = 2)
lplot(report_autocal, energies, title = "Peak search")

# ## Simple calibration
#
# `simple_calibration` fits the peak positions with a line through zero and cuts the
# histograms around the peaks. The report shows the calibrated spectrum with the peak
# windows, or the uncalibrated one with `cal = false`.

result_simple, report_simple = simple_calibration(e_uncal, energies, [25, 25, 35]u"keV", [25, 25, 30]u"keV", calib_type = :th228)
lplot(report_simple, title = "Simple calibration")

#

lplot(report_simple, cal = false)

# ## Charge trapping correction
#
# `ctc_energy` corrects the energy for charge trapping with the effective drift time; the
# report shows the peak before and after the correction and the correlation with the drift
# time.

m_cal_simple = result_simple.c
qdrift = rand(length(e_uncal))
result_ctc, report_ctc = ctc_energy(e_uncal .* m_cal_simple, qdrift, 2614.5u"keV", (5u"keV", 5u"keV"), m_cal_simple)
lplot(report_ctc, figsize = (600, 600), title = "Charge trapping correction")

# ## Peak fits
#
# `fit_peaks` fits every calibration peak; the report holds one panel per peak, with the
# fit components and the residuals.

result_fit, report_fit = fit_peaks(result_simple.peakhists, result_simple.peakstats, lines;
    e_unit = result_simple.unit, calib_type = :th228, m_cal_simple)
lplot(report_fit, figsize = (600, 400 * length(report_fit)), title = "Peak fits")

# A single peak fit is drawn on its own, with `legend_position = :split` the data and the
# fit components in separate legends.

lplot(report_fit[:Tl208FEP], title = "Tl208FEP", legend_position = :split)

# ## Calibration curve
#
# `fit_calibration` fits the fitted peak positions against the literature energies. The
# errors are scaled to be visible; `additional_pts` marks peaks left out of the fit.

μ_fit = getfield.(getindex.(Ref(result_fit), lines), :centroid)
result_calib, report_calib = fit_calibration(1, μ_fit, energies)
lplot(report_calib, xerrscaling = 10, yerrscaling = 10, additional_pts = (μ = [100_000], peaks = [1000u"keV"]), title = "Calibration curve")

# ## Resolution curve
#
# `fit_fwhm` fits the resolution of the peaks as a function of the energy, and marks the
# resolution at Q_ββ.

f_cal_widths(x) = report_calib.f_fit(x) .* report_calib.e_unit .- first(report_calib.par)
fwhm_fit = f_cal_widths.(getfield.(getindex.(Ref(result_fit), lines), :fwhm))
result_fwhm, report_fwhm = fit_fwhm(1, energies, fwhm_fit, uncertainty = true)
lplot(report_fwhm, additional_pts = (peaks = [1000u"keV"], fwhm = [3.5u"keV"]), title = "Resolution curve")
