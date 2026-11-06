# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

const _trigger_color = "#E07B00"
const _string_color = "#EEF0F4"
const _string_edge_color = "#B8BEC8"
const _detector_color = "#D5D9E0"
const _outside_cut_color = "#7A8088"
const _absent_sipm_color = "#D8DBE0"
const _lar_colormap = :plasma

# The side of the logo in the title row, in pixels of the figure
const _event_logo_size = 56

_rgba(color) = Makie.RGBAf(Makie.to_color(color))
_rgba(color, alpha) = Makie.RGBAf(Makie.to_color(color), alpha)

_wrap_degrees(a::Real) = mod(a + 180, 360) - 180
_dphi_degrees(a::Real, b::Real) = abs(_wrap_degrees(a - b))

# The energy type of the SiPMs that decides the LAr cut of an event
function _lar_energy_type(lar)
    energy_types = Symbol.(collect(keys(lar.energy_types)))
    found = filter(e -> occursin(string(e), string(lar.is_valid_lar)), energy_types)
    length(found) == 1 || throw(ArgumentError("Expected one of the energy types $energy_types in the LAr cut `$(lar.is_valid_lar)`"))
    only(found)
end

# The window of the LAr cut `name` and its maximal azimuth from a triggered HPGe detector per SiPM
# barrel. Without a name every SiPM counts.
function _lar_geometric_cut(lar, name)
    isnothing(name) && return (name = nothing, window = nothing, dphi_max = (inner = 180.0, outer = 180.0))
    cut = Symbol(name)
    haskey(lar.cuts, cut) || throw(ArgumentError("The LAr configuration has no cut `$cut`, only $(collect(keys(lar.cuts)))"))
    (; window, dphi_max) = lar.cuts[cut]
    (name = cut, window = Symbol(window), dphi_max = (inner = Unitful.ustrip(u"°", dphi_max.inner), outer = Unitful.ustrip(u"°", dphi_max.outer)))
end

# The date and time of an event in UTC to the microsecond, the resolution of a Float64 time in
# seconds since the epoch
function _event_date(ts::Unitful.Time)
    seconds = Unitful.ustrip(u"s", ts)
    whole = floor(Int, seconds)
    Dates.format(Dates.unix2datetime(whole), "yyyy-mm-dd HH:MM:SS") * Format.format(".{:06d} UTC", floor(Int, (seconds - whole) * 1e6))
end

# What the display takes from the metadata for a DAQ cycle. `key` holds everything the layout of
# the figure depends on: an event with another `key` needs a new layout.
function _event_configuration(data, fk, lar_energy, lar_cut)
    lar_task = Threads.@spawn LegendDataManagement.get_spms_evt_lar_cut_props(data, fk)
    chinfo = LegendDataManagement.channelinfo(data, fk; extended = true, verbose = false)
    lar = fetch(lar_task)
    haskey(lar, :windows) && haskey(lar, :cuts) || throw(ArgumentError("The LAr configuration of $fk has no `windows` and `cuts`: the event display needs an event tier of JuLeAna v0.8.3 or later"))

    geds = chinfo[chinfo.system .== :geds]
    spms = chinfo[chinfo.system .== :spms]
    for column in (geds.x, geds.y, geds.z, geds.angle, spms.x, spms.y, spms.z, spms.angle)
        all(isfinite, column) || throw(ArgumentError("The event display needs the position of every HPGe and SiPM detector in the metadata `hardware/geometry`"))
    end

    geometric = _lar_geometric_cut(lar, lar_cut)
    windows = (; (Symbol(k) => Unitful.ustrip.(u"µs", w) for (k, w) in pairs(lar.windows))...)
    cut_window = Symbol(lar.cuts[:all].window)
    key = (geds = map(c -> collect(getproperty(geds, c)), (:detector, :detstring, :position, :processable, :usability, :x, :y, :z, :angle)),
        spms = map(c -> collect(getproperty(spms, c)), (:detector, :processable, :usability, :barrel, :x, :y, :z, :angle)),
        geometric, windows, cut_window)
    (; geds, spms, lar, lar_energy = isnothing(lar_energy) ? _lar_energy_type(lar) : Symbol(lar_energy), geometric, windows, cut_window, key)
end

# The radius and height in mm of every HPGe detector, one file of the metadata per detector
function _detector_shapes(data, detectors)
    diodes = data.metadata.hardware.detectors.germanium.diodes
    fetch.(map(collect(detectors)) do det
        Threads.@spawn let g = diodes[Symbol(det)].geometry
            (radius = Float64(g.radius_in_mm), height = Float64(g.height_in_mm))
        end
    end)
end

# The layout of the HPGe detectors and SiPMs in the array for a row `evt` of the event tier: every
# position in mm and azimuth in degrees, the HPGe detectors that triggered and the light of each
# SiPM in the windows of the LAr cut, in photoelectrons. The `z` of a detector is the center of its
# crystal, so a string starts where the rod length and the height of its top detector put it.
function _event_array(geds, spms, shapes, evt, lar_energy, lar, dphi_max)
    trig_dets = collect(evt.geds.trig_e_det)
    all(in(geds.detector), trig_dets) || throw(ArgumentError("Triggered detector $(setdiff(trig_dets, geds.detector)) not in the channel information"))
    main_det = trig_dets[findmax(e -> isnan(e) ? zero(e) : e, evt.geds.trig_e_cusp_ctc_cal)[2]]
    angle_of(det) = Unitful.ustrip(u"°", geds.angle[findfirst(==(det), geds.detector)])
    trig_angles = angle_of.(trig_dets)
    main_angle = angle_of(main_det)

    det_angles = Unitful.ustrip.(u"°", geds.angle)
    x, y, z = Unitful.ustrip.(u"mm", geds.x), Unitful.ustrip.(u"mm", geds.y), Unitful.ustrip.(u"mm", geds.z)
    triggered = geds.detector .∈ Ref(trig_dets)

    detectors = (; detector = geds.detector, detstring = geds.detstring, position = geds.position, z, triggered, in_event = geds.detector .∈ Ref(Set(evt.geds.detector)),
        radius = getindex.(shapes, :radius), height = getindex.(shapes, :height), dphi = _wrap_degrees.(det_angles .- main_angle))

    strings = map(sort(unique(geds.detstring))) do s
        sel = findall(==(s), geds.detstring)
        (detstring = s, x = first(x[sel]), y = first(y[sel]), radius = maximum(detectors.radius[sel]), top = maximum(z[sel] .+ detectors.height[sel] ./ 2),
            dphi = first(detectors.dphi[sel]), triggered = any(triggered[sel]))
    end

    # the light per SiPM over the windows of the event tier; a channel outside the event tier has none
    spm = evt.ged_spm.spm
    window_pe = map(w -> Unitful.ustrip.(getproperty(spm, Symbol(lar_energy, "_", w, "_pe_sum"))), lar.spm_windows)
    spm_pe = Dict(zip(spm.detector, reduce(+, window_pe)))
    spm_angles = Unitful.ustrip.(u"°", spms.angle)
    barrel_limit = [getproperty(dphi_max, b) for b in spms.barrel]
    sipms = (; detector = spms.detector, x = Unitful.ustrip.(u"mm", spms.x), y = Unitful.ustrip.(u"mm", spms.y), z = Unitful.ustrip.(u"mm", spms.z), barrel = spms.barrel,
        dphi = _wrap_degrees.(spm_angles .- main_angle), pe = [get(spm_pe, d, 0.0) for d in spms.detector], in_event = spms.detector .∈ Ref(Set(spm.detector)),
        in_cut = [any(t -> _dphi_degrees(a, t) <= l, trig_angles) for (a, l) in zip(spm_angles, barrel_limit)])

    # a module of a barrel holds the SiPMs at the top and at the bottom of one azimuth
    keys_module = collect(zip(sipms.x, sipms.y, sipms.barrel))
    modules = map(unique(keys_module)) do k
        sel = findall(==(k), keys_module)
        (x = k[1], y = k[2], barrel = k[3], pe = sum(sipms.pe[sel]), in_cut = first(sipms.in_cut[sel]), in_event = any(sipms.in_event[sel]))
    end

    radii = (; (b => maximum(hypot.(sipms.x[sipms.barrel .== b], sipms.y[sipms.barrel .== b])) for b in unique(sipms.barrel))...)
    # the azimuths of the triggered strings in the plane of the top view, in which y grows against the azimuth
    trig_plot_angles = unique(trig_angles) .|> a -> -a
    (; detectors, strings, sipms, modules, radii, main_det, main_angle, trig_angles, trig_plot_angles)
end

# The SiPM triggers inside the window of the LAr cut around the first HPGe t0: time in µs relative to
# that t0 and light, without the triggers the cut flags as dark counts
function _event_lar_triggers(evt, lar_energy, lar, window_us)
    props = lar.energy_types[lar_energy]
    t0 = Unitful.ustrip(u"µs", evt.geds.t0_start)
    positions = getproperty(evt.spms, Symbol(props.pos))
    is_dc = getproperty(evt.spms, Symbol(props.is_dc))
    charges = getproperty(evt.spms, lar_energy)
    times, pes = Float64[], Float64[]
    for i in eachindex(positions, is_dc, charges), j in eachindex(positions[i], is_dc[i], charges[i])
        t = Unitful.ustrip(u"µs", positions[i][j]) - t0
        pe = Unitful.ustrip(charges[i][j])
        if !is_dc[i][j] && pe > 0 && first(window_us) <= t <= last(window_us)
            push!(times, t)
            push!(pes, pe)
        end
    end
    (; times, pes)
end

# The channels whose traces hold a signal, per system: the triggered HPGe detectors and the SiPMs
# with light anywhere in their trace, also outside the windows of the LAr cut
function _event_signal_channels(evt, lar_energy)
    lit = [any(q -> Unitful.ustrip(q) > 0, charges) for charges in getproperty(evt.spms, lar_energy)]
    Dict(:geds => Set(evt.geds.trig_e_det), :spms => Set(evt.spms.detector[lit]))
end

# The color scale covers at least 0.5 to 10 PE and widens to the smallest and largest light of the event
function _event_pe_limits(array, triggers, pe_limits)
    isnothing(pe_limits) || return pe_limits
    pes = vcat(filter(>(0), array.sipms.pe), filter(>(0), [m.pe for m in array.modules]), triggers.pes)
    isempty(pes) ? (0.5, 10.0) : (min(0.5, minimum(pes)), max(10.0, maximum(pes)))
