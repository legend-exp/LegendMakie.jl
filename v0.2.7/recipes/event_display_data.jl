# Writes what `eventdisplay` reads for the page `event_display_lit.jl`. All of it is made up: a copy
# of the metadata of LegendTestData with an array of 8 HPGe strings and 2 SiPM barrels, a LAr
# configuration, a raw tier of random waveforms, and the event rows `evts`.

using Dates, LegendDataManagement, LegendHDF5IO, LegendTestData, PropDicts, Random
using RadiationDetectorSignals, TypedTables, Unitful, YAML

Random.seed!(42)

testdata_dir = joinpath(legend_test_data_path(), "data", "legend")
docsdir = mkpath(joinpath(mktempdir(), "docs-data")) # named in the production tag of the plots
metadata = joinpath(docsdir, "metadata")
cp(joinpath(testdata_dir, "metadata"), metadata)
chmod(metadata, 0o755, recursive = true)
hardware = joinpath(metadata, "hardware")

quantity(val, unit) = Dict("val" => val, "unit" => unit)
# In the metadata, y grows against the azimuth
coordinates(radius, angle, z) = Dict(
    "x" => quantity(radius * cosd(angle), "mm"), "y" => quantity(-radius * sind(angle), "mm"),
    "z" => quantity(z, "mm"), "radius" => quantity(radius, "mm"), "angle" => quantity(angle, "°"))

# The `string`, `position` and shape of the HPGe detectors. The test data holds V99000A at the top
# of string 1 and B99000A at the top of string 4, the latter switched off.
string_angle(s) = 22.5 + 45 * (s - 1)
heights = [80.0, 65.0, 40.0, 90.0, 55.0]
string_heights = [[80.0; heights[1:4]], heights[1:3], heights[1:4], [40.0; heights[2:4]], heights[1:4], heights[1:3], heights[1:5], heights[2:4]]
hpge = [(; name = (s, p) == (1, 1) ? "V99000A" : (s, p) == (4, 1) ? "B99000A" : "V99$(s)0$(p)A", string = s, position = p, height = hs[p],
        radius = (s, p) == (4, 1) ? 40.0 : 35.0, z = -350.0 - sum(hs[1:p-1]; init = 0.0) - 15.0 * (p - 1) - hs[p] / 2)
    for (s, hs) in enumerate(string_heights) for p in eachindex(hs)]

# The SiPMs of a barrel sit in modules around the array, each with one SiPM at the top and one at the bottom
modules = [(; barrel = "inner", radius = 90.0, angle = 72.0 * (m - 1), fiber = "IB$(lpad(2m - 1, 3, '0'))$(lpad(2m, 3, '0'))") for m in 1:5]
append!(modules, [(; barrel = "outer", radius = 310.0, angle = 30.0 * (m - 1), fiber = "OB$(lpad(2m - 1, 3, '0'))$(lpad(2m, 3, '0'))") for m in 1:12])
sipms = [(; name = "S$(lpad(2i - 2 + j, 3, '0'))", m..., position, z = position == "top" ? (m.barrel == "inner" ? -130.0 : -80.0) : (m.barrel == "inner" ? -1180.0 : -1230.0))
    for (i, m) in enumerate(modules) for (j, position) in enumerate(("top", "bottom"))]

# The channel map and the statuses of the run gain the channels that the test data does not hold
ged_channel(d, rawid) = Dict("name" => d.name, "system" => "geds", "location" => Dict("string" => d.string, "position" => d.position),
    "daq" => Dict("crate" => 0, "card" => Dict("id" => 1, "address" => "0x234", "serialno" => nothing), "channel" => mod(rawid, 16), "fcid" => rawid - 1234500, "rawid" => rawid),
    "voltage" => Dict("card" => Dict("id" => 2, "serialno" => nothing), "channel" => mod(rawid, 16), "filter" => Dict("id" => nothing, "channel" => nothing)),
    "electronics" => Dict("cc4" => Dict("id" => "C$(d.string)", "channel" => d.position)))
spm_channel(d, rawid) = Dict("name" => d.name, "system" => "spms", "location" => Dict("fiber" => d.fiber, "position" => d.position),
    "daq" => Dict("crate" => 2, "card" => Dict("id" => 10, "address" => "0x100", "serialno" => nothing), "channel" => mod(rawid, 48), "fcid" => rawid - 1234500, "rawid" => rawid))
new_hpge = filter(d -> d.name ∉ ("V99000A", "B99000A"), hpge)
channelmap = joinpath(hardware, "configuration", "channelmaps", "l200-p02-r%-T%-all-config.yaml")
channels = merge(YAML.load_file(channelmap),
    Dict(d.name => ged_channel(d, 1234570 + i) for (i, d) in pairs(new_hpge)),
    Dict(d.name => spm_channel(d, 1234620 + i) for (i, d) in pairs(sipms)))
