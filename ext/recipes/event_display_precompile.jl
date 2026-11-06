# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

# Fills an event display with a synthetic event so that its layout and panels are compiled at
# package precompilation. Nothing is read or rendered: the metadata and the data of a real event
# are not available, and a Makie backend is not a dependency. Compiled code is only reused for the
# same argument types, so `array`, `config.windows`, `config.geometric` and `panels` have the types
# they have for a real event. A function keeps these names out of the globals of the module, where
# `@setup_workload` would put them.
function _event_display_workload()
    DetId = LegendDataManagement.DetectorId
    data = LegendDataManagement.LegendData(LegendDataManagement.SetupConfig(Pair{Vector{String}, String}[], "default"), :l200, :default)

    geds = (detector = DetId.([:V00001A, :V00002A, :V00003A]), detstring = [1, 1, 2], position = [1, 2, 1],
        x = [200.0, 200.0, -200.0]u"mm", y = [0.0, 0.0, 0.0]u"mm", z = [-500.0, -600.0, -500.0]u"mm", angle = [0.0, 0.0, 180.0]u"°")
    spms = (detector = DetId.([:S001, :S002, :S003]), barrel = [:outer, :outer, :inner],
        x = [280.0, -280.0, 0.0]u"mm", y = [0.0, 0.0, -120.0]u"mm", z = [-30.0, -30.0, -60.0]u"mm", angle = [0.0, 180.0, 90.0]u"°")
    shapes = [(radius = 40.0, height = 80.0) for _ in eachindex(geds.detector)]
    evt = (geds = (trig_e_det = geds.detector[2:2], trig_e_cusp_ctc_cal = [1000.0u"keV"], detector = geds.detector),
        ged_spm = (; spm = (detector = spms.detector[1:2], trig_max_trap_cal_prompt_pe_sum = [2.0, 0.0], trig_max_trap_cal_delayed_pe_sum = [1.0, 3.0])))
    lar = (; spm_windows = ["prompt", "delayed"])
    config = (geometric = (name = :geom, window = :full, dphi_max = (inner = 180.0, outer = 45.0)),
        windows = (prompt = [-1.5, 0.5], full = [-1.5, 5.0], delayed = [0.5, 5.0]), cut_window = :full)
    triggers = (times = [0.0, 1.0], pes = [2.0, 3.0])
    observables = (event = fill("1", 5), cuts = fill("1", 4), triggered = fill("1", 5))
    logo = fill(Makie.Colors.RGBA{Makie.Colors.N0f8}(0, 0, 0, 0), 2, 2)

    t = range(0.0u"ns", step = 16.0u"ns", length = 600)
    waveforms = RadiationDetectorSignals.ArrayOfRDWaveforms([RadiationDetectorSignals.RDWaveform(t, [k * sin(i / 10) for i in eachindex(t)]) for k in (1.0, 2.0)])
    panels = [(; sys, tag = string(sys), wvfs = [column => waveforms], colors = Dict(column => get(Makie.cgrad(:coolwarm), [1.0, 2.0], :extrema)), legend = nothing)
        for (sys, column) in ((:geds, :waveform_presummed), (:spms, :waveform_bit_drop))]

    d = LegendMakie.eventdisplay(data)
    array = _event_array(geds, spms, shapes, evt, :trig_max_trap_cal, lar, config.geometric.dphi_max)
    _build_event_display!(d, array, config; logo)
    _fill_event_panels!(d.plots, "key", _event_date(1.5u"s"), observables, array, config, triggers, (0.5, 10.0))
    d.waveforms = _build_event_waveforms!(d.waveform_grid, panels, d.options)
    _fill_event_waveforms!(d.waveforms, panels, 4.0, config.windows, config.cut_window, d.options)
    Base.empty!(d.figure)
    nothing
end

PrecompileTools.@compile_workload _event_display_workload()
