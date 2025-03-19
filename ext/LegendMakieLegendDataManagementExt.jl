# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

module LegendMakieLegendDataManagementExt

    import LegendMakie
    import LegendDataManagement

    import Dates
    import Format
    import Makie
    import Measurements
    import PropDicts
    import TypedTables
    import Unitful

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


    function LegendMakie.lplot!(
            data::LegendDataManagement.LegendData, fk::LegendDataManagement.FileKey, ts::Unitful.Time{<:Real}, ch::LegendDataManagement.ChannelIdLike; 
            plot_tier = LegendDataManagement.DataTier(:raw), plot_waveform = [:waveform_presummed], show_unixtime = false, xunit::Unitful.Units = u"µs", 
            xlims = nothing, show_title::Bool = true, show_label::Bool = true, watermark::Bool = true, final::Bool = true
        )
        
        raw = LegendDataManagement.read_ldata(data, plot_tier, fk, ch)
        idx = findfirst(isequal(ts), raw.timestamp)
        
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
            title = "$(LegendDataManagement.channelinfo(data, fk, ch).system) - Event" * (show_unixtime ? " $(Dates.unix2datetime(Unitful.ustrip(u"s", ts)))" : "")
        )
        for (p, p_wvf) in enumerate(plot_waveform)
            label = if show_label && p == 1 
                "$(LegendDataManagement.channelinfo(data, fk, ch).detector) ($(ch))"
            end
            LegendMakie.waveformplot!(ax, getproperty(raw, p_wvf)[idx]; label)
        end

        # add legend
        Makie.axislegend(ax)

        # add general title
        show_title && Makie.Label(g[1,:,Makie.Top()], "$(fk.setup)-$(fk.period)-$(fk.run)-$(fk.category)", padding = (0,0,36,0), fontsize = 24, font = :bold)

        # add watermarks
        Makie.current_axis!(ax)
        watermark && LegendMakie.add_watermarks!(; final)

        fig
    end

    function LegendMakie.lplot!(data::LegendDataManagement.LegendData, ts::Unitful.Time; 
            system=Dict{Symbol, Vector{Symbol}}([:geds, :spms] .=> [[:waveform_presummed], [:waveform_bit_drop]]), 
            only_processable=true, plot_tier=LegendDataManagement.DataTier(:raw), show_unixtime=false, xunit::Unitful.Units = u"µs",
            xlims = nothing, show_title::Bool = true, watermark::Bool = true, final::Bool = true, kwargs...)
        
        fk = LegendDataManagement.find_filekey(data, ts)

        # check for valid category
        fk.category in LegendDataManagement.DataCategory.((:cal, :phy)) || throw(ArgumentError("Only `DataCategory` cal and phy are supported"))
        
        return if fk.category == LegendDataManagement.DataCategory(:cal)
            @debug "Got $(fk.category) event, looking for raw event"
            timestamps = LegendDataManagement.read_ldata(:timestamp, data, LegendDataManagement.DataTier(:raw), fk)
            ch_ts = ""
            for ch in keys(timestamps)
                if any(ts .== timestamps[ch].timestamp)
                    ch_ts = string(ch)
                    @debug "Found event $ts in channel $ch"
                    break
                end
            end
            isempty(ch_ts) && throw(ArgumentError("Timestamp $ts not found in the data"))
            
            ch = LegendDataManagement.ChannelId(ch_ts)
            chinfo_ch = LegendDataManagement.channelinfo(data, fk, ch)
            
            # validate the entry to plot
            chinfo_ch.system != :geds && throw(ArgumentError("Only HPGe cal events are supported"))
            only_processable && !chinfo_ch.processable && throw(ArgumentError("Channel $ch is not processable"))

            fig = LegendMakie.lplot!(data, fk, ts, ch; plot_waveform = system[:geds], plot_tier, show_unixtime, watermark = false, xlims, kwargs...)
            watermark && LegendMakie.add_watermarks!(; final)
                        
            fig
            
        elseif fk.category == LegendDataManagement.DataCategory(:phy)
            raw = LegendDataManagement.read_ldata(data, plot_tier, fk)
            
            fig = Makie.current_figure()          
            g = Makie.GridLayout(fig[1,1])
            axs = [ begin
                ax = Makie.Axis(g[s,1], 
                    dim1_conversion = Makie.UnitfulConversion(xunit, units_in_label=false),
                    ytickformat = x -> string.(round.(Int,x)), 
                    palette = (color = Makie.wong_colors(),), 
                    limits = (xlims ,nothing), 
                    xticks = Makie.WilkinsonTicks(6,k_min=5),
                    xlabel = "Time ($xunit)", ylabel = "Signal", 
                    titlefont = :regular, 
                    title = "$sys - Event" * (show_unixtime ? " $(Dates.unix2datetime(Unitful.ustrip(u"s", ts)))" : "")
                )
                chinfo = LegendDataManagement.channelinfo(data, fk; system=sys, only_processable=true)
                for (c, chinfo_ch) in enumerate(chinfo)
                    for (p, p_wvf) = enumerate(system[sys])
                        idx = findfirst(isequal(ts), raw[Symbol(chinfo_ch.channel)].timestamp)
                        LegendMakie.waveformplot!(ax, getproperty(raw[Symbol(chinfo_ch.channel)], p_wvf)[idx])
                    end
                end
                ax
            end for (s,sys) in enumerate(sort(collect(keys(system))))]

            show_title && Makie.Label(g[1,:,Makie.Top()], "$(fk.setup)-$(fk.period)-$(fk.run)-$(fk.category)", padding = (0,0,36,0), fontsize = 24, font = :bold)

            # link xaxes
            for a in axs[begin:end-1]
                a.xlabel = ""
                #ax.xticksize = 0
                a.xticklabelsize = 0
            end
            Makie.linkxaxes!(axs...)

            # align ylabels
            yspace = maximum(Makie.tight_yticklabel_spacing!, (axs...,))
            for a in axs; a.yticklabelspace = yspace; end
                                                
            Makie.current_axis!(first(axs))
            watermark && LegendMakie.add_watermarks!(; final)

            fig
        end
    end


    function LegendMakie.lplot!(data::LegendDataManagement.LegendData, ts::Unitful.Time{<:Real}, ch::LegendDataManagement.ChannelIdLike; kwargs...)
        fk = LegendDataManagement.find_filekey(data, ts)
        LegendMakie.lplot!(data, fk, ts, ch; kwargs...)
    end

    # TODO: check rounding of `Dates.DateTime`
    function LegendMakie.lplot!(data::LegendDataManagement.LegendData, ts::Dates.DateTime, args...; kwargs...)
        LegendMakie.lplot!(data, Dates.datetime2unix(ts)*u"s", args...; kwargs...)
    end

end
