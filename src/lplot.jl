# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

"""
    const LegendTheme

Makie Theme based on the LEGEND-specific style guide.

"""
LegendTheme = missing
export LegendTheme

"""
    lplot(objs...)
    lplot!(objs...)

Plots `objs` via Makie in a LEGEND-specific form/style into a new plot.

    lplot(data::LegendData, evt::NamedTuple; kwargs...)
    lplot(data::LegendData, tier::DataTier, ts::Unitful.Time; kwargs...)

The event display of a physics event: `evt` is a row of an event tier, e.g. of
`read_ldata(data, :jlevt, filekey)`, or the row at the time `ts` is read from `tier`. See
[`eventdisplay`](@ref) for the content, the keywords and for plotting several events.

"""
function lplot end
function lplot! end
export lplot, lplot!

"""
    eventdisplay(data::LegendData, ts::Unitful.Time; event_tier = :jlevt, kwargs...)
    eventdisplay(data::LegendData, evt::NamedTuple; kwargs...)

The event display of one physics event, as a new figure. `ts` is the exact `tstart` of the event,
e.g. `evts.tstart[i]`, whose row is read from `event_tier`; a time without a row is an error. `evt`
is a row of an event tier.

    eventdisplay(data::LegendData; figsize = (1800, 920), kwargs...)

A figure of the event display of physics events that is filled event by event with
`lplot!(display, ts; event_tier = :jlevt)` or `lplot!(display, evt)`, which return the figure
`display.figure`. The layout is built for the first event and reused for the next ones, and
built again for an event with other channels or another LAr configuration. The figure holds one
event at a time: save it or copy what you need before the next call.

```julia
d = eventdisplay(l200)
for i in idxs
    save("event_\$i.png", lplot!(d, evts[i]), px_per_unit = 1.5)
end
```

Needs the positions of the metadata `hardware/geometry` and an event configuration with the
`windows` and `cuts` of the LAr cut. An event without a triggered HPGe detector throws an
`ArgumentError`.

The figure shows the file key and the date and time of the event, the array from the top and from
the side, the SiPM triggers in the windows of the LAr cut around the HPGe t0, the observables of the
event and of its triggered HPGe detectors, whether it passed the LAr, muon, QC and PSD cuts, and the
waveforms of `lplot(data, ts)`. The side view
is unrolled around the array axis: the azimuth relative to the triggered string with the largest
energy runs along the horizontal axis, so that no string hides another one. SiPMs with light take
the color of their photoelectrons in the windows, and the top view adds up the SiPMs of a module;
the edge of a SiPM marks whether it is in the geometric cut around the triggered strings.

Keywords:
* `lar_energy`: the SiPM energy type, by default the one of the column `is_valid_lar`.
* `lar_cut = :geom`: the geometric LAr cut to show, `nothing` for none. The event tier needs the
  columns of that cut.
* `energy = :e_cusp_ctc_cal`, `aoe = :aoe_sg_classifier`, `lq = :lq80_250025_classifier`: the
  columns of `evt.geds` to show per triggered HPGe detector; the energy sum adds up `energy`.
* `pe_limits`: the limits of the color scale, by default at least 0.5 to 10 PE and wide enough for
  the light of the event.
* `figure`: the empty figure to fill, by default a new one of the size `figsize`. A new layout
  clears it.
* `watermark = true`, `final = true`, `preliminary = true`, `approved = false`, `production = true`:
  the marks of [`add_watermarks!`](@ref) without its logo; the logo of the display is in the title row.
* the keywords of `lplot(data, ts)` for the waveforms: `system`, `only_processable`, `filterby`,
  `group`, `color`, `exploded`, `ncols`, `plot_tier`, `subtract_baseline`, `xunit` and `xlims`. They
  do not change the top and side views.
* `show_empty_traces = true`: with `false`, only the waveforms of the triggered HPGe detectors and of
  the SiPMs with light anywhere in their trace, also outside the windows of the LAr cut. A layout
  fills in place only for an event with as many of these channels per panel as the event before.

With several Julia threads the waveforms are read while the other panels are filled.
"""
function eventdisplay end
export eventdisplay


"""
    lhist(values; bins = 100, kwargs...)
    lhist(x, y; bins = 100, kwargs...)
    lhist(histogram; kwargs...)
    lhist!(args...; kwargs...)

Plot a one- or two-dimensional histogram with the LEGEND style. `bins` may be a
bin count, explicit edges, or a pair of either for a two-dimensional histogram.

"""
function lhist end
function lhist! end
export lhist, lhist!

"""
    lsavefig(filename)

Saves the current figure to a file with a given `filename`.

"""
function lsavefig end
export lsavefig


# recipes
function residualplot! end
function energycalibrationplot! end
function aoecorrectionplot! end
function parameterplot! end
function waveformplot! end

# watermark functions
function add_logo! end
function add_legend_logo! end
function add_juleana_logo! end
function add_text! end
"""
    add_watermarks!(; legend_logo = false, juleana_logo = true, show_date = true, position = "outer right",
        preliminary = true, approved = false, final = false, production = true)

Mark the current figure: the Juleana logo, or the LEGEND logo with `legend_logo`, with the month
of the plot unless `show_date = false`, at `position` (`"outer right"` or `"outer top"`) of the
current axis; the tag `PRELIMINARY`, or `INTERNAL USE ONLY` when `preliminary = false` and not
`approved`, and no tag when `final`; and, with `production` and the environment variable
`LEGEND_DATA_CONFIG` set, the name of the data production, the directory of its configuration
file. Every recipe calls it unless `watermark = false` and passes these keywords on.
"""
function add_watermarks! end
function add_production! end