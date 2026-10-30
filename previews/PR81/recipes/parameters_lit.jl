# # Parameters per detector
#
# `lplot` of a `channelinfo` table and a `PropDict` of parameters draws one parameter per
# detector, ordered by string and position, with its uncertainty. This page uses the
# metadata of LegendTestData.

using CairoMakie, LegendMakie
using LegendDataManagement, LegendTestData
using PropDicts, Measurements, Unitful
using TypedTables
using LegendDataTypes, RadiationDetectorSignals # the recipes of LegendData load with the waveform types they read
#md using Random; Random.seed!(42) # hide

testdata_dir = joinpath(legend_test_data_path(), "data", "legend")
config = PropDict(:setups => PropDict(:l200 => PropDicts.readprops(joinpath(testdata_dir, "dataflow-config.yaml"))))
configfile = joinpath(mktempdir(), "config.json")
PropDicts.writeprops(configfile, config)
ENV["LEGEND_DATA_CONFIG"] = configfile
l200 = LegendData(:l200);

# The channels of a run are read from the metadata with `channelinfo` at the start key of
# the run.

filekey = start_filekey(l200, :p02, :r000, :cal)
chinfo = channelinfo(l200, filekey, system = :geds)

# A parameter is a `PropDict` keyed by detector; nested properties are picked by a vector
# of their names, here the mass of the detectors from the hardware metadata.

diodes = l200.metadata.hardware.detectors.germanium.diodes
masses = PropDict(Dict(Symbol(det.name) => det.production.mass_in_g * u"g" for det in diodes))
lplot(chinfo, masses, ylabel = "Mass (g)", title = "Detector masses")

# A measured parameter with uncertainties, and a detector without an entry, which is marked
# in red on the axis.

resolution = PropDict(Dict(Symbol(det) => PropDict(:fwhm => measurement(2.5 + 0.3 * randn(), 0.1)u"keV") for det in chinfo.detector))
delete!(resolution, Symbol(first(chinfo.detector)))
lplot(chinfo, resolution, [:fwhm], ylabel = "FWHM at Qββ (keV)", title = "Resolution")

# ## Detector status colors
#
# Set `detector_status_colors = true` to color detector names by the `usability` column:
# black for `:on`, golden yellow for `:ac`, and red for `:off`. A missing parameter gets a
# thin red vertical line while its detector name keeps its status color. String names and
# string separation lines keep their usual colors. The option is off by default.
#
# The test metadata above contains only `:on` detectors, so this small illustrative table
# shows all three statuses and a missing value.

status_chinfo = Table(detector = [:D01, :D02, :D03, :D04],
    detstring = [1, 1, 1, 1], position = [1, 2, 3, 4],
    usability = [:on, :ac, :off, :on])
status_resolution = PropDict(Dict(
    :D01 => PropDict(:fwhm => measurement(2.3, 0.1)),
    :D02 => PropDict(:fwhm => measurement(2.6, 0.1)),
    :D03 => PropDict(:fwhm => measurement(2.8, 0.1)),
))
lplot(status_chinfo, status_resolution, [:fwhm]; detector_status_colors = true,
    figsize = (850, 450), ylabel = "FWHM at Qββ (keV)", watermark = false)