YAML.write_file(channelmap, channels)

statuses_file = joinpath(metadata, "datasets", "statuses", "l200-p02-r006-T%-all-config.yaml")
YAML.write_file(statuses_file, merge(YAML.load_file(statuses_file),
    Dict(d.name => Dict("processable" => true, "usability" => "on", "psd" => Dict("status" => Dict("low_aoe" => "valid"))) for d in new_hpge),
    Dict(d.name => Dict("processable" => true, "usability" => "on") for d in sipms)))

# The shape of the crystals, from the entry of V99000A
diodes = joinpath(hardware, "detectors", "germanium", "diodes")
for d in new_hpge
    diode = YAML.load_file(joinpath(diodes, "V99000A.yaml"))
    diode["name"] = d.name
    diode["geometry"]["height_in_mm"] = d.height
    diode["geometry"]["radius_in_mm"] = d.radius
    diode["geometry"]["taper"]["top"]["height_in_mm"] = 0.75 * d.height
    YAML.write_file(joinpath(diodes, "$(d.name).yaml"), diode)
end

# `hardware/geometry`: the position of every HPGe detector and SiPM. `z` is the center of a crystal.
function write_validity_entries(dir, name, entries)
    mkpath(dir)
    YAML.write_file(joinpath(dir, "validity.yaml"), [Dict("valid_from" => "20200101T000000Z", "category" => "all", "mode" => "reset", "apply" => ["$name.yaml"])])
    YAML.write_file(joinpath(dir, "$name.yaml"), entries)
end
write_validity_entries(joinpath(hardware, "geometry", "hpge"), "hpge-geometry",
    Dict(d.name => Dict("string" => d.string, "position" => d.position, "coordinates" => coordinates(200.0, string_angle(d.string), d.z)) for d in hpge))
write_validity_entries(joinpath(hardware, "geometry", "spms"), "spms-geometry",
    Dict(d.name => Dict("barrel" => d.barrel, "fiber" => d.fiber, "position" => d.position, "coordinates" => coordinates(d.radius, d.angle, d.z)) for d in sipms))

# The LAr cut of the event tier: the windows around the HPGe t0 and the cuts over all SiPMs and over
# the SiPMs close to a triggered string
windows = (prompt = (-2.0, 1.0), delayed = (1.0, 6.0), full = (-2.0, 6.0))
dphi_geom = 30.0
lar_cut_entry(dphi_outer) = Dict("window" => "full", "dphi_max" => Dict("inner" => quantity(180.0, "°"), "outer" => quantity(dphi_outer, "°")))
write_validity_entries(joinpath(metadata, "dataprod", "config", "evt"), "evt", Dict("spms" => Dict("lar_cut" => Dict(
    "energy_types" => Dict("trig_max_trap_cal" => Dict("pos" => "trig_pos_trap", "is_dc" => "trig_max_trap_is_dc")),
    "windows" => Dict(string(k) => quantity(collect(w), "µs") for (k, w) in pairs(windows)),
    "spm_windows" => ["prompt", "delayed"],
    "cuts" => Dict("all" => lar_cut_entry(180.0), "geom" => lar_cut_entry(dphi_geom)),
    "is_valid_lar" => "!trig_max_trap_cal_all_lar_cut"))))

config = PropDict(:setups => PropDict(:l200 => PropDicts.readprops(joinpath(testdata_dir, "dataflow-config.yaml"))))
config.setups.l200.paths[Symbol("tier/raw")] = joinpath(docsdir, "raw")
config.setups.l200.paths[:metadata] = metadata
PropDicts.writeprops(joinpath(docsdir, "config.json"), config)
ENV["LEGEND_DATA_CONFIG"] = joinpath(docsdir, "config.json")
l200 = LegendData(:l200)
filekey = start_filekey(l200, :p02, :r006, :phy)

# Two events: `triggers` holds the energy of each triggered HPGe detector, `light` the time relative
# to the HPGe t0 in µs and the photoelectrons of the pulses of a SiPM, some of them outside the windows.
t0 = 48.0
t_ged = range(0.0u"µs", 100.0u"µs", length = 1000)
t_spm = range(0.0u"µs", 100.0u"µs", length = 6250)
event_time(i) = datetime2unix(DateTime(filekey))u"s" + 100.0u"s" * i
event_inputs = [
    (triggers = Dict("V99302A" => 1460.8), light = Dict("S017" => [(0.1, 6.2), (2.4, 1.3)], "S018" => [(0.3, 2.8)], "S021" => [(-0.6, 3.5)], "S022" => [(1.2, 1.1)], "S003" => [(0.0, 1.6)], "S030" => [(-20.0, 1.2)]),
        is_valid_lar = false, is_valid_muon = true, is_valid_qc = true, is_valid_psd = true),
    (triggers = Dict("V99202A" => 583.2, "V99602A" => 1204.5), light = Dict("S034" => [(-30.0, 1.4)]),
        is_valid_lar = true, is_valid_muon = true, is_valid_qc = true, is_valid_psd = false),
]

