# # SiPM calibration
#
# The threshold and the photoelectron calibration of a SiPM channel, on a random amplitude
# spectrum of five photoelectron peaks over a background.

using CairoMakie, LegendMakie
using LegendSpecFits, Unitful
#md using Random; Random.seed!(42); nothing # hide

# ## Threshold
#
# `fit_sipm_threshold` fits the noise peak of the amplitudes; the report shows the fit and
# the threshold derived from it.

result_thres, report_thres = fit_sipm_threshold(randn(100_000), -5.0, 5.0)
lplot(report_thres, title = "SiPM threshold")

# ## Simple calibration
#
# `sipm_simple_calibration` finds the photoelectron peaks in the amplitude spectrum. The
# report shows the uncalibrated and the calibrated spectrum with the peaks and the noise
# cut.

e_uncal = vcat([randn(round(Int, exp10(6 - 0.5 * i))) .* 0.3 .+ i * 1.4 for i in 1:5]..., randn(10_000) .* 1.5 .+ 6)
result_simple, report_simple = sipm_simple_calibration(e_uncal, n_fwhm_noise_cut = 0.0)
lplot(report_simple, title = "SiPM peak search")

# ## Spectrum fit
#
# `fit_sipm_spectrum` fits the calibrated spectrum with a mixture of Gaussians; the report
# shows the mixture, its components, the peaks assigned to photoelectron numbers, and the
# residuals.

result_fit, report_fit = fit_sipm_spectrum(result_simple.pe_simple_cal, 0.5, 4.5, n_mixtures = 8, Δpe_peak_assignment = 0.5)
lplot(report_fit, xerrscaling = 5, title = "SiPM spectrum fit")

# ## Calibration curve
#
# The fitted peak positions against the photoelectron numbers.

result_calib, report_calib = fit_calibration(1, result_fit.positions, collect(result_fit.peaks) * u"eV/V")
lplot(report_calib, xerrscaling = 5, title = "SiPM calibration")
