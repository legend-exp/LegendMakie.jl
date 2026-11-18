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
docsdir = mkpath(joinpath(mktempdir(), "docs-data")) # named in the production tag of the plots
config = PropDict(:setups => PropDict(:l200 => PropDicts.readprops(joinpath(testdata_dir, "dataflow-config.yaml"))))
config.setups.l200.paths[Symbol("tier/raw")] = joinpath(docsdir, "raw")

# The test data holds germanium channels only. Two SiPM channels, one per barrel, are added
# to a copy of its metadata: to the channel map and to the statuses of the run.

metadata = joinpath(docsdir, "metadata")
cp(joinpath(testdata_dir, "metadata"), metadata)
chmod(metadata, 0o755, recursive = true)
sipm_channel(name, fiber, rawid) = """
$name:
  name: $name
  system: spms
  location:
    fiber: $fiber
    position: top
  daq:
    crate: 2
    card:
      id: 10
      address: '0x100'
      serialno: null
    channel: $(rawid - 1234570)
    fcid: $(rawid - 1234530)
    rawid: $rawid
"""
open(joinpath(metadata, "hardware", "configuration", "channelmaps", "l200-p02-r%-T%-all-config.yaml"), "a") do io
    print(io, sipm_channel("S001", "IB001002", 1234570), sipm_channel("S002", "OB003004", 1234571))
end
open(joinpath(metadata, "datasets", "statuses", "l200-p02-r006-T%-all-config.yaml"), "a") do io
    print(io, "S001:\n    processable: true\n    usability: \"on\"\nS002:\n    processable: true\n    usability: \"on\"\n")
end
config.setups.l200.paths[:metadata] = metadata
PropDicts.writeprops(joinpath(docsdir, "config.json"), config)
ENV["LEGEND_DATA_CONFIG"] = joinpath(docsdir, "config.json")
l200 = LegendData(:l200);

# One trigger per channel, as the DAQ writes it: the FlashCam `baseline` of every channel,
# the germanium waveforms presummed over `presum_rate` samples and windowed around the
# rise, and the SiPM waveforms with two bits dropped, holding a few photoelectron pulses.

fk_cal = start_filekey(l200, :p02, :r006, :cal)
fk_phy = start_filekey(l200, :p02, :r006, :phy)
t_spm = range(0u"μs", 100u"μs", length = 6250)
photoelectrons(t) = sum(a * pulse(t; t0, τ = 3u"μs") for (a, t0) in zip((60, 40, 25), (60u"μs", 61u"μs", 63u"μs")))
for fk in (fk_cal, fk_phy)
    raw_path = l200.tier[:raw, fk]
    mkpath(dirname(raw_path))
    timestamp = [datetime2unix(DateTime(fk))u"s" + 100u"s"]
    lh5open(raw_path, "w") do h
        for det in channelinfo(l200, fk, system = :geds).detector
            h["raw/$det"] = Table(; timestamp,
                baseline = [UInt16(14000)], presum_rate = [UInt16(8)],
                waveform_presummed = [RDWaveform(t, 8 .* (14000 .+ 1000 .* pulse.(t) .+ 5 .* randn(length(t))))],
                waveform_windowed = [RDWaveform(t[400:600], 14000 .+ 1000 .* pulse.(t[400:600]) .+ 5 .* randn(201))],
            )
        end
        for det in channelinfo(l200, fk, system = :spms).detector
            h["raw/$det"] = Table(; timestamp,
                baseline = [UInt16(15000)],
                waveform_bit_drop = [RDWaveform(t_spm, round.(Int32, (15000 .+ rand() .* photoelectrons.(t_spm) .+ 2 .* randn(length(t_spm))) ./ 4))],
            )
        end
    end
end
t_cal = datetime2unix(DateTime(fk_cal))u"s" + 100u"s"
t_phy = datetime2unix(DateTime(fk_phy))u"s" + 100u"s";

# A physics event shows every processable channel of each system in a panel, colored by
# signal amplitude. Every waveform is drawn in the units of one ADC sample, a presummed
# waveform divided by its `presum_rate` and a bit-dropped one multiplied by its dropped
# bits, and the FlashCam baseline of the trigger is subtracted unless
# `subtract_baseline = false`.

lplot(l200, t_phy)

# `system` names the systems to draw, or gives the waveform columns of a system as a
# `Dict`; `xlims` defaults to the time range of the germanium waveforms.

lplot(l200, t_phy, system = Dict(:geds => [:waveform_presummed, :waveform_windowed]), subtract_baseline = false, figsize = (800, 400))

# The channels of a system are grouped by a column of `channelinfo`, by default the
# detector string, or the barrel of a SiPM. A `group` colors the channels by it, with a
# legend; `color` picks `:amplitude`, `:group` or `:channel` explicitly.

lplot(l200, t_phy, group = Dict(:geds => :cc4, :spms => :barrel))

# `exploded` puts every group into its own panel, `ncols` of them per row, and `filterby`
# selects channels with a predicate on the rows of `channelinfo`.

lplot(l200, t_phy, exploded = true, ncols = 2, color = :channel, figsize = (900, 700))

# A single detector of an event, of a calibration or a physics run, with its channel in the
# legend.

lplot(l200, t_cal, :V99000A)

# A timestamp is also given as a `DateTime`.

lplot(l200, unix2datetime(ustrip(u"s", t_phy)), :V99000A, show_label = false)
