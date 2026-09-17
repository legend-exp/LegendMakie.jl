# # Parameters per detector
#
# `lplot` of a `channelinfo` table and a `PropDict` of parameters draws one parameter per
# detector, ordered by string and position, with its uncertainty. This page uses the
# metadata of LegendTestData.

using CairoMakie, LegendMakie
using LegendDataManagement, LegendTestData
using PropDicts, Measurements, Unitful
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