end

# The text of a number; `Format.format` cuts a value that is not finite to the digits of `spec`
_number_text(spec, v) = isfinite(v) ? Format.format(spec, v) : string(v)

# The observables of the event as text: the values of the event, the decisions of its cuts, and per
# column the values of the triggered HPGe detectors, one per line
function _event_observable_values(evt, array, config; energy, aoe, lq)
    (; lar_energy, cut_window, geometric) = config
    sum_of(cut, col) = getproperty(evt.ged_spm, Symbol(lar_energy, "_spms_", cut, "_", col))
    pe_text(v) = _number_text("{:.1f}", Unitful.ustrip(v)) * " PE"
    energy_text(v) = _number_text("{:.2f}", Unitful.ustrip(u"keV", v)) * " keV"
    idxs = collect(evt.geds.trig_e_det_idxs)
    energies = getproperty(evt.geds, energy)[idxs]
    (; detector, detstring, position) = array.detectors
    places = [findfirst(==(d), detector) for d in evt.geds.detector[idxs]]

    event = [energy_text(sum(energies)), pe_text(sum_of(cut_window, "pe_sum")), string(sum_of(cut_window, "multiplicity"))]
    if !isnothing(geometric.name)
        geometric_cut = "$(geometric.name)_$(geometric.window)"
        push!(event, pe_text(sum_of(geometric_cut, "pe_sum")), string(sum_of(geometric_cut, "multiplicity")))
    end
    passed_text(is_valid) = is_valid ? "passed" : "not passed"
    cuts = [evt.ged_spm.is_valid_lar ? "passed" : "vetoed", passed_text(evt.ged_pmt.is_valid_muon), passed_text(evt.geds.is_valid_qc), passed_text(evt.geds.is_valid_psd)]

    triggered = [string.(evt.geds.detector[idxs]), ["$(detstring[i]), $(position[i])" for i in places],
        energy_text.(energies), _number_text.("{:.2f}", getproperty(evt.geds, aoe)[idxs]), _number_text.("{:.2f}", getproperty(evt.geds, lq)[idxs])]
    (; event, cuts, triggered = [join(column, "\n") for column in triggered])
end

# The tick values of a logarithmic color bar over `limits`
function _pe_ticks(limits)
    decades = floor(Int, log10(first(limits))):ceil(Int, log10(last(limits)))
    ticks = [m * 10.0^d for d in decades for m in (1, 2, 5)]
    filter(t -> first(limits) <= t <= last(limits), ticks)
end

_pe_label(t) = isinteger(t) ? string(round(Int, t)) : string(t)

# The color of an amount of light on the logarithmic scale of the color bar
function _pe_color(pe, limits)
    Makie.RGBAf(Makie.interpolated_getindex(Makie.to_colormap(_lar_colormap), log10(pe), (log10(first(limits)), log10(last(limits)))))
end

# The markers of SiPMs: the ones without light are hollow and drawn first, the ones with light take
# the color of their light on top of them; the edge tells whether the SiPM is in the geometric cut.
function _sipm_marker_data(points, pe, in_cut, in_event, limits)
    order = vcat(findall(iszero, pe), findall(>(0), pe))
    color = [pe[i] > 0 ? _pe_color(pe[i], limits) : in_event[i] ? _rgba(:white) : _rgba(_absent_sipm_color) for i in order]
    strokecolor = [in_cut[i] ? _rgba(LegendMakie.AchatBlue) : _rgba(_outside_cut_color) for i in order]
    (points = points[order], color, strokecolor)
end

_update_sipm_markers!(plot, data) = Makie.update!(plot, arg1 = data.points, color = data.color, strokecolor = data.strokecolor)

# The polygon of an annular sector, with the half width `dphi` in degrees around the azimuth `phi`
function _annular_sector(r_inner, r_outer, phi, dphi)
    angles = deg2rad.(range(phi - dphi, phi + dphi, length = 181))
    outer = Makie.Point2f.(r_outer .* cos.(angles), r_outer .* sin.(angles))
    inner = Makie.Point2f.(r_inner .* cos.(reverse(angles)), r_inner .* sin.(reverse(angles)))
    vcat(outer, inner)
end

# The half width of the band of a barrel around its radius in the top view, in mm
const _barrel_band = 22

