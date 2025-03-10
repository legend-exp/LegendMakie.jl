# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

module LegendMakieLegendDataManagementExt

    import LegendMakie

    import Format
    import Makie
    import Measurements
    import PropDicts
    import TypedTables
    import Unitful

    import LegendMakie: parameterplot!


    Makie.@recipe(ParameterPlot, chinfo, pars, properties) do scene
        Makie.Attributes(
            xlabel = "Detector",
            ylabel = missing,
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
        Makie.scatter!(p, xvalues, Unitful.ustrip.(u, Measurements.value.(yvalues)), color = p.color)
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

end