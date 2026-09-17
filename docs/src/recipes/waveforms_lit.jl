# # Waveforms and events
#
# `lplot` draws an `RDWaveform`, or several in one axis, and the waveforms of an event of
# `LegendData` at a timestamp.

using CairoMakie, LegendMakie
using RadiationDetectorSignals, Unitful
#md using Random; Random.seed!(42); nothing # hide

# ## Waveforms
#
# A waveform of a charge pulse on a noisy baseline.

t = range(0u"μs", 128u"μs", length = 1000)
pulse(t; t0 = 60u"μs", τ = 50u"μs") = t < t0 ? 0.0 : exp(-(t - t0) / τ)
wf = RDWaveform(t, 1000 .* pulse.(t) .+ 5 .* randn(length(t)))
lplot(wf, title = "A waveform")

# Several waveforms share the axis; the `label` of each fills a legend, and the time
# `xunit` and every other attribute of `lines` can be set.

wfs = ArrayOfRDWaveforms([RDWaveform(t, a .* pulse.(t) .+ 5 .* randn(length(t))) for a in (400, 800, 1200)])
lplot(wfs, label = ["400 ADC", "800 ADC", "1200 ADC"], xunit = u"ns", xlims = (0, 128_000), linewidth = 2)

# ## Events
#
# The waveforms of an event are read from the raw tier of a `LegendData` by their timestamp:
# every processable channel of a physics event, or the germanium detector of a calibration
# event. This page builds a raw tier of random waveforms for the test data of LegendTestData.

using LegendDataManagement, LegendHDF5IO, LegendTestData
using TypedTables, PropDicts, Dates

testdata_dir = joinpath(legend_test_data_path(), "data", "legend")
config = PropDicts.readprops(joinpath(testdata_dir, "julia-config.yaml"))
rawdir = mkpath(joinpath(mktempdir(), "docs-data")) # named after in the production tag of the plots
config.setups.l200.paths[Symbol("tier/raw")] = rawdir
PropDicts.writeprops(joinpath(rawdir, "config.json"), config)
ENV["LEGEND_DATA_CONFIG"] = joinpath(rawdir, "config.json")
l200 = LegendData(:l200);

# The event timestamps are looked up in the DAQ cycle keys of the runs, which `runinfo`
# reads from the metadata `datasets/filekeys`. The test data does not hold them, so the
# cycle keys of the run are registered by hand.

rinfo = l200.metadata.datasets.runinfo.p02.r006
fk_cal = FileKey(l200.name, DataPeriod(2), DataRun(6), DataCategory(:cal), Timestamp(rinfo.cal.start_key))
fk_phy = FileKey(l200.name, DataPeriod(2), DataRun(6), DataCategory(:phy), Timestamp(rinfo.phy.start_key))
LegendDataManagement._cached_runinfo_dataset[objectid(l200)] = DataSet([fk_cal, fk_phy], l200.dataset);

# One trigger per channel with the FlashCam `baseline` and `presum_rate` and both germanium
# waveform columns.

for fk in (fk_cal, fk_phy)
    raw_path = l200.tier[:raw, fk]
    mkpath(dirname(raw_path))
    chinfo = channelinfo(l200, fk, system = :geds)
    lh5open(raw_path, "w") do h
        for det in chinfo.detector
            h["raw/$det"] = Table(
                timestamp = [datetime2unix(DateTime(fk))u"s" + 100u"s"],
                baseline = [UInt16(14000)], presum_rate = [UInt16(8)],
                waveform_presummed = [RDWaveform(t, 8 .* (14000 .+ 1000 .* pulse.(t) .+ 5 .* randn(length(t))))],
                waveform_windowed = [RDWaveform(t[400:600], 14000 .+ 1000 .* pulse.(t[400:600]) .+ 5 .* randn(201))],
            )
        end
    end
end
t_cal = datetime2unix(DateTime(fk_cal))u"s" + 100u"s"
t_phy = datetime2unix(DateTime(fk_phy))u"s" + 100u"s";

# A physics event shows every processable channel of a `system` in a panel, colored by
# signal amplitude. Every waveform is drawn in the units of one ADC sample, a presummed
# waveform divided by its `presum_rate`, and the FlashCam baseline of the trigger is
# subtracted unless `subtract_baseline = false`. The test data holds germanium channels only.

lplot(l200, t_phy, system = :geds)

# The waveform columns of a system are given as a `Dict`; `xlims` defaults to the time
# range of the germanium waveforms.

lplot(l200, t_phy, system = Dict(:geds => [:waveform_presummed, :waveform_windowed]), subtract_baseline = false)

# The channels of a system are grouped by a column of `channelinfo`, by default the
# detector string, or the barrel of a SiPM. A `group` colors the channels by it, with a
# legend; `color` picks `:amplitude`, `:group` or `:channel` explicitly.

lplot(l200, t_phy, system = :geds, group = :cc4)

# `exploded` puts every group into its own panel, `ncols` of them per row, and `filterby`
# selects channels with a predicate on the rows of `channelinfo`.

lplot(l200, t_phy, system = :geds, exploded = true, ncols = 2, color = :channel, figsize = (800, 400))

# A single detector of an event, of a calibration or a physics run, with its channel in the
# legend.

lplot(l200, t_cal, :V99000A)

# A timestamp is also given as a `DateTime`.

lplot(l200, unix2datetime(ustrip(u"s", t_phy)), :V99000A, show_label = false)