# The array seen from the top: the HPGe strings, the SiPM barrels around them and the geometric cut
function _build_event_top_view!(pos, array, geometric)
    r_outer, r_inner = array.radii.outer, array.radii.inner
    r_max = r_outer + 42
    ax = Makie.Axis(pos, aspect = Makie.DataAspect(), limits = (-r_max, r_max, -r_max, r_max), title = "Top view", titlefont = :regular)
    Makie.hidedecorations!(ax)
    Makie.hidespines!(ax)

    sectors = Makie.poly!(ax, Vector{Makie.Point2f}[], color = Makie.RGBAf[], strokewidth = 0)
    edges = Makie.linesegments!(ax, Pair{Makie.Point2f, Makie.Point2f}[], color = LegendMakie.AchatBlue, linestyle = :dash, linewidth = 1)

    circle(r) = Makie.Point2f.(r .* cosd.(0:2:360), r .* sind.(0:2:360))
    Makie.lines!(ax, circle(r_outer), color = _string_edge_color, linewidth = 1)
    Makie.lines!(ax, circle(r_inner), color = _string_edge_color, linewidth = 1)

    strings = Makie.poly!(ax, [Makie.Circle(Makie.Point2f(s.x, s.y), s.radius) for s in array.strings],
        color = fill(_rgba(_string_color), length(array.strings)), strokecolor = _string_edge_color, strokewidth = 1)
    string_names = Makie.text!(ax, [Makie.Point2f(s.x, s.y) for s in array.strings], text = [string(s.detstring) for s in array.strings],
        align = (:center, :center), fontsize = 15, color = fill(_rgba(:gray35), length(array.strings)))

    inner_selection = geometric.dphi_max.inner >= 180 ? "all $(count(m -> m.barrel == :inner, array.modules)) modules" : "±$(round(Int, geometric.dphi_max.inner))°"
    Makie.text!(ax, 0, 0, text = "inner barrel\n$inner_selection", align = (:center, :center), fontsize = 14, color = LegendMakie.DeepCove)

    markers = Makie.scatter!(ax, Makie.Point2f[], color = Makie.RGBAf[], strokecolor = Makie.RGBAf[], strokewidth = 1.5, markersize = 17)
    (; sectors, edges, strings, string_names, markers)
end

function _fill_event_top_view!(h, array, geometric, limits)
    r_outer, r_inner = array.radii.outer, array.radii.inner
    limit_outer, limit_inner = geometric.dphi_max.outer, geometric.dphi_max.inner
    band, wedge = _rgba(LegendMakie.AchatBlue, 0.22), _rgba(LegendMakie.AchatBlue, 0.09)

    # the part of each barrel in the geometric cut around every triggered string
    polygons, colors = Vector{Makie.Point2f}[], Makie.RGBAf[]
    for phi in (limit_inner >= 180 ? [0.0] : array.trig_plot_angles)
        push!(polygons, _annular_sector(r_inner - _barrel_band, r_inner + _barrel_band, phi, min(limit_inner, 180)))
        push!(colors, band)
    end
    for phi in array.trig_plot_angles
        push!(polygons, _annular_sector(r_inner + _barrel_band, r_outer, phi, min(limit_outer, 180)), _annular_sector(r_outer - _barrel_band, r_outer + _barrel_band, phi, min(limit_outer, 180)))
        push!(colors, wedge, band)
    end
    Makie.update!(h.sectors, arg1 = polygons, color = colors)

    r_from, r_to = r_inner + _barrel_band, r_outer + _barrel_band
    Makie.update!(h.edges, arg1 = Pair{Makie.Point2f, Makie.Point2f}[Makie.Point2f(r_from * cosd(a), r_from * sind(a)) => Makie.Point2f(r_to * cosd(a), r_to * sind(a))
        for phi in array.trig_plot_angles if limit_outer < 180 for a in (phi - limit_outer, phi + limit_outer)])

    Makie.update!(h.strings, color = [s.triggered ? _rgba(_trigger_color) : _rgba(_string_color) for s in array.strings])
    Makie.update!(h.string_names, color = [s.triggered ? _rgba(:white) : _rgba(:gray35) for s in array.strings])

    m = array.modules
    _update_sipm_markers!(h.markers, _sipm_marker_data([Makie.Point2f(x.x, x.y) for x in m], [x.pe for x in m], [x.in_cut for x in m], [x.in_event for x in m], limits))
end

# The array seen from the side, unrolled around its axis: the azimuth relative to the main triggered
# string runs along the axis, so that no string hides another one
function _build_event_side_view!(pos, array, geometric)
    (; strings, sipms) = array
    z_max = maximum(sipms.z) + 50
    z_min = minimum(sipms.z) - 50
    outer_limit = geometric.dphi_max.outer
    xticks = sort(unique(vcat(-180.0, -90.0, 0.0, 90.0, 180.0, outer_limit < 180 ? [-outer_limit, outer_limit] : Float64[])))
    # the left margin holds the names of the SiPM rows
    ax = Makie.Axis(pos, limits = (-240, 198, z_min, z_max), title = "Side view, unrolled around the array axis", titlefont = :regular,
        xlabel = "Azimuth relative to the trigger string (°)", ylabel = "z (mm)", xticks = (xticks, _pe_label.(xticks)), ygridvisible = false, xgridvisible = false)

    bands = Makie.vspan!(ax, Float64[], Float64[], color = _rgba(LegendMakie.AchatBlue, 0.10))
    rects = Makie.poly!(ax, Makie.Rect2f[], color = Makie.RGBAf[], strokecolor = _string_edge_color, strokewidth = 0.8)
    # one height for the numbers of the strings, above the highest detector
    names_z = maximum(s.top for s in strings) + 14
    string_names = Makie.text!(ax, [Makie.Point2f(s.dphi, names_z) for s in strings], text = [string(s.detstring) for s in strings], align = (:center, :bottom), fontsize = 12, color = :gray35)
    # the names of the triggered detectors stand on a white outline, over the detectors next to them
    trig_outlines = Makie.text!(ax, Makie.Point2f[], text = String[], align = (:left, :center), fontsize = 12, font = :bold, color = :white, strokecolor = :white, strokewidth = 3)
    trig_names = Makie.text!(ax, Makie.Point2f[], text = String[], align = (:left, :center), fontsize = 12, font = :bold, color = _trigger_color)
    markers = Makie.scatter!(ax, Makie.Point2f[], color = Makie.RGBAf[], strokecolor = Makie.RGBAf[], strokewidth = 1.5, markersize = 10)
    for b in unique(sipms.barrel), z in unique(sipms.z[sipms.barrel .== b])
        Makie.text!(ax, -236, z, text = string(b), align = (:left, :center), fontsize = 10, color = :gray40)
    end
    (; bands, rects, string_names, names_z, trig_outlines, trig_names, markers)
end

function _fill_event_side_view!(h, array, geometric, limits)
    (; detectors, strings, sipms) = array

    # the azimuths of the geometric cut in the outer barrel
    lows, highs = Float64[], Float64[]
    if geometric.dphi_max.outer < 180
        for phi in array.trig_angles, shift in (-360, 0, 360)
            center = _wrap_degrees(phi - array.main_angle) + shift
            push!(lows, center - geometric.dphi_max.outer)
            push!(highs, center + geometric.dphi_max.outer)
        end
    end
    Makie.update!(h.bands, arg1 = lows, arg2 = highs)

    # a detector at its true height, and at the azimuth its width takes at the radius of a string
    string_radius = maximum(hypot(s.x, s.y) for s in strings)
    widths = rad2deg.(2 .* detectors.radius ./ string_radius)
    Makie.update!(h.rects, arg1 = [Makie.Rect2f(detectors.dphi[i] - widths[i] / 2, detectors.z[i] - detectors.height[i] / 2, widths[i], detectors.height[i]) for i in eachindex(widths)],
        color = [detectors.triggered[i] ? _rgba(_trigger_color) : detectors.in_event[i] ? _rgba(_detector_color) : _rgba(:white) for i in eachindex(widths)])

    Makie.update!(h.string_names, arg1 = [Makie.Point2f(s.dphi, h.names_z) for s in strings])

    # the name of a detector far to the right of the main string stands on its left, inside the axis
    trig = findall(detectors.triggered)
    on_left = [detectors.dphi[i] > 90 for i in trig]
    points = [Makie.Point2f(detectors.dphi[i] + (left ? -1 : 1) * (widths[i] / 2 + 2), detectors.z[i]) for (i, left) in zip(trig, on_left)]
    aligns = [(left ? :right : :left, :center) for left in on_left]
    names = [string(detectors.detector[i]) for i in trig]
    Makie.update!(h.trig_outlines, arg1 = points, text = names, align = aligns)
    Makie.update!(h.trig_names, arg1 = points, text = names, align = aligns)

    _update_sipm_markers!(h.markers, _sipm_marker_data(Makie.Point2f.(sipms.dphi, sipms.z), sipms.pe, sipms.in_cut, sipms.in_event, limits))
end

# The windows of the LAr cut around the HPGe t0 with the positions of the SiPM triggers as bars
function _build_event_windows!(pos, windows, cut_window)
    cut = getproperty(windows, cut_window)
    margin = 0.04 * (last(cut) - first(cut))
    edges = sort(unique(vcat(0.0, [collect(getproperty(windows, k)) for k in keys(windows)]...)))
    ax = Makie.Axis(pos, limits = (first(cut) - margin, last(cut) + margin, 0, 1), xticks = (edges, [e > 0 ? "+$(_pe_label(e))" : _pe_label(e) for e in edges]),
        xlabel = "SiPM triggers, time relative to the HPGe t₀ (µs)", xgridvisible = false, ygridvisible = false, yticksvisible = false, yticklabelsvisible = false,
        topspinevisible = false, leftspinevisible = false, rightspinevisible = false)
    for (i, k) in enumerate(sort(filter(k -> k != cut_window, collect(keys(windows))), by = k -> first(getproperty(windows, k))))
        w = getproperty(windows, k)
        Makie.poly!(ax, Makie.Rect2f(first(w), 0.0, last(w) - first(w), 1.0), color = _rgba(LegendMakie.AchatBlue, isodd(i) ? 0.30 : 0.13))
        Makie.text!(ax, first(w) + 0.05, 0.82, text = string(k), align = (:left, :center), fontsize = 13, color = LegendMakie.DeepCove)
    end
    bars = Makie.linesegments!(ax, Makie.Point2f[], color = Makie.RGBAf[], linewidth = 2.5)
    Makie.vlines!(ax, [0.0], color = _trigger_color, linewidth = 1.5)
    (; bars)
end

function _fill_event_windows!(h, triggers, limits)
    Makie.update!(h.bars, arg1 = [Makie.Point2f(t, y) for t in triggers.times for y in (0.0, 0.66)],
        color = [_pe_color(pe, limits) for pe in triggers.pes for _ in 1:2])
end

# The file key and the date of the event with the logo in the corner of the figure
function _build_event_title!(pos, logo_image)
    g = Makie.GridLayout(pos, tellheight = true)
    filekey = Makie.Label(g[1, 1], " ", font = :bold, fontsize = 22, halign = :left, tellwidth = false)
    date = Makie.Label(g[1, 2], " ", font = :bold, fontsize = 22, halign = :right, tellwidth = false)
    logo = Makie.Axis(g[1, 3], width = _event_logo_size, height = _event_logo_size, aspect = Makie.DataAspect())
    Makie.hidedecorations!(logo)
    Makie.hidespines!(logo)
    Makie.image!(logo, Makie.rotr90(logo_image))
    Makie.colgap!(g, 2, 12)
    (; filekey, date)