# A charge pulse in a germanium detector, a light pulse in a SiPM
ged_pulse(t, t_start) = t < t_start ? 0.0 : (1 - exp(-(t - t_start) / 0.25u"µs")) * exp(-(t - t_start) / 150u"µs")
spm_pulse(t, t_start) = t < t_start ? 0.0 : exp(-(t - t_start) / 0.3u"µs")

mkpath(dirname(l200.tier[:raw, filekey]))
lh5open(l200.tier[:raw, filekey], "w") do h
    timestamp = event_time.(eachindex(event_inputs))
    for d in hpge
        energies = [get(e.triggers, d.name, 0.0) for e in event_inputs]
        offset = 30 * randn()
        h["raw/$(d.name)"] = Table(; timestamp, baseline = fill(UInt16(14000), 2), presum_rate = fill(UInt16(8), 2),
            waveform_presummed = [RDWaveform(t_ged, 8 .* (14000 .+ offset .+ 3 * e .* ged_pulse.(t_ged, t0 * u"µs") .+ 5 .* randn(length(t_ged)))) for e in energies])
    end
    for d in sipms
        h["raw/$(d.name)"] = Table(; timestamp, baseline = fill(UInt16(15000), 2),
            waveform_bit_drop = [RDWaveform(t_spm, round.(Int32, (15000 .+ sum((30 * pe .* spm_pulse.(t_spm, (t0 + dt) * u"µs") for (dt, pe) in get(e.light, d.name, [])); init = zeros(length(t_spm))) .+ randn(length(t_spm))) ./ 4)) for e in event_inputs])
    end
end

# The row of an event tier holds the channels of the event, here all but the switched-off B99000A
function event_row(i, e)
    geds = filter(d -> d.name != "B99000A", hpge)
    detector = DetectorId.(Symbol.(getproperty.(geds, :name)))
    idxs = [findfirst(==(DetectorId(Symbol(name))), detector) for name in sort(collect(keys(e.triggers)))]
    energies = [get(e.triggers, d.name, 0.0) for d in geds] .* u"keV"
    spm_names = getproperty.(sipms, :name)
    pulses = [get(e.light, name, Tuple{Float64, Float64}[]) for name in spm_names]
    in_window(w, name) = sum((pe for (dt, pe) in get(e.light, name, Tuple{Float64, Float64}[]) if first(w) <= dt < last(w)); init = 0.0)
    trig_angles = [string_angle(hpge[findfirst(d -> d.name == name, hpge)].string) for name in keys(e.triggers)]
    in_geom(d) = d.barrel == "inner" || any(a -> abs(mod(d.angle - a + 180, 360) - 180) <= dphi_geom, trig_angles)
    full = [in_window(windows.full, name) for name in spm_names]
    geom = [in_geom(d) ? pe : 0.0 for (d, pe) in zip(sipms, full)]
    (tstart = event_time(i),
        geds = (; detector, t0_start = t0 * u"µs", trig_e_det = detector[idxs], trig_e_det_idxs = idxs, trig_e_cusp_ctc_cal = energies[idxs],
            e_cusp_ctc_cal = energies, aoe_sg_classifier = 0.2 .* randn(length(geds)), lq80_250025_classifier = 1.5 .* randn(length(geds)),
            e.is_valid_qc, e.is_valid_psd),
        spms = (detector = DetectorId.(Symbol.(spm_names)), trig_max_trap_cal = [last.(p) for p in pulses], trig_pos_trap = [(t0 .+ first.(p)) .* u"µs" for p in pulses], trig_max_trap_is_dc = [falses(length(p)) for p in pulses]),
        ged_spm = (; e.is_valid_lar, trig_max_trap_cal_spms_full_pe_sum = sum(full), trig_max_trap_cal_spms_full_multiplicity = count(>(0), full),
            trig_max_trap_cal_spms_geom_full_pe_sum = sum(geom), trig_max_trap_cal_spms_geom_full_multiplicity = count(>(0), geom),
            spm = (detector = DetectorId.(Symbol.(spm_names)), trig_max_trap_cal_prompt_pe_sum = [in_window(windows.prompt, name) for name in spm_names],
                trig_max_trap_cal_delayed_pe_sum = [in_window(windows.delayed, name) for name in spm_names])),
        ged_pmt = (; e.is_valid_muon))
end
evts = [event_row(i, e) for (i, e) in pairs(event_inputs)]
nothing
