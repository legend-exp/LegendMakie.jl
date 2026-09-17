# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

module LegendMakieLegendDataManagementExt

    import LegendMakie
    import LegendDataManagement

    import Dates
    import Format
    import LegendDataTypes: decode_data
    import Makie
    import Measurements
    import PropDicts
    import TypedTables
    import Unitful
    import RadiationDetectorSignals

    import LegendMakie: parameterplot!
    import Unitful: @u_str

    Makie.@recipe(ParameterPlot, chinfo, pars, properties) do scene
        Makie.Attributes(
            xlabel = "Detector",
            ylabel = missing,
	    label = nothing,
            color = LegendMakie.AchatBlue,
            legend_logo = true,
            juleana_logo = true,
            approved = false,
            ylims = nothing,
            title = ""
        )
    end

    function Makie.plot!(p::ParameterPlot{<:Tuple{<:TypedTables.Table, <:PropDicts.PropDict, <:AbstractVector{Symbol}}})
        
        # get info
        chinfo     = p.chinfo[]
        pars       = p.pars[]
        properties = p.properties[]
        
        # Collect the unit
        u = Unitful.NoUnits
        for det in chinfo.detector
            if haskey(pars, det)
                mval = reduce(getproperty, properties, init = pars[det])
                if !(mval isa PropDicts.MissingProperty)
                    u = Unitful.unit(mval)
                    break
                end
            end
        end

        # collect the data
        labels = Makie.RichText[]
        labelcolors = Symbol[]
        vlines = Int[]
        xvalues = Int[]
        yvalues = []
        notworking = Int[]
        verbose = true
        for s in sort(unique(chinfo.detstring))
            push!(labels, Makie.rich(Format.format("String:{:02d}", s), color = LegendMakie.AchatBlue))
            labelcolor = :blue
            push!(vlines, length(labels))
            for det in sort(chinfo[chinfo.detstring .== s], lt = (a,b) -> a.position < b.position).detector
                push!(xvalues, length(labels))
                existing = false
                if haskey(pars, det)
                    mval = reduce(getproperty, properties, init = pars[det])
                    existing = (mval isa Number && !iszero(Measurements.value(mval)))
                end
                if existing
                    push!(yvalues, Unitful.uconvert(u, mval))
                    push!(labels, Makie.rich(string(det), color=:black))
                else
                    verbose && @warn "No entry $(join(string.(properties), '/')) for detector $(det)"
                    push!(yvalues, NaN * u)
                    push!(notworking, length(labels))
                    push!(labels, Makie.rich(string(det), color=:red))
                end
            
            end
        end
        push!(vlines, length(labels) + 1);
        ylabel = ismissing(p.ylabel[]) ? (length(properties) > 0 ? join(string.(properties), " ") : "Quantity") * ifelse(u == Unitful.NoUnits, "", " ($u)") : p.ylabel[]

        Makie.errorbars!(p, xvalues, Unitful.ustrip.(u, Measurements.value.(yvalues)), Unitful.ustrip.(u, Measurements.uncertainty.(yvalues)), color = p.color)
        Makie.scatter!(p, xvalues, Unitful.ustrip.(u, Measurements.value.(yvalues)), color = p.color, label = p.label)
        Makie.vlines!(p, vlines .- 1, color = :black)

        ax = Makie.current_axis()
        ax.xlabel = p.xlabel[]
        ax.ylabel = ylabel
        ax.xticks = (eachindex(labels) .- 1, labels)
        ax.xticklabelrotation = π/2
        ax.xgridvisible = true
        ax.ygridvisible = true
        ax.limits = ((0, length(labels)), p.ylims[])

        p
    end

    function LegendMakie.lplot!(
            chinfo::TypedTables.Table, pars::PropDicts.PropDict, properties::AbstractVector{Symbol} = Symbol[];
            watermark::Bool = true, kwargs...
        )

        fig = Makie.current_figure()

        # create plot
        ax = Makie.Axis(fig[1,1])
        LegendMakie.parameterplot!(ax, chinfo, pars, properties; kwargs...)

        # add watermarks
        watermark && LegendMakie.add_watermarks!(; kwargs...)

        fig
    end


    # The time of an event: its date and time, and below it the unix time in seconds with every
    # digit a Float64 resolves at the LEGEND epoch, in a smaller regular font
    _event_time(ts::Unitful.Time; fontsize) = Makie.rich(string(Dates.unix2datetime(Unitful.ustrip(u"s", ts))), "\n",
        Makie.rich(Format.format("{:.7f} s", Unitful.ustrip(u"s", ts)); fontsize, font = :regular))

    # The columns of an event read to plot the waveforms `wvfs`: the `presum_rate` a presummed
    # waveform sums over, and with the baseline the FlashCam `baseline` of the trigger.
    _event_columns(wvfs, subtract_baseline::Bool) =
        (wvfs..., (:waveform_presummed in wvfs ? (:presum_rate,) : ())..., (subtract_baseline ? (:baseline,) : ())...)

    # The number of bits the SiPM waveforms drop from every sample; the raw tier does not record it.
    const _bit_drop_bits = 2

    # The waveform `wvf` of the single row of `tbl`, decoded and in the units of one ADC sample:
    # a presummed waveform sums `presum_rate` samples, a bit-dropped one holds the sample shifted
    # right by `_bit_drop_bits`. The FlashCam `baseline` is the level of one ADC sample.
    function _event_waveform(tbl, wvf::Symbol, subtract_baseline::Bool)
        wf = decode_data(only(getproperty(tbl, wvf)))
        signal = wvf == :waveform_presummed ? wf.signal ./ Int(only(tbl.presum_rate)) :
                 wvf == :waveform_bit_drop ? wf.signal .* 2^_bit_drop_bits : wf.signal
        subtract_baseline && (signal = signal .- Int(only(tbl.baseline)))
        RadiationDetectorSignals.RDWaveform(wf.time, signal)
    end

    # The column of the channel information the channels of a system are grouped by, and the name
    # of a grouping in the plot
    const _default_groups = Dict(:geds => :detstring, :spms => :barrel)
    const _group_names = Dict(:detstring => "string", :hvcard => "HV card", :cc4 => "CC4", :barrel => "barrel")
    _group_name(grp::Symbol) = get(_group_names, grp, string(grp))

    # A per-system option: one value for every system, a Dict with the value of each system, or
    # `true` for the default of a system
    _per_system(opt::AbstractDict, sys::Symbol, defaults) = get(opt, sys, nothing)
    _per_system(opt::Bool, sys::Symbol, defaults) = opt ? get(defaults, sys, nothing) : nothing
    _per_system(opt, sys::Symbol, defaults) = opt

    # The group of every channel of `chinfo`: a column of the channel information, or the barrel
    # of a SiPM, the first two characters of its fiber
    _group_values(chinfo, grp::Symbol) = grp == :barrel ?
        [Symbol(first(strip(String(f), '\0'), 2)) for f in chinfo.fiber] : getproperty(chinfo, grp)
    _group_label(v) = strip(string(v), '\0')

    # `n` distinct colors: the tab20 scheme as far as it goes, beyond that a Glasbey scheme
    _categorical_colors(n::Int) = Makie.categorical_colors(n <= 20 ? :tab20 : :glasbey_hv_n256, n)

    # The waveform column of a system drawn when `system` names only the systems
    const _default_waveforms = Dict(:geds => [:waveform_presummed], :spms => [:waveform_bit_drop])
    _system_waveforms(system::AbstractDict) = system
    _system_waveforms(system::Symbol) = _system_waveforms([system])
    _system_waveforms(system::AbstractVector{Symbol}) = Dict(sys => begin
        haskey(_default_waveforms, sys) || throw(ArgumentError("No default waveform for system $sys, give its column as `system = Dict(:$sys => [column])`"))
        _default_waveforms[sys]
    end for sys in system)

    function LegendMakie.lplot!(
            data::LegendDataManagement.LegendData, fk::LegendDataManagement.FileKey, ts::Unitful.Time{<:Real}, det::LegendDataManagement.DetectorIdLike; 
            plot_tier = LegendDataManagement.DataTier(:raw), plot_waveform = [:waveform_presummed], subtract_baseline::Bool = true,
            show_unixtime = false, xunit::Unitful.Units = u"µs", 
            xlims = nothing, show_title::Bool = true, show_label::Bool = true, watermark::Bool = true, final::Bool = true, kwargs...
        )
        det = LegendDataManagement.DetectorId(det)  # convert to DetectorId if necessary
        
        # only the row of the event is read
        raw = LegendDataManagement.read_ldata(_event_columns(plot_waveform, subtract_baseline), data, plot_tier, fk, [ts], det)
        
        # best results for figure size (800,400)
        fig = Makie.current_figure()
        
        g = Makie.GridLayout(fig[1,1])
        ax = Makie.Axis(g[1,1], 
            dim1_conversion = Makie.UnitfulConversion(xunit, units_in_label=false),
            ytickformat = x -> string.(round.(Int,x)), 
            palette = (color = Makie.wong_colors(),), 
            limits = (xlims, nothing), 
            xticks = Makie.WilkinsonTicks(6,k_min=5),
            xlabel = "Time ($xunit)", ylabel = "Signal", 
            titlefont = :regular, 
            title = show_unixtime ? Makie.rich("$(LegendDataManagement.channelinfo(data, fk, det).system) - Event ", _event_time(ts; fontsize = 13)) :
                "$(LegendDataManagement.channelinfo(data, fk, det).system) - Event"
        )
        for (p, p_wvf) in enumerate(plot_waveform)
            label = if show_label && p == 1 
                "$det ($(LegendDataManagement.channelinfo(data, fk, det).channel))"
            end
            LegendMakie.waveformplot!(ax, _event_waveform(raw, p_wvf, subtract_baseline); label)
        end

        # add legend
        Makie.axislegend(ax)

        # add general title
        show_title && Makie.Label(g[1,:,Makie.Top()], "$(fk.setup)-$(fk.period)-$(fk.run)-$(fk.category)", padding = (0,0,36,0), fontsize = 24, font = :bold)

        # add watermarks
        Makie.current_axis!(ax)
        watermark && LegendMakie.add_watermarks!(; final, kwargs...)

        fig
    end

    function LegendMakie.lplot!(data::LegendDataManagement.LegendData, ts::Unitful.Time;
            system = [:geds, :spms], only_processable::Bool = true, filterby = nothing, group = nothing,
            color::Symbol = isnothing(group) || group === false ? :amplitude : :group,
            exploded::Bool = false, ncols::Int = 3, plot_tier = LegendDataManagement.DataTier(:raw),
            subtract_baseline::Bool = true, show_unixtime::Bool = true, xunit::Unitful.Units = u"µs",
            xlims = nothing, show_title::Bool = true, watermark::Bool = true, final::Bool = true, kwargs...)

        fk = LegendDataManagement.find_filekey(data, ts)
        system = _system_waveforms(system)

        # check for valid category
        fk.category in LegendDataManagement.DataCategory.((:cal, :phy)) || throw(ArgumentError("Only `DataCategory` cal and phy are supported"))

        return if fk.category == LegendDataManagement.DataCategory(:cal)
            haskey(system, :geds) || throw(ArgumentError("A cal event plot needs the germanium waveforms in `system`"))
            @debug "Got $(fk.category) event, looking for raw event"
            timestamps = LegendDataManagement.read_ldata(:timestamp, data, LegendDataManagement.DataTier(:raw), fk)
            det_ts = ""
            for det in keys(timestamps)
                if any(ts .== timestamps[det].timestamp)
                    det_ts = string(det)
                    @debug "Found event $ts in detector $det"
                    break
                end
            end
            isempty(det_ts) && throw(ArgumentError("Timestamp $ts not found in the data"))

            det = LegendDataManagement.DetectorId(det_ts)
            chinfo_det = LegendDataManagement.channelinfo(data, fk, det)

            # validate the entry to plot
            chinfo_det.system != :geds && throw(ArgumentError("Only HPGe cal events are supported"))
            only_processable && !chinfo_det.processable && throw(ArgumentError("Detector $det is not processable"))

            fig = LegendMakie.lplot!(data, fk, ts, det; plot_waveform = system[:geds], plot_tier, subtract_baseline, show_unixtime, watermark = false, xlims, kwargs...)
            watermark && LegendMakie.add_watermarks!(; final, kwargs...)

            fig

        elseif fk.category == LegendDataManagement.DataCategory(:phy)
            systems = sort(collect(keys(system)))
            color in (:amplitude, :group, :channel) || throw(ArgumentError("`color` must be :amplitude, :group or :channel, got :$color"))
            (exploded || color == :group) && isnothing(group) && (group = true)

            # one panel per system, or per group of a system when exploded, with the waveforms of
            # the event per waveform column, the color of every channel per column, and the entries
            # of a legend of the colors. The channels of a system are colored as a whole, by the
            # signal amplitude, by their group or one by one.
            panels = []
            for sys in systems
                grp = _per_system(group, sys, _default_groups)
                pf = _per_system(filterby, sys, Dict())
                chinfo = LegendDataManagement.channelinfo(data, fk; system = sys, only_processable, extended = true)
                isnothing(pf) || (chinfo = filter(pf, chinfo))
                if isempty(chinfo)
                    @warn "No $(only_processable ? "processable " : "")channels found for system $sys, skipping waveform plot"
                    continue
                end
                # only the row of the event is read from each channel, keyed by detector
                raw = LegendDataManagement.read_ldata(_event_columns(system[sys], subtract_baseline), data, plot_tier, fk, [ts], chinfo.detector)
                wvfs = [p_wvf => RadiationDetectorSignals.ArrayOfRDWaveforms([_event_waveform(tbl, p_wvf, subtract_baseline) for tbl in raw]) for p_wvf in system[sys]]
                groups = isnothing(grp) ? nothing : _group_values(chinfo, grp)
                (exploded || color == :group) && isnothing(groups) && throw(ArgumentError("No grouping of the channels of system $sys, give one with `group`"))
                colors, legend = if color == :amplitude
                    Dict(p => get(Makie.cgrad(:coolwarm), maximum.(w.signal) .- minimum.(w.signal), :extrema) for (p, w) in wvfs), nothing
                elseif color == :group
                    vals = sort(unique(groups))
                    palette = _categorical_colors(length(vals))
                    Dict(p => palette[indexin(groups, vals)] for (p, _) in wvfs), (_group_name(grp), _group_label.(vals), palette)
                else
                    palette = _categorical_colors(length(chinfo))
                    Dict(p => palette for (p, _) in wvfs), ("detector", string.(chinfo.detector), palette)
                end
                if exploded
                    for v in sort(unique(groups))
                        sel = findall(==(v), groups)
                        # a panel of one group has no legend of the groups, and only its own channels
                        panel_legend = color == :group ? nothing : color == :channel ? (legend[1], legend[2][sel], legend[3][sel]) : nothing
                        push!(panels, (; sys, tag = "$sys: $(_group_name(grp)) $(_group_label(v))",
                            wvfs = [p => w[sel] for (p, w) in wvfs], colors = Dict(p => c[sel] for (p, c) in colors), legend = panel_legend))
                    end
                else
                    push!(panels, (; sys, tag = string(sys), wvfs, colors, legend))
                end
            end
            isempty(panels) && throw(ArgumentError("No channels to plot for event $ts"))

            # without limits, the time range of the germanium waveforms, or of every waveform
            if isnothing(xlims)
                ref = filter(p -> p.sys == :geds, panels)
                isempty(ref) && (ref = panels)
                xlims = Unitful.ustrip.(xunit, extrema(t for p in ref for (_, w) in p.wvfs for wf in w for t in extrema(wf.time)))
            end

            # the panels of a system fill `ncols` columns, each system starting a new row
            ncols = exploded ? ncols : 1
            pos = Tuple{Int, Int}[]
            row = col = 0
            for (i, p) in enumerate(panels)
                if i == 1 || p.sys != panels[i-1].sys || col == ncols
                    row += 1
                    col = 0
                end
                col += 1
                push!(pos, (row, col))
            end

            fig = Makie.current_figure()
            g = Makie.GridLayout(fig[1,1])
            axs = map(panels, pos) do p, (r, c)
                ax = Makie.Axis(g[r, c],
                    ytickformat = x -> string.(round.(Int,x)),
                    palette = (color = Makie.wong_colors(),),
                    limits = (xlims ,nothing),
                    xticks = Makie.WilkinsonTicks(6,k_min=5),
                    xlabel = "Time ($xunit)", ylabel = "Signal"
                )
                # one line per channel
                for (p_wvf, w) in p.wvfs
                    Makie.series!(ax, Unitful.ustrip.(xunit, first(w).time), stack(w.signal)', solid_color = p.colors[p_wvf])
                end
                if !isnothing(p.legend)
                    title, labels, palette = p.legend
                    Makie.axislegend(ax, [Makie.LineElement(color = c) for c in palette], labels, title,
                        position = :rt, nbanks = cld(length(labels), 8), labelsize = 12, titlesize = 12, rowgap = 0, padding = 4, backgroundcolor = :white)
                end
                Makie.text!(ax, 0.02, 0.95, text = p.tag, space = :relative, align = (:left, :top), font = :bold, fontsize = 18)
                ax
            end

            runkey = "$(fk.setup)-$(fk.period)-$(fk.run)-$(fk.category)"
            show_title && Makie.Label(g[1,:,Makie.Top()], show_unixtime ? Makie.rich("$runkey - ", _event_time(ts; fontsize = 16)) : runkey,
                padding = (0,0,36,0), fontsize = 24, font = :bold)

            # the panels share the time axis and the panels of a system the signal axis; a panel
            # with another one to its left shows no signal tick labels, one with another one of
            # its system below it (of any system in a single column) no time tick labels
            for (i, (r, c)) in enumerate(pos)
                below = any(j -> pos[j] == (r + 1, c) && (!exploded || panels[j].sys == panels[i].sys), eachindex(panels))
                below && Makie.hidexdecorations!(axs[i], grid = false, ticks = false)
                c > 1 && Makie.hideydecorations!(axs[i], grid = false, ticks = false)
            end
            Makie.linkxaxes!(axs...)
            for sys in systems
                sel = findall(p -> p.sys == sys, panels)
                length(sel) > 1 && Makie.linkyaxes!(axs[sel]...)
            end
            Makie.rowgap!(g, 0)
            Makie.colgap!(g, 0)

            # align ylabels
            left = axs[findall(((r, c),) -> c == 1, pos)]
            yspace = maximum(Makie.tight_yticklabel_spacing!, (left...,))
            for a in left; a.yticklabelspace = yspace; end

            # the watermarks sit beside the last panel of the first row
            Makie.current_axis!(axs[findlast(((r, c),) -> r == 1, pos)])
            watermark && LegendMakie.add_watermarks!(; final, kwargs...)

            fig
        end
    end


    function LegendMakie.lplot!(data::LegendDataManagement.LegendData, ts::Unitful.Time{<:Real}, det::LegendDataManagement.DetectorIdLike; kwargs...)
        fk = LegendDataManagement.find_filekey(data, ts)
        det = LegendDataManagement.DetectorId(det)  # convert to DetectorId if necessary
        LegendMakie.lplot!(data, fk, ts, det; kwargs...)
    end

    # TODO: check rounding of `Dates.DateTime`
    function LegendMakie.lplot!(data::LegendDataManagement.LegendData, ts::Dates.DateTime, args...; kwargs...)
        LegendMakie.lplot!(data, Dates.datetime2unix(ts)*u"s", args...; kwargs...)
    end

    # the event plots have their own default figure sizes
    function LegendMakie.lplot(data::LegendDataManagement.LegendData, ts::Union{Unitful.Time, Dates.DateTime}; exploded::Bool = false, figsize = exploded ? (1200, 900) : (800, 600), kwargs...)
        fig = Makie.Figure(size = figsize)
        LegendMakie.lplot!(data, ts; exploded, kwargs...)
        fig
    end
    function LegendMakie.lplot(data::LegendDataManagement.LegendData, ts::Union{Unitful.Time, Dates.DateTime}, det::LegendDataManagement.DetectorIdLike; figsize = (800, 400), kwargs...)
        fig = Makie.Figure(size = figsize)
        LegendMakie.lplot!(data, ts, det; kwargs...)
        fig
    end

end