end

# The observables centered over the waveforms: the values of the event, the decisions of its cuts,
# and below them one row per triggered HPGe detector
function _build_event_observables!(pos, geometric; energy, aoe, lq)
    g = Makie.GridLayout(pos, tellheight = true)
    function table(row, names; first_color = :black)
        cells = Makie.GridLayout(g[row, 1], halign = :center, tellwidth = false)
        map(enumerate(names)) do (c, name)
            Makie.Label(cells[1, c], name, fontsize = 13, color = :gray40, halign = :left, tellwidth = true)
            value = Makie.Label(cells[2, c], " ", fontsize = 17, font = :bold, color = c == 1 ? first_color : :black, halign = :left, justification = :left, tellwidth = true)
            Makie.colgap!(cells, 22)
            Makie.rowgap!(cells, 2)
            value
        end
    end
    has_geometric = !isnothing(geometric.name)
    event = table(1, vcat("energy sum", "LAr PE sum", "LAr multiplicity", has_geometric ? ["geom. cut PE sum", "geom. cut multiplicity"] : String[]))
    cuts = table(2, ["LAr cut", "muon cut", "QC", "PSD cut"])
    triggered = table(3, ["triggered HPGe", "string, position", string(energy), string(aoe), string(lq)]; first_color = _trigger_color)
    Makie.rowgap!(g, 6)
    (; event, cuts, triggered)
end

# The legend of the array and the color scale of the light
function _build_event_key!(pos)
    key = Makie.GridLayout(pos, tellheight = true)
    marker(color, edge; shape = :circle) = Makie.MarkerElement(; marker = shape, color, strokecolor = edge, strokewidth = 1.5, markersize = 15)
    Makie.Legend(key[1, 1], [
            marker(_string_color, _string_edge_color), marker(_trigger_color, _string_edge_color), marker(:white, _string_edge_color; shape = :rect),
            marker(:white, LegendMakie.AchatBlue), marker(:white, _outside_cut_color)],
        ["HPGe string", "triggering HPGe", "HPGe off", "SiPM in the geom. cut", "SiPM outside"],
        orientation = :horizontal, nbanks = 2, framevisible = false, labelsize = 13, patchsize = (16, 14), tellwidth = false, tellheight = true)
    colorbar = Makie.Colorbar(key[2, 1], vertical = false, flipaxis = false, colormap = _lar_colormap, limits = (0.5, 10.0), scale = log10,
        label = "SiPM light in the windows (PE)", labelsize = 14, ticklabelsize = 12, height = 12, tellwidth = false)
    Makie.rowgap!(key, 2)
    (; colorbar)
end

function _fill_event_key!(h, limits)
    ticks = _pe_ticks(limits)
    h.colorbar.limits[] = limits
    h.colorbar.ticks[] = (ticks, _pe_label.(ticks))
    # the minor ticks of a color bar do not follow new limits on their own
    h.colorbar.minorticks[] = Makie.IntervalsBetween(5, true)
    nothing
end

# Draws the marks of `add_watermarks!` inside the axis `ax`, so that they follow the layout. The
# title row holds the logo.
function _add_event_marks!(ax; preliminary::Bool, approved::Bool, final::Bool, production::Bool)
    tag = final ? nothing : preliminary ? "PRELIMINARY" : approved ? nothing : "INTERNAL USE ONLY"
    isnothing(tag) || Makie.text!(ax, 0.995, 0.97, text = tag, space = :relative, align = (:right, :top), font = :bold, color = :red)
    if production && haskey(ENV, "LEGEND_DATA_CONFIG")
        Makie.text!(ax, 0.995, 0.995, text = basename(dirname(last(split(ENV["LEGEND_DATA_CONFIG"], ":")))), space = :relative, align = (:right, :top), fontsize = 7)
    end
    nothing
end

# The number of channels, the waveform columns and the legend of the panels: other ones need new axes
_panel_key(panels) = [(p.sys, p.tag, [(k, length(w)) for (k, w) in p.wvfs], p.legend) for p in panels]

# The axes of the waveforms, with the lines of the HPGe t0 and the bands of the windows of the cut
function _build_event_waveforms!(g, panels, options)
    grid = Makie.GridLayout(g)
    axs, watermark_ax = _draw_event_panels!(grid, panels; options.exploded, options.ncols, options.xlims, options.xunit)
    series = [filter(p -> p isa Makie.Series, ax.scene.plots) for ax in axs]
    t0_lines = [Makie.vlines!(ax, [0.0], color = _trigger_color, linewidth = 1) for ax in axs]
    bands = [p.sys == :spms ? Makie.vspan!(ax, Float64[], Float64[], color = _rgba(LegendMakie.AchatBlue, 0.18)) : nothing for (ax, p) in zip(axs, panels)]
    options.watermark && _add_event_marks!(watermark_ax; options.preliminary, options.approved, options.final, options.production)
    (; key = _panel_key(panels), axs, series, t0_lines, bands)
end

function _fill_event_waveforms!(h, panels, t0_us, windows, cut_window, options)
    (; xunit) = options
    t0 = Unitful.ustrip(xunit, t0_us * u"µs")
    in_xunit(v) = Unitful.ustrip(xunit, v * u"µs")
    others = filter(k -> k != cut_window, collect(keys(windows)))
    lows = [t0 + in_xunit(first(getproperty(windows, k))) for k in others]
    highs = [t0 + in_xunit(last(getproperty(windows, k))) for k in others]
    for (i, p) in enumerate(panels)
        for (plot, (p_wvf, w)) in zip(h.series[i], p.wvfs)
            x, signals = _series_data(w, xunit)
            Makie.update!(plot, arg1 = x, arg2 = collect(signals'), solid_color = p.colors[p_wvf])
        end
        Makie.update!(h.t0_lines[i], arg1 = [t0])
        isnothing(h.bands[i]) || Makie.update!(h.bands[i], arg1 = lows, arg2 = highs)
    end
    xlims = isnothing(options.xlims) ? _event_xlims(panels, xunit) : options.xlims
    foreach(ax -> ax.limits[] = (xlims, nothing), h.axs)
    # the signal tick labels of an event set the width of the label column
    foreach(Makie.reset_limits!, h.axs)
    yspace = maximum(Makie.tight_yticklabel_spacing!, (h.axs...,))
    foreach(ax -> ax.yticklabelspace = yspace, h.axs)
    nothing
end

# A figure of the event display that is filled event by event, see `eventdisplay`. The layout is
# built for the first event and again for an event whose `_event_configuration` key or waveform
# panels differ.
mutable struct EventDisplay
    const data::LegendDataManagement.LegendData
    const figure::Makie.Figure
    const options::NamedTuple
    key::Any
    shapes::Vector{@NamedTuple{radius::Float64, height::Float64}}
    plots::Any
    waveform_grid::Any
    waveforms::Any
end

function LegendMakie.eventdisplay(data::LegendDataManagement.LegendData;
        figsize = (1800, 920), figure::Makie.Figure = Makie.Figure(size = figsize),
        system = [:geds, :spms], lar_energy = nothing, lar_cut = :geom, energy::Symbol = :e_cusp_ctc_cal, aoe::Symbol = :aoe_sg_classifier, lq::Symbol = :lq80_250025_classifier,
        pe_limits = nothing, only_processable::Bool = true, filterby = nothing, group = nothing, color::Symbol = isnothing(group) || group === false ? :amplitude : :group,
        exploded::Bool = false, ncols::Int = 3, plot_tier = LegendDataManagement.DataTier(:raw), subtract_baseline::Bool = true, xunit::Unitful.Units = u"µs", xlims = nothing,
        show_empty_traces::Bool = true, watermark::Bool = true, final::Bool = true, preliminary::Bool = true, approved::Bool = false, production::Bool = true)
    isempty(figure.content) || throw(ArgumentError("`figure` must be empty: the event display takes the whole figure. To show another event in the same figure, fill a display: `d = eventdisplay(data); lplot!(d, evt)`"))
    options = (; system = _system_waveforms(system), lar_energy, lar_cut, energy, aoe, lq, pe_limits, only_processable, filterby, group, color, exploded, ncols, plot_tier, subtract_baseline, xunit, xlims,
        show_empty_traces, watermark, final, preliminary, approved, production)
    EventDisplay(data, figure, options, nothing, @NamedTuple{radius::Float64, height::Float64}[], nothing, nothing, nothing)
end

# Builds the layout of the figure for the channels of `config`; the waveforms get their axes once
# they are read
function _build_event_display!(d::EventDisplay, array, config; logo = FileIO.load(LegendMakie.JuleanaCircle))
    empty!(d.figure)
    (; options) = d
    g = Makie.GridLayout(d.figure[1, 1])
    title = _build_event_title!(g[1, 1:3], logo)

    left = Makie.GridLayout(g[2, 1])
    top_view = _build_event_top_view!(left[1, 1], array, config.geometric)
    key = _build_event_key!(left[2, 1])
    windows = _build_event_windows!(left[3, 1], config.windows, config.cut_window)
    Makie.rowsize!(left, 1, Makie.Aspect(1, 1.0))
    Makie.rowsize!(left, 3, Makie.Fixed(46))
    Makie.rowgap!(left, 4)

    side_view = _build_event_side_view!(g[2, 2], array, config.geometric)

    right = Makie.GridLayout(g[2, 3])
    observables = _build_event_observables!(right[1, 1], config.geometric; options.energy, options.aoe, options.lq)
    Makie.rowgap!(right, 6)

    Makie.colsize!(g, 1, Makie.Relative(0.35))
    Makie.colsize!(g, 2, Makie.Relative(0.21))
    Makie.colgap!(g, 18)
    Makie.rowgap!(g, 6)

    d.plots = (; title, top_view, key, windows, side_view, observables)
    d.waveform_grid = right[2, 1]
    d.waveforms = nothing
    d
end

# Fills everything but the waveforms
function _fill_event_panels!(h, filekey, date, values, array, config, triggers, limits)
    h.title.filekey.text[] = filekey
    h.title.date.text[] = date
    foreach((label, text) -> label.text[] = text, h.observables.event, values.event)
    foreach((label, text) -> label.text[] = text, h.observables.cuts, values.cuts)
    foreach((label, text) -> label.text[] = text, h.observables.triggered, values.triggered)
    _fill_event_top_view!(h.top_view, array, config.geometric, limits)
    _fill_event_side_view!(h.side_view, array, config.geometric, limits)
    _fill_event_windows!(h.windows, triggers, limits)
    _fill_event_key!(h.key, limits)
end

function LegendMakie.lplot!(d::EventDisplay, evt::NamedTuple)
    all(k -> haskey(evt, k), (:tstart, :geds, :spms, :ged_spm, :ged_pmt)) || throw(ArgumentError("`evt` must be a row of an event tier with the columns tstart, geds, spms, ged_spm and ged_pmt, got $(keys(evt))"))
    ts = evt.tstart
    isempty(evt.geds.trig_e_det) && throw(ArgumentError("Event at $ts has no triggered HPGe detector: the event display shows the location of a trigger in the array"))
    fk = LegendDataManagement.find_filekey(d.data, ts)
    fk.category == LegendDataManagement.DataCategory(:phy) || throw(ArgumentError("The event display supports the category phy, got $(fk.category)"))
    (; options) = d

    # All reads of the HDF5 library take its global lock and run one after the other on any number
    # of threads, so the waveforms are read by one task while the other panels are filled. The SiPMs
    # with light depend on the energy type of the configuration.
    read_panels(channels) = Threads.@spawn _event_panels(d.data, fk, ts, options.system; options.only_processable, options.filterby, options.group, options.color, options.exploded, options.plot_tier, options.subtract_baseline, channels)
    panels_task = options.show_empty_traces ? read_panels(nothing) : nothing

    config = _event_configuration(d.data, fk, options.lar_energy, options.lar_cut)
    isnothing(panels_task) && (panels_task = read_panels(_event_signal_channels(evt, config.lar_energy)))
    rebuild = d.key != config.key
    shapes = rebuild ? _detector_shapes(d.data, config.geds.detector) : d.shapes
    array = _event_array(config.geds, config.spms, shapes, evt, config.lar_energy, config.lar, config.geometric.dphi_max)
    triggers = _event_lar_triggers(evt, config.lar_energy, config.lar, getproperty(config.windows, config.cut_window))
    limits = _event_pe_limits(array, triggers, options.pe_limits)
    values = _event_observable_values(evt, array, config; options.energy, options.aoe, options.lq)

    # A failure from here on can leave a partly drawn figure: the key is only set again at the end,
    # so that the next event then builds a new layout.
    d.key = nothing
    d.shapes = shapes
    rebuild && _build_event_display!(d, array, config)
    _fill_event_panels!(d.plots, string(fk), _event_date(ts), values, array, config, triggers, limits)

    panels = fetch(panels_task)
    if !isnothing(d.waveforms) && d.waveforms.key != _panel_key(panels)
        _build_event_display!(d, array, config)
        _fill_event_panels!(d.plots, string(fk), _event_date(ts), values, array, config, triggers, limits)
    end
    isnothing(d.waveforms) && (d.waveforms = _build_event_waveforms!(d.waveform_grid, panels, options))
    _fill_event_waveforms!(d.waveforms, panels, Unitful.ustrip(u"µs", evt.geds.t0_start), config.windows, config.cut_window, options)
    d.key = config.key
    d.figure
end

function LegendMakie.lplot!(data::LegendDataManagement.LegendData, evt::NamedTuple; kwargs...)
    LegendMakie.lplot!(LegendMakie.eventdisplay(data; figure = Makie.current_figure(), kwargs...), evt)
end

function LegendMakie.lplot(data::LegendDataManagement.LegendData, evt::NamedTuple; kwargs...)
    LegendMakie.lplot!(LegendMakie.eventdisplay(data; kwargs...), evt)
end

_read_event(data, tier, ts) = only(LegendDataManagement.read_ldata(data, tier, LegendDataManagement.find_filekey(data, ts), [ts]))

LegendMakie.lplot!(d::EventDisplay, tier::LegendDataManagement.DataTier, ts::Unitful.Time{<:Real}) = LegendMakie.lplot!(d, _read_event(d.data, tier, ts))
LegendMakie.lplot!(data::LegendDataManagement.LegendData, tier::LegendDataManagement.DataTier, ts::Unitful.Time{<:Real}; kwargs...) = LegendMakie.lplot!(data, _read_event(data, tier, ts); kwargs...)
LegendMakie.lplot(data::LegendDataManagement.LegendData, tier::LegendDataManagement.DataTier, ts::Unitful.Time{<:Real}; kwargs...) = LegendMakie.lplot(data, _read_event(data, tier, ts); kwargs...)
LegendMakie.lplot!(d::EventDisplay, ts::Unitful.Time{<:Real}; event_tier = :jlevt) = LegendMakie.lplot!(d, LegendDataManagement.DataTier(event_tier), ts)

LegendMakie.eventdisplay(data::LegendDataManagement.LegendData, evt::NamedTuple; kwargs...) = LegendMakie.lplot(data, evt; kwargs...)
LegendMakie.eventdisplay(data::LegendDataManagement.LegendData, ts::Unitful.Time{<:Real}; event_tier = :jlevt, kwargs...) = LegendMakie.lplot(data, LegendDataManagement.DataTier(event_tier), ts; kwargs...)
