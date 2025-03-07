# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

module LegendMakieLegendSpecFitsExt

    import LegendMakie

    import KernelDensity
    import LaTeXStrings
    import Makie
    import Measurements
    import StatsBase
    import Unitful

    import LegendMakie: pt, aoecorrectionplot!, energycalibrationplot!
    import Unitful: @u_str

    # Default color palette
    function get_default_color(i::Int)
        colors = Makie.wong_colors()
        colors[(i - 1) % end + 1]
    end

    function round_wo_units(x::Unitful.RealOrRealQuantity; digits::Int=2)
        Unitful.unit(x) == Unitful.NoUnits ? round(x; digits) : round(Unitful.unit(x), x; digits)
    end

    # function to compose labels when errorbars are scaled
    function label_errscaling(xerrscaling::Real, yerrscaling::Real = 1)
        result = String[]
        xerrscaling != 1 && push!(result, "x-Error ×$(xerrscaling)")
        yerrscaling != 1 && push!(result, "y-Error ×$(yerrscaling)")
        isempty(result) ? "" : " ($(join(result,", ")))"
    end


    Makie.@recipe(AoECorrectionPlot, report) do scene
        Makie.Attributes(
            color = (LegendMakie.AchatBlue,0.5),
            markercolor = :black
        )
    end
    
    # Needed for creatings legend using Makie recipes
    # https://discourse.julialang.org/t/makie-defining-legend-output-for-a-makie-recipe/121567
    function Makie.get_plots(p::AoECorrectionPlot)
        return p.plots
    end
    
    function Makie.plot!(p::AoECorrectionPlot{<:Tuple{NamedTuple{(:par, :f_fit, :x, :y, :gof, :e_unit, :label_y, :label_fit)}}})
        report = p.report[]
        Makie.lines!(p, 0:1:3000, report.f_fit ∘ Measurements.value, color = p.color, label = LaTeXStrings.latexstring("\\fontfamily{Roboto}" * report.label_fit))
        Makie.errorbars!(p, report.x, Measurements.value.(report.y), Measurements.uncertainty.(report.y), color = p.markercolor)
        Makie.scatter!(p, report.x, Measurements.value.(report.y), color = p.markercolor, label = "Compton band fits: Gaussian $(report.label_y)(A/E)")
        p
    end


    Makie.@recipe(EnergyCalibrationPlot, report, additional_pts) do scene
        Makie.Attributes(
            color = LegendMakie.AchatBlue,
            plot_ribbon = true,
            xerrscaling = 1,
            yerrscaling = 1
        )
    end

    # Needed for creatings legend using Makie recipes
    # https://discourse.julialang.org/t/makie-defining-legend-output-for-a-makie-recipe/121567
    function Makie.get_plots(p::EnergyCalibrationPlot)
        return p.plots
    end
    
    function Makie.plot!(p::EnergyCalibrationPlot{<:Tuple{<:NamedTuple{(:par, :f_fit, :x, :y, :gof)}, <:NamedTuple}})
        
        report = p.report[]
        additional_pts = p.additional_pts[]
        xerrscaling = p.xerrscaling[]
        yerrscaling = p.yerrscaling[]

        # plot fit
        xfit = 0:1:1.2*Measurements.value(maximum(report.x))
        yfit = report.f_fit.(xfit)
        yfit_m = Measurements.value.(yfit)
        Makie.lines!(xfit, yfit_m, label = "Best Fit" * (!isempty(report.gof) ? " (p = $(round(report.gof.pvalue, digits=2))| χ²/ndf = $(round(report.gof.chi2min, digits=2)) / $(report.gof.dof))" : ""), color = p.color)
        if p.plot_ribbon[]
            Δyfit = Measurements.uncertainty.(yfit)
            Makie.band!(xfit, yfit_m .- Δyfit, yfit_m .+ Δyfit, color = (p.color[], 0.2))
        end
        
        # scatter points with error bars
        xvalues = Measurements.value.(report.x)
        yvalues = Measurements.value.(report.y)
        Makie.errorbars!(p, xvalues, yvalues, Measurements.uncertainty.(report.x) .* xerrscaling, direction = :x, color = :black)
        Makie.errorbars!(p, xvalues, yvalues, Measurements.uncertainty.(report.y) .* yerrscaling, color = :black)
        Makie.scatter!(p, xvalues, yvalues, marker = :circle, color = :black, label = "Data" * label_errscaling(xerrscaling, yerrscaling))
        
        # plot additional points
        if !isempty(additional_pts)
            xvalues = Measurements.value.(additional_pts.x)
            yvalues = Measurements.value.(additional_pts.y)
            Makie.errorbars!(p, xvalues, yvalues, Measurements.uncertainty.(additional_pts.x) .* xerrscaling, direction = :x, color = :black)
            Makie.errorbars!(p, xvalues, yvalues, Measurements.uncertainty.(additional_pts.y) .* yerrscaling, color = :black)
            Makie.scatter!(p, xvalues, yvalues, marker = :circle, color = :silver, strokewidth = 1, strokecolor = :black, label = "Data not used for fit" * label_errscaling(xerrscaling, yerrscaling))
        end

        p
    end


    function LegendMakie.lplot!(
            report::NamedTuple{(:par, :f_fit, :x, :y, :gof)};
            additional_pts::NamedTuple = NamedTuple(),
            xlims = (0, 1.2*Measurements.value(maximum(report.x))), ylims = nothing,
            xlabel = "Energy (ADC)", ylabel = "Energy (calibrated)", title::AbstractString = "",
            show_residuals::Bool = true, plot_ribbon::Bool = true, legend_position = :lt,
            xerrscaling::Real = 1, yerrscaling::Real = 1, row::Int = 1, col::Int = 1,
            watermark::Bool = true, final::Bool = !isempty(title), kwargs...
        )
        
        fig = Makie.current_figure()
            
        g = Makie.GridLayout(fig[row,col])
        ax = Makie.Axis(g[1,1],
            title = title,
            limits = (xlims, ylims),
            xlabel = xlabel, ylabel = ylabel,
        )
        
        LegendMakie.energycalibrationplot!(ax, report, additional_pts; plot_ribbon, xerrscaling, yerrscaling)
        legend_position != :none && Makie.axislegend(ax, position = legend_position)
        
        if !isempty(report.gof) && show_residuals

            ax.xticklabelsize = 0
            ax.xticksize = 0
            ax.xlabel = ""

            ax2 = Makie.Axis(g[2,1], yticks = -3:3:3, limits = (xlims,(-5,5)), xlabel = xlabel, ylabel = "Residuals (σ)")
            LegendMakie.residualplot!(ax2, (x = Measurements.value.(report.x), residuals_norm = report.gof.residuals_norm))
            # add the additional points
            if !isempty(additional_pts)
                Makie.scatter!(ax2, Measurements.value.(additional_pts.x), additional_pts.residuals_norm, 
                        marker = :circle, color = :silver, strokewidth = 1, strokecolor = :black)
            end

            # link axis and put plots together
            Makie.linkxaxes!(ax, ax2)
            Makie.rowgap!(g, 0)
            Makie.rowsize!(g, 1, Makie.Auto(4))

            # align ylabels
            yspace = maximum(Makie.tight_yticklabel_spacing!, (ax, ax2))
            ax.yticklabelspace = yspace
            ax2.yticklabelspace = yspace
        end

        # add watermarks
        Makie.current_axis!(ax)
        watermark && LegendMakie.add_watermarks!(; final, kwargs...)

        fig
    end


    function LegendMakie.lplot!(
            report::NamedTuple{(:par, :f_fit, :x, :y, :gof, :e_unit, :type)}; 
            additional_pts::NamedTuple = NamedTuple(), kwargs...
        )

        if report.type != :cal
            @warn "Unknown calibration type $(report.type), no plot generated."
            return Makie.current_figure()
        end
                 
        LegendMakie.lplot!(
            report[(:par, :f_fit, :x, :y, :gof)],
            additional_pts = if !isempty(additional_pts)
                # strip the units from the additional points
                μ_strip = Unitful.unit(first(additional_pts.μ)) != Unitful.NoUnits ? Unitful.ustrip.(report.e_unit, additional_pts.μ) : additional_pts.μ
                p_strip = Unitful.unit(first(additional_pts.peaks)) != Unitful.NoUnits ? Unitful.ustrip.(report.e_unit, additional_pts.peaks) : additional_pts.peaks    
                μ_cal = report.f_fit.(μ_strip)
                (x = μ_strip, y = p_strip, residuals_norm = (Measurements.value.(μ_cal) .- Measurements.value.(p_strip))./ Measurements.uncertainty.(μ_cal))
            else
                NamedTuple()
            end,
            xlabel = "Energy (ADC)", ylabel = "Energy ($(report.e_unit))", xlims = (0, 1.1*Measurements.value(maximum(report.x))); kwargs...
        )
    end

    function LegendMakie.lplot!(
            report::NamedTuple{(:par, :f_fit, :x, :y, :gof, :e_unit, :qbb, :type)};
            additional_pts::NamedTuple = NamedTuple(), xlims = (0,3000), title::AbstractString = "",
            kwargs...
        )
        
        if report.type != :fwhm
            @warn "Unknown calibration type $(report.type), no plot generated."
            return Makie.current_figure()
        end

        fig = LegendMakie.lplot!(
            report[(:par, :f_fit, :x, :y, :gof)],
            additional_pts = if !isempty(additional_pts)
                fwhm_cal = report.f_fit.(Unitful.ustrip.(additional_pts.peaks))
                (x = Unitful.ustrip.(report.e_unit, additional_pts.peaks), y = Unitful.ustrip.(report.e_unit, additional_pts.fwhm),
                    residuals_norm = (Measurements.value.(fwhm_cal .- Unitful.ustrip.(report.e_unit, additional_pts.fwhm))) ./ Measurements.uncertainty.(fwhm_cal))
            else
                NamedTuple()
            end,
            xlabel = "Energy ($(report.e_unit))", ylabel = "FWHM ($(report.e_unit))",
            legend_position = :none; xlims, title, kwargs...
        )
        
        ax = first(fig.content)
        Makie.current_axis!(ax)
        qbb = Unitful.ustrip(report.e_unit, Measurements.value(report.qbb))
        Δqbb = Unitful.ustrip(report.e_unit, Measurements.uncertainty(report.qbb))
        Makie.hlines!(ax, [qbb], color = LegendMakie.CoaxGreen, label = LaTeXStrings.latexstring("\\fontfamily{Roboto}Q_{\\beta \\beta}:" * " $(round(Unitful.ustrip(report.e_unit, report.qbb), digits=2))\\;\\text{$(report.e_unit)}"))
        Makie.band!(ax, range(xlims..., length = 2), fill(qbb - Δqbb, 2), fill(qbb + Δqbb, 2), color = (LegendMakie.CoaxGreen, 0.2))
        Makie.axislegend(ax, position = :lt)
        
        fig
    end

    LegendMakie.lplot!(report::NamedTuple{(:peak, :n_before, :n_after, :sf, :before, :after)}; kwargs...) = LegendMakie.lplot!(report.after; kwargs...)
        
    function LegendMakie.lplot!(
            report::NamedTuple{((:survived, :cut, :sf, :bsf))};
            xlims::Tuple{<:Real, <:Real} = extrema(first(report.survived.h.edges)), 
            xticks = (ceil(first(xlims)/10)*10):10:(floor(last(xlims)/10)*10),
            ylims = nothing, row::Int = 1, col::Int = 1, xlabel = "Energy (keV)",
            title::AbstractString = "", yscale = Makie.log10, show_residuals::Bool = true, kwargs...
        )
            
        fig = Makie.current_figure()
        g = Makie.GridLayout(fig[row,col])
        
        if isnothing(ylims)
            ylim_max = 1.5 * max(
                Measurements.value(report.survived.f_fit(report.survived.v.μ)), 
                Measurements.value(report.cut.f_fit(report.cut.v.μ)),
                maximum(report.survived.h.weights), maximum(report.cut.h.weights)
            )
            ylim_max = ifelse(iszero(ylim_max), nothing, max(1.2e2, ylim_max))
            ylim_min = 0.5 * min(minimum(filter(x -> x > 0, report.survived.h.weights)), minimum(filter(x -> x > 0, report.cut.h.weights)))
            ylims = (ylim_min, ylim_max)
        end

        ax = Makie.Axis(g[1,1], yticks = (exp10.(0:10), "1" .* join.(fill.("0", 0:10))), 
            ylabel = "Counts / $(round(step(first(report.survived.h.edges)), digits=2)) keV", 
            limits = (xlims, ylims); yscale, xlabel, title, xticks)
        
        Makie.plot!(ax, report.survived.h, color = (:gray, 0.5), label = "Data Survived", fillto = 0.5)
        Makie.lines!(ax, range(xlims..., length = 1000), x -> report.survived.f_fit(x) * step(first(report.survived.h.edges)), color = :black, label = "Best Fit" * (!isempty(report.survived.gof) ? " (p = $(round(report.survived.gof.pvalue, digits=2)))" : ""))
        Makie.plot!(ax, report.cut.h, color = (:lightgray, 0.5), label = "Data Cut", fillto = 0.5)
        Makie.lines!(ax, range(xlims..., length = 1000), x -> report.cut.f_fit(x) * step(first(report.cut.h.edges)), color = (:gray, 0.5), label = "Best Fit" * (!isempty(report.cut.gof) ? " (p = $(round(report.cut.gof.pvalue, digits=2)))" : ""))
        Makie.axislegend(ax, position = :lt)

        if !isempty(report.survived.gof) && show_residuals
            ax2 = Makie.Axis(g[2,1], limits = (extrema(first(report.survived.h.edges)), (-5,5)), xlabel = xlabel, xticks = xticks, ylabel = "Residuals (σ)")
            LegendMakie.residualplot!(ax2,(x = report.survived.gof.bin_centers, residuals_norm = report.survived.gof.residuals_norm), color = (:black, 0.5))
            Makie.scatter!(report.cut.gof.bin_centers, report.cut.gof.residuals_norm, color = (:darkgray, 0.7))

            ax.xticklabelsize = 0
            ax.xticksize = 0
            ax.xlabel = ""        

            Makie.linkxaxes!(ax, ax2)
            Makie.rowgap!(g, 0)
            Makie.rowsize!(g, 1, Makie.Auto(3))

            # align ylabels
            yspace = maximum(Makie.tight_yticklabel_spacing!, (ax, ax2))
            ax.yticklabelspace = yspace
            ax2.yticklabelspace = yspace

            if row == 1
                Makie.current_axis!(ax)
                LegendMakie.add_watermarks!(final = true)
            end
        end
        
        fig
    end

    # SiPM Gaussian Mixture fit
    function LegendMakie.lplot!(
            report::NamedTuple{(:h_cal, :f_fit, :f_fit_components, :min_pe, :max_pe, :bin_width, :n_mixtures, :n_pos_mixtures, :peaks, :positions, :μ, :gof)};
            show_peaks::Bool = true, show_residuals::Bool = true, show_components::Bool = true, show_label::Bool = true,
            xlims = extrema(first(report.h_cal.edges)), title::AbstractString = "", yscale = Makie.log10,
            ylims = yscale == Makie.log10 ? (10, maximum(report.h_cal.weights)*4) : (0, maximum(report.h_cal.weights)*1.2),
            xlabel = "Peak amplitudes (P.E.)", ylabel = "Counts", xerrscaling = 1,
            row::Int = 1, col::Int = 1, xticks = Makie.automatic, yticks = Makie.automatic,
            legend_position = :rt, watermark::Bool = true, final::Bool = !isempty(title), kwargs...
        )

        fig = Makie.current_figure()

        # create plot
        g = Makie.GridLayout(fig[row,col])
        ax = Makie.Axis(g[1,1], 
            title = title, titlefont = :bold, titlesize = 16pt, 
            limits = (xlims, ylims); xlabel, ylabel, xticks, yticks, yscale
        )

        Makie.hist!(ax, StatsBase.midpoints(first(report.h_cal.edges)), weights = report.h_cal.weights, bins = first(report.h_cal.edges), color = LegendMakie.DiamondGrey, label = "Amplitudes", fillto = 1e-2)
        Makie.lines!(range(xlims..., length = 1000), x -> report.f_fit(x), linewidth = 2, color = :black, label = ifelse(show_label, "Best Fit" * (!isempty(report.gof) ? " (p = $(round(report.gof.pvalue, digits=2)))" : ""), nothing))

        # show individual components of the Gaussian mixtures
        if show_components
            for i in eachindex(report.μ)
                f = Base.Fix2(report.f_fit_components, i)
                Makie.lines!(
                    range(extrema(first(report.h_cal.edges))..., length = 1000), 
                    x -> f(x), 
                    #color = report.f_components.colors[component], 
                    label = ifelse(show_label && i == firstindex(report.μ) , "Mixture Components", nothing),
                    color = (get_default_color(i), 0.5),
                    linestyle = :dash,
                    linewidth = 2
                )
            end
        end

        # show peak positions as vlines
        if show_peaks
            for (i, p) in enumerate(report.positions)
                Makie.vlines!([Measurements.value(p)], label = "$(report.peaks[i]) P.E. [$(report.n_pos_mixtures[i]) Mix.]" * label_errscaling(xerrscaling,1), linewidth = 1.5)
                Makie.band!(ax, [(Measurements.value(p) .+ (-1,1) .* xerrscaling .* Measurements.uncertainty(p))...], ylims..., alpha = 0.5)
            end
        end

        # add residuals
        if !isempty(report.gof) && show_residuals

            ax.xticklabelsize = 0
            ax.xticksize = 0
            ax.xlabel = ""

            ax2 = Makie.Axis(g[2,1],
                xlabel = "Peak amplitudes (P.E.)", ylabel = "Residuals (σ)",
                xticks = xticks, yticks = -3:3:3, limits = (xlims,(-5,5))
            )
            LegendMakie.residualplot!(ax2, (x = report.gof.bin_centers, residuals_norm = report.gof.residuals_norm))

            # link axis and put plots together
            Makie.linkxaxes!(ax, ax2)
            Makie.rowgap!(g, 0)
            Makie.rowsize!(g, 1, Makie.Auto(3))

            # align ylabels
            yspace = maximum(Makie.tight_yticklabel_spacing!, (ax, ax2))
            ax.yticklabelspace = yspace
            ax2.yticklabelspace = yspace
        end

        legend_position != :none && Makie.axislegend(ax, backgroundcolor = (:white, 0.7), framevisible = true, framecolor = :lightgray, position = legend_position)

        # add watermarks
        Makie.current_axis!(ax)
        watermark && LegendMakie.add_watermarks!(; final, kwargs...)

        fig
    end

    # filter optimzation plots
    function LegendMakie.lplot!(
            report::NamedTuple{(:x, :minx, :y, :miny)};
            title::AbstractString = "", xunit = Unitful.unit(first(report.x)), yunit = Unitful.unit(first(report.y)),
            xlabel = "", ylabel = "", xlegendlabel = xlabel, ylegendlabel = ylabel, 
            xlims = Unitful.ustrip.(xunit, extrema(report.x) .+ (-1, 1) .* (report.x[2] - report.x[1])),
            legend_position = :lt, watermark::Bool = true, final::Bool = !isempty(title), kwargs...
        )

        fig = Makie.current_figure()

        ax = Makie.Axis(fig[1,1];
            title, limits = (xlims, nothing),
            xlabel = (xlabel * ifelse(xunit == Unitful.NoUnits, "", " ($xunit)")) |> typeof(xlabel),
            ylabel = (ylabel * ifelse(yunit == Unitful.NoUnits, "", " ($yunit)")) |> typeof(ylabel)
        )

        Makie.errorbars!(ax, Unitful.ustrip.(xunit, report.x), Unitful.ustrip.(yunit, Measurements.value.(report.y)), Unitful.ustrip.(yunit, Measurements.uncertainty.(report.y)))
        Makie.scatter!(ax, Unitful.ustrip.(xunit, report.x), Unitful.ustrip.(yunit, Measurements.value.(report.y)), label = ylegendlabel)
        Makie.hlines!(ax, [Unitful.ustrip(yunit, Measurements.value(report.miny))], color = :red, label = "Min. $(ylegendlabel) $(round_wo_units(report.miny, digits = 2)) $yunit ($(xlegendlabel): $(report.minx))")
        Makie.band!(ax, [xlims...], Unitful.ustrip.(yunit, (Measurements.value(report.miny) .+ (-1,1) .* Measurements.uncertainty(report.miny)))..., color = (:red,0.2))
        
        legend_position != :none && Makie.axislegend(ax, position = legend_position)

        Makie.current_axis!(ax)
        watermark && LegendMakie.add_watermarks!(; final, kwargs...)
        fig
    end

    function LegendMakie.lplot!(report::NamedTuple{(:rt, :min_enc, :enc_grid_rt, :enc)}; kwargs...)
        LegendMakie.lplot!(
            (x = report.enc_grid_rt, minx = report.rt, y = report.enc, miny = report.min_enc);
            xlabel = "Rise Time", ylabel = "ENC (ADC)", xlegendlabel = "RT", ylegendlabel = "ENC noise", kwargs...
        )
    end

    function LegendMakie.lplot!(report::NamedTuple{(:ft, :min_fwhm, :e_grid_ft, :fwhm)}; kwargs...)
        LegendMakie.lplot!(
            (x = report.e_grid_ft, minx = report.ft, y = report.fwhm, miny = report.min_fwhm);
            xlabel = "Flat-Top Time", ylabel = "FWHM", xlegendlabel = "FT", ylegendlabel = "FWHM", kwargs...
        )
    end

    function LegendMakie.lplot!(report::NamedTuple{(:wl, :min_sf, :a_grid_wl_sg, :sfs)}; kwargs...)
        LegendMakie.lplot!(
            (x = report.a_grid_wl_sg, minx = report.wl, y = report.sfs, miny = report.min_sf);
            xlabel = "Window length", ylabel = "SEP survival fraction", xlegendlabel = "WL", ylegendlabel = "SF", kwargs...
        )
    end

    function LegendMakie.lplot!(report::NamedTuple{(:wl, :min_obj, :gain, :res_1pe, :pos_1pe, :threshold, :a_grid_wl_sg, :obj, :report_simple, :report_fit)}; kwargs...)
        LegendMakie.lplot!(
            (x = report.a_grid_wl_sg, minx = report.wl, y = report.obj, miny = report.min_obj);
            xlabel = "Window length",
            ylabel = LaTeXStrings.latexstring("\\fontfamily{Roboto} Objective\\; \$\\frac{\\sqrt{\\sigma \\cdot \\text{threshold}}}{\\text{gain}}\$"), 
            xlegendlabel = "WL", ylegendlabel = "Obj", kwargs...
        )
    end

    # single fits
    function LegendMakie.lplot!(
            report::NamedTuple{(:f_fit, :h, :μ, :σ, :gof)};
            title::AbstractString = "", show_residuals::Bool = true,
            ylims = (0,nothing), xlabel = "", xticks = Makie.automatic, 
            xlims = Unitful.ustrip.(Measurements.value.((report.μ - 5*report.σ, report.μ + 5*report.σ))), 
            legend_position = :lt, watermark::Bool = true, final::Bool = !isempty(title), kwargs...
        )

        fig = Makie.current_figure()
        
        g = Makie.GridLayout(fig[1,1])
        ax = Makie.Axis(g[1,1], 
            title = title, titlefont = :bold, titlesize = 16pt, xlabel = xlabel,
            xticks = xticks, limits = (xlims, ylims), ylabel = "Normalized Counts",
        )
        
        # Create histogram
        Makie.plot!(ax, report.h, label = "Data")
        
        _x = range(extrema(xlims)..., length = 1000)
        Makie.lines!(_x, report.f_fit.(_x), color = :red, 
            label = "Normal Fit\nμ = $(round_wo_units(report.μ, digits=2))\nσ = $(round_wo_units(report.σ, digits=2))")
        
        if legend_position != :none 
            Makie.axislegend(ax, position = legend_position)
        end
        
        if !isempty(report.gof) && show_residuals

            ax.xticklabelsize = 0
            ax.xticksize = 0
            ax.xlabel = ""

            ax2 = Makie.Axis(g[2,1], xticks = xticks, yticks = -3:3:3, limits = (xlims,(-5,5)), xlabel = xlabel, ylabel = "Residuals (σ)")
            LegendMakie.residualplot!(ax2, (x = report.gof.bin_centers, residuals_norm = [ifelse(abs(r) < 1e-6, 0.0, r) for r in report.gof.residuals_norm]))

            # link axis and put plots together
            Makie.linkxaxes!(ax, ax2)
            Makie.rowgap!(g, 0)
            Makie.rowsize!(g, 1, Makie.Auto(3))

            # align ylabels
            yspace = maximum(Makie.tight_yticklabel_spacing!, (ax, ax2))
            ax.yticklabelspace = yspace
            ax2.yticklabelspace = yspace
        end

        # add watermarks
        Makie.current_axis!(ax)
        watermark && LegendMakie.add_watermarks!(; final, kwargs...)
        
        fig
    end

    function LegendMakie.lplot!(
            report::NamedTuple{(:v, :h, :f_fit, :f_components, :gof)};
            xlabel = "Energy (keV)", ylabel = "Counts / bin",
            title::AbstractString = "", legend_position = :lt,
            xlims = extrema(first(report.h.edges)), 
            ylims = let (_min, _max) = extrema(filter(x -> x > 0, report.h.weights))
                scale = (_max/_min)^(1/4)
                (_min / sqrt(scale), _max * scale)
            end,
            show_label::Bool = true, show_components::Bool = true, yticks = Makie.automatic,
            watermark::Bool = true, final::Bool = !isempty(title),
            show_residuals::Bool = true, row::Int = 1, col::Int = 1, kwargs...
        )

        
        fig = Makie.current_figure()

        # create plot
        g = Makie.GridLayout(fig[row,col])
        ax = Makie.Axis(g[1,1], 
            title = title, titlefont = :bold, titlesize = 16pt, 
            xlabel = xlabel, ylabel = ylabel, yticks = yticks,
            limits = (xlims, ylims),
            yscale = Makie.log10
        )

        Makie.hist!(ax, StatsBase.midpoints(first(report.h.edges)), weights = report.h.weights, bins = first(report.h.edges), color = LegendMakie.DiamondGrey, label = "Data", fillto = 1e-2)
        Makie.lines!(range(xlims..., length = 1000), x -> report.f_fit(x) * step(first(report.h.edges)), color = :black, label = ifelse(show_label, "Best Fit" * (!isempty(report.gof) ? " (p = $(round(report.gof.pvalue, digits=2)))" : ""), ""))
                    
        if show_components
            for (idx, component) in enumerate(keys(report.f_components.funcs))
                Makie.lines!(
                    range(extrema(first(report.h.edges))..., length = 1000), 
                    x -> report.f_components.funcs[component](x) * step(first(report.h.edges)), 
                    color = report.f_components.colors[component], 
                    label = ifelse(show_label, report.f_components.labels[component], ""),
                    linestyle = report.f_components.linestyles[component],
                    linewidth = 4
                )
            end
        end

        if legend_position != :none 
            Makie.axislegend(ax, position = legend_position)
        end

        if !isempty(report.gof) && show_residuals

            ax.xticklabelsize = 0
            ax.xticksize = 0
            ax.xlabel = ""

            ax2 = Makie.Axis(g[2,1],
                    xlabel = xlabel, ylabel = "Residuals (σ)",
                    yticks = -3:3:3, limits = (xlims,(-5,5))
                )
            LegendMakie.residualplot!(ax2, (x = StatsBase.midpoints(first(report.h.edges)), residuals_norm = report.gof.residuals_norm))

            Makie.linkxaxes!(ax, ax2)
            Makie.rowgap!(g, 0)
            Makie.rowsize!(g, 1, Makie.Auto(3))

            # align ylabels
            yspace = maximum(Makie.tight_yticklabel_spacing!, (ax, ax2))
            ax.yticklabelspace = yspace
            ax2.yticklabelspace = yspace
        end

        # add watermarks
        Makie.current_axis!(ax)
        watermark && LegendMakie.add_watermarks!(; final, kwargs...)

        fig
    end

    # Ecal
    function LegendMakie.lplot!(
            report::NamedTuple{(:f_calib, :h_cal, :h_uncal, :c, :peak_positions, :threshold)},
            cal_lines::Vector{<:Unitful.Energy} = typeof(1.0u"keV")[];
            e_unit = u"keV", title::AbstractString = "", xlabel = "Energy ($(e_unit))", ylabel = "Counts / $(round(step(first(report.h_cal.edges)), digits = 2)) keV",
            yscale = Makie.log10, xlims = (0,3000), ylims = (0.9, maximum(report.h_cal.weights)*1.2),
            xticks = 0:250:3000, legend_position = :rt,
            watermark::Bool = true, final::Bool = !isempty(title), kwargs...
        )

        fig = Makie.current_figure()
        ax = Makie.Axis(fig[1,1]; limits = (xlims, ylims), title, xticks, xlabel, ylabel, yscale)

        Makie.stephist!(ax, StatsBase.midpoints(first(report.h_cal.edges)), weights = replace(report.h_cal.weights, 0=>1e-10), bins = first(report.h_cal.edges), label = "e_fc")
        !isempty(cal_lines) && Makie.vlines!(ax, Unitful.ustrip.(e_unit, cal_lines), color = :red, label = "Th228 Calibration Lines")
        legend_position != :none && Makie.axislegend(ax, position = legend_position, framevisible = true, framecolor = :lightgray)
            
        Makie.current_axis!(ax)
        watermark && LegendMakie.add_watermarks!(; final, kwargs...)
        fig
    end

    function LegendMakie.lplot!(
            report::NamedTuple{(:h_calsimple, :h_uncal, :c, :fep_guess, :peakhists, :peakstats)};
            cal::Bool = true, title::AbstractString = "", yscale = Makie.log10, 
            final::Bool = !isempty(title), watermark::Bool = true, kwargs...
        )
        
        fig = Makie.current_figure()
        
        # select correct histogram
        h = StatsBase.normalize(cal ? report.h_calsimple : report.h_uncal, mode = :density)
        fep_guess = cal ? 2614.5 : report.fep_guess

        # create main histogram plot
        ax = Makie.Axis(
            fig[1,1], 
            title = title, titlegap = 2,
            limits = (0, cal ? 3000 : 1.2*report.fep_guess, 0.99*minimum(filter(x -> x > 0, h.weights)), 1.2 * maximum(h.weights)*1.1),
            xticks = cal ? (0:300:3000) : (0:50000:1.2*report.fep_guess),
            xlabel = "Energy ($(cal ? "keV" : "ADC"))",
            ylabel = "Counts",
            yscale = yscale
        )
        
        Makie.stephist!(ax, StatsBase.midpoints(first(h.edges)), bins = first(h.edges), weights = h.weights, label = "Energy")
        Makie.vlines!(ax, [fep_guess], color = :red, label = "FEP Guess", linewidth = 1.5)
        Makie.axislegend(ax, position = :ct)
        
        # add watermarks
        Makie.current_axis!(ax)
        watermark && LegendMakie.add_watermarks!(; final, kwargs...)
        
        fig
    end

    # A/E
    function LegendMakie.lplot!( 
            report::NamedTuple{(:par, :f_fit, :x, :y, :gof, :e_unit, :label_y, :label_fit)}; 
            title::AbstractString = "", show_residuals::Bool = true,
            xticks = 500:250:2250, xlims = (500,2300), ylims = nothing,
            legend_position = :rt, row::Int = 1, col::Int = 1, 
            watermark::Bool = false, final::Bool = !isempty(title), kwargs...
        )

        fig = Makie.current_figure()

        # create plot
        g = Makie.GridLayout(fig[row,col])
        ax = Makie.Axis(g[1,1], 
            title = title, titlefont = :bold, titlesize = 16pt, 
            xlabel = "E ($(report.e_unit))", ylabel = report.label_y * " (a.u.)", 
            xticks = xticks, limits = (xlims, ylims)
        )

        LegendMakie.aoecorrectionplot!(ax, report)
        if legend_position != :none 
            Makie.axislegend(ax, position = legend_position)
        end

        # add residuals
        if !isempty(report.gof) && show_residuals

            ax.xticklabelsize = 0
            ax.xticksize = 0
            ax.xlabel = ""

            ax2 = Makie.Axis(g[2,1],
                xlabel = "E ($(report.e_unit))", ylabel = "Residuals (σ)",
                xticks = xticks, yticks = -3:3:3, limits = (xlims,(-5,5))
            )
            LegendMakie.residualplot!(ax2, (x = report.x, residuals_norm = report.gof.residuals_norm))

            # link axis and put plots together
            Makie.linkxaxes!(ax, ax2)
            Makie.rowgap!(g, 0)
            Makie.rowsize!(g, 1, Makie.Auto(3))

            # align ylabels
            yspace = maximum(Makie.tight_yticklabel_spacing!, (ax, ax2))
            ax.yticklabelspace = yspace
            ax2.yticklabelspace = yspace
        end

        # add watermarks
        Makie.current_axis!(ax)
        watermark && LegendMakie.add_watermarks!(; final, kwargs...)

        fig 
    end


    function LegendMakie.lplot!( 
            report::NamedTuple{(:h_before, :h_after_low, :h_after_ds, :dep_h_before, :dep_h_after_low, :dep_h_after_ds, :sf, :n0, :lowcut, :highcut, :e_unit, :bin_width)}; 
            title::AbstractString = "", watermark::Bool = true, final::Bool = true, kwargs...
        )

        fig = Makie.current_figure()

        # create main histogram plot
        ax = Makie.Axis(fig[1,1],
            title = title, limits = ((0,2700), (1,maximum(report.h_before.weights) * 1.2)), yscale = Makie.log10,
            xlabel = "Energy (keV)", ylabel = "Counts / $(round(step(first(report.h_before.edges)), digits = 2)) keV", 
        )
        Makie.stephist!(ax, StatsBase.midpoints(first(report.h_before.edges)),    weights = report.h_before.weights,    bins = first(report.h_before.edges),    color = (LegendMakie.AchatBlue, 0.5),  label = "Before A/E")
        Makie.stephist!(ax, StatsBase.midpoints(first(report.h_after_low.edges)), weights = report.h_after_low.weights, bins = first(report.h_after_low.edges), color = (LegendMakie.BEGeOrange, 1), label = "After low A/E")
        Makie.stephist!(ax, StatsBase.midpoints(first(report.h_after_ds.edges)),  weights = report.h_after_ds.weights,  bins = first(report.h_after_ds.edges),  color = (LegendMakie.CoaxGreen, 0.5),  label = "After DS A/E")
        Makie.axislegend(ax, position = (0.96,1))

        # add inset
        ax_inset = Makie.Axis(fig[1,1],
            width = Makie.Relative(0.4),
            height = Makie.Relative(0.2),
            halign = 0.55,
            valign = 0.95, 
            yscale = Makie.log10,
            xlabel = "Energy (keV)",
            ylabel = "Counts",
            xticks = 1585:10:1645,
            xlabelsize = 12pt,
            ylabelsize = 12pt,
            xticklabelsize = 10pt,
            yticklabelsize = 10pt,
            yticks = (exp10.(0:10), "1" .* join.(fill.("0", 0:10))),
            limits = (extrema(first(report.dep_h_before.edges)), (0.9, max(100, maximum(report.dep_h_before.weights)) * 1.2))
        )
        Makie.stephist!(ax_inset, StatsBase.midpoints(first(report.dep_h_before.edges)),    weights = replace(report.dep_h_before.weights, 0 => 1e-10),    bins = first(report.dep_h_before.edges),    color = (LegendMakie.AchatBlue, 0.5),  label = "Before A/E")
        Makie.stephist!(ax_inset, StatsBase.midpoints(first(report.dep_h_after_low.edges)), weights = replace(report.dep_h_after_low.weights, 0 => 1e-10), bins = first(report.dep_h_after_low.edges), color = (LegendMakie.BEGeOrange, 1), label = "After low A/E")
        Makie.stephist!(ax_inset, StatsBase.midpoints(first(report.dep_h_after_ds.edges)),  weights = replace(report.dep_h_after_ds.weights, 0 => 1e-10),  bins = first(report.dep_h_after_ds.edges),  color = (LegendMakie.CoaxGreen, 0.5),  label = "After DS A/E")

        # add watermarks
        Makie.current_axis!(ax)
        watermark && LegendMakie.add_watermarks!(; final, kwargs...)

        fig
    end


    function LegendMakie.lplot!( 
            report::NamedTuple{(:par, :f_fit, :x, :y, :gof, :e_unit, :label_y, :label_fit)},
            com_report::NamedTuple{(:values, :label_y, :label_fit, :energy)};
            legend_position = :rt, row::Int = 1, col::Int = 1, kwargs...
        )

        fig = LegendMakie.lplot!(report, legend_position = :none, col = col; kwargs...)

        g = last(Makie.contents(fig[row,col]))
        ax = Makie.contents(g)[1]
        Makie.lines!(ax, com_report.energy, com_report.values, linewidth = 4, color = :red, linestyle = :dash, label = LaTeXStrings.latexstring("\\fontfamily{Roboto}" * com_report.label_fit))
        Makie.axislegend(ax, position = legend_position)

        fig
    end

    function LegendMakie.lplot!(
            report::NamedTuple{(:peak, :window, :fct, :bin_width, :bin_width_qdrift, :e_peak, :e_ctc, :qdrift_peak, :h_before, :h_after, :fwhm_before, :fwhm_after, :report_before, :report_after)};
            label_before = "Before correction", label_after = "After correction", title::AbstractString = "", watermark::Bool = true, 
            xlims = extrema(first(report.h_before.edges)), e_unit = u"keV", kwargs...
        )

        # Best results for figsize (600,600)
        fig = Makie.current_figure()

        g = Makie.GridLayout(fig[1,1])

        ax = Makie.Axis(g[1,1], limits = (xlims...,0,nothing), ylabel = "Counts / $(round(step(first(report.h_before.edges)), digits = 2))")
        Makie.plot!(ax, report.h_before, color = :darkgrey, label = label_before)
        Makie.plot!(ax, report.h_after, color = (:purple, 0.5), label = label_after)
        Makie.axislegend(position = :lt)

        ax2 = Makie.Axis(g[2,1], limits = (xlims...,0,1-1e-5), xticks = 2400:10:2630, yticks = 0:0.2:1, xlabel = "Energy ($e_unit)", ylabel = "Qdrift / E (a.u.)")
        k_before = KernelDensity.kde((Unitful.ustrip.(e_unit, report.e_peak), report.qdrift_peak ./ maximum(report.qdrift_peak)))
        k_after = KernelDensity.kde((Unitful.ustrip.(e_unit, report.e_ctc), report.qdrift_peak ./ maximum(report.qdrift_peak)))
        Makie.contourf!(ax2, k_before.x, k_before.y, k_before.density, levels = 15, colormap = :binary)
        Makie.contour!(ax2, k_before.x, k_before.y, k_before.density, levels = 15 - 1, color = :white)
        Makie.contour!(ax2, k_after.x, k_after.y, k_after.density, levels = 15 - 1, colormap = :plasma)
        Makie.lines!(ax2, [0], [0], label = label_before, color = :darkgrey)
        Makie.lines!(ax2, [0], [0], label = label_after, color = (:purple, 0.5))
        Makie.axislegend(position = :lb)

        ax3 = Makie.Axis(g[2,2], limits = (0,nothing,0,1-1e-5), xlabel = "Counts / 0.1")
        Makie.plot!(ax3, StatsBase.fit(StatsBase.Histogram, report.qdrift_peak ./ maximum(report.qdrift_peak), 0:0.01:1), color = :darkgrey, label = "Before correction", direction = :x)
        ax3.xticks = Makie.WilkinsonTicks(3, k_min = 3, k_max=4)

        # Formatting
        Makie.linkxaxes!(ax,ax2)
        Makie.hidexdecorations!(ax)
        Makie.rowgap!(g, 0)
        Makie.rowsize!(g, 1, Makie.Auto(0.5))
        Makie.linkyaxes!(ax2,ax3)
        Makie.hideydecorations!(ax3)
        Makie.colgap!(g, 0)
        Makie.colsize!(g, 2, Makie.Auto(0.5))
        xspace = maximum(Makie.tight_xticklabel_spacing!, (ax2, ax3))
        ax2.xticklabelspace = xspace
        ax3.xticklabelspace = xspace
        yspace = maximum(Makie.tight_yticklabel_spacing!, (ax, ax2))
        ax.yticklabelspace = yspace
        ax2.yticklabelspace = yspace

        # add general title
        if !isempty(title)
            Makie.Label(g[1,:,Makie.Top()], title, padding = (0,0,2,0), fontsize = 20, font = :bold)
        end

        # add watermarks
        Makie.current_axis!(ax3)
        watermark && LegendMakie.add_watermarks!(; kwargs...)

        fig
    end


    function LegendMakie.lplot!( 
            report::NamedTuple{(:peak, :window, :fct, :bin_width, :bin_width_qdrift, :aoe_peak, :aoe_ctc, :qdrift_peak, :h_before, :h_after, :σ_before, :σ_after, :report_before, :report_after)};
            label_before = "Before correction", label_after = "After correction", title::AbstractString = "", watermark::Bool = true, kwargs...
        )

        # Best results for figsize (600,600)
        fig = Makie.current_figure()
        
        g = Makie.GridLayout(fig[1,1])
        
        ax = Makie.Axis(g[1,1], limits = (-9,5,0,nothing), ylabel = "Counts / $(round(step(first(report.h_before.edges)), digits = 2))")
        Makie.plot!(ax, report.h_before, color = :darkgrey, label = label_before)
        Makie.plot!(ax, report.h_after, color = (:purple, 0.5), label = label_after)
        Makie.axislegend(position = :lt)
        
        ax2 = Makie.Axis(g[2,1], limits = (-9,5,0,11.5), xticks = -8:2:5, yticks = 0:2:10, xlabel = "A/E classifier", ylabel = "Qdrift / E")
        k_before = KernelDensity.kde((report.aoe_peak, report.qdrift_peak))
        k_after = KernelDensity.kde((report.aoe_ctc, report.qdrift_peak))
        Makie.contourf!(ax2, k_before.x, k_before.y, k_before.density, levels = 15, colormap = :binary)
        Makie.contour!(ax2, k_before.x, k_before.y, k_before.density, levels = 15 - 1, color = :white)
        Makie.contour!(ax2, k_after.x, k_after.y, k_after.density, levels = 15 - 1, colormap = :plasma)
        Makie.lines!(ax2, [0], [0], label = label_before, color = :darkgrey)
        Makie.lines!(ax2, [0], [0], label = label_after, color = (:purple, 0.5))
        Makie.axislegend(position = :lb)
        
        ax3 = Makie.Axis(g[2,2], limits = (0,nothing,0,11.5), xlabel = "Counts / 0.1")
        Makie.plot!(ax3, StatsBase.fit(StatsBase.Histogram, report.qdrift_peak, 0:0.1:11.5), color = :darkgrey, label = "Before correction", direction = :x)
        ax3.xticks = Makie.WilkinsonTicks(3, k_min = 3, k_max=4)
        
        # Formatting
        Makie.linkxaxes!(ax,ax2)
        Makie.hidexdecorations!(ax)
        Makie.rowgap!(g, 0)
        Makie.rowsize!(g, 1, Makie.Auto(0.5))
        Makie.linkyaxes!(ax2,ax3)
        Makie.hideydecorations!(ax3)
        Makie.colgap!(g, 0)
        Makie.colsize!(g, 2, Makie.Auto(0.5))
        xspace = maximum(Makie.tight_xticklabel_spacing!, (ax2, ax3))
        ax2.xticklabelspace = xspace
        ax3.xticklabelspace = xspace
        yspace = maximum(Makie.tight_yticklabel_spacing!, (ax, ax2))
        ax.yticklabelspace = yspace
        ax2.yticklabelspace = yspace

        # add general title
        if !isempty(title)
            Makie.Label(g[1,:,Makie.Top()], title, padding = (0,0,2,0), fontsize = 20, font = :bold)
        end
        
        # add watermarks
        Makie.current_axis!(ax3)
        watermark && LegendMakie.add_watermarks!(; kwargs...)
        
        fig
    end

    # LQ plots
    function LegendMakie.lplot!(
            report::NamedTuple{(:hist_dep, :hist_sb1, :hist_sb2, :hist_subtracted, :hist_corrected)};
            title::AbstractString = "", xlabel = "LQ (a.u.)", ylabel = "Counts", legend_position = :rt,
            xlims = nothing, ylims = (0, nothing), final::Bool = !isempty(title),
            watermark::Bool = true, kwargs...
        )
        
        fig = Makie.current_figure()
        ax = Makie.Axis(fig[1,1]; limits = (xlims, ylims), title, xlabel, ylabel)
        
        let h = report.hist_dep, h1 = report.hist_sb1, h2 = report.hist_sb2
        Makie.stephist!(ax, StatsBase.midpoints(first(h.edges)), bins = first(h.edges), weights = h.weights, label = "Peak")
        Makie.stephist!(ax, StatsBase.midpoints(first(h1.edges)), bins = first(h1.edges), weights = h1.weights, label = "Sideband 1")
        Makie.stephist!(ax, StatsBase.midpoints(first(h2.edges)), bins = first(h2.edges), weights = h2.weights, label = "Sideband 2")
        end
        
        legend_position != :none && Makie.axislegend(position = legend_position)
        
        watermark && LegendMakie.add_watermarks!(; final, kwargs...)
        fig
    end

    function LegendMakie.lplot!(
            report::NamedTuple{(:e_cal, :lq_class, :cut_value)};
            title::AbstractString = "", e_unit = Unitful.unit(first(report.e_cal)), 
            xlabel = "Energy ($e_unit)", ylabel = "Counts", yscale = Makie.log10,
            watermark::Bool = true, final::Bool = !isempty(title), kwargs...
        )
        
        # best results for figsize = (750,400)
        fig = Makie.current_figure()
        
        h = StatsBase.fit(StatsBase.Histogram, Unitful.ustrip.(e_unit, report.e_cal), 0:1:3000)
        ax = Makie.Axis(fig[1,1],
            limits = ((0,2700), (1,maximum(h.weights)*1.2));
            title, xlabel, ylabel = ylabel * " / $(e_unit)", yscale
        )

        Makie.stephist!(ax, Unitful.ustrip.(e_unit, report.e_cal), bins = 0:1:3000,  color = (LegendMakie.AchatBlue, 0.5),  label = "Before LQ")
        Makie.stephist!(ax, Unitful.ustrip.(e_unit, report.e_cal)[report.lq_class .> report.cut_value], bins = 0:1:3000, color = (LegendMakie.BEGeOrange, 1),  label = "Cut by LQ")
        Makie.stephist!(ax, Unitful.ustrip.(e_unit, report.e_cal)[report.lq_class .<= report.cut_value], bins = 0:1:3000, color = (LegendMakie.CoaxGreen, 0.7), label = "Surviving LQ")
        Makie.axislegend(ax, position = (0.96,1))

        # add inset
        h_in = StatsBase.fit(StatsBase.Histogram, Unitful.ustrip.(e_unit, report.e_cal), 1583:0.5:1640)
        ax_inset = Makie.Axis(fig[1,1],
            width = Makie.Relative(0.4),
            height = Makie.Relative(0.2),
            halign = 0.55,
            valign = 0.95, 
            yscale = yscale,
            xlabel = xlabel,
            ylabel = ylabel,
            xticks = 1585:10:1645,
            xlabelsize = 12pt,
            ylabelsize = 12pt,
            xticklabelsize = 10pt,
            yticklabelsize = 10pt,
            yticks = (exp10.(0:10), "1" .* join.(fill.("0", 0:10))),
            limits = (extrema(first(h_in.edges)), (0.9, max(100, maximum(h_in.weights)) * 1.2))
        )
        Makie.stephist!(ax_inset, Unitful.ustrip.(e_unit, report.e_cal), bins = 1583:0.5:1640,  color = (LegendMakie.AchatBlue, 0.5),  label = "Before A/E")
        Makie.stephist!(ax_inset, Unitful.ustrip.(e_unit, report.e_cal)[report.lq_class .> report.cut_value],  bins = 1583:0.5:1640, color = (LegendMakie.BEGeOrange, 1.0),  label = "Before A/E")
        Makie.stephist!(ax_inset, Unitful.ustrip.(e_unit, report.e_cal)[report.lq_class .<= report.cut_value], bins = 1583:0.5:1640, color = (LegendMakie.CoaxGreen, 0.7),  label = "Before A/E")

        Makie.current_axis!(ax)
        watermark && LegendMakie.add_watermarks!(final = true)
        
        fig
    end

    function LegendMakie.lplot!(
            report::NamedTuple{(:e_cal, :edges, :dep_σ)};
            e_unit = Unitful.unit(first(report.e_cal)), 
            h = StatsBase.fit(StatsBase.Histogram, Unitful.ustrip.(e_unit, report.e_cal), 1500:1:1650),
            xlims = extrema(first(h.edges)), ylims = (0, maximum(h.weights)*1.2),
            title::AbstractString = "", xlabel = "Energy ($e_unit)", ylabel = "Counts / $(e_unit)",
            legend_position = :lt, watermark::Bool = true, final::Bool = !isempty(title), kwargs...
        )
        
        fig = Makie.current_figure()
        
        ax = Makie.Axis(fig[1,1], limits = (xlims, ylims); title, xlabel, ylabel)
        
        Makie.stephist!(ax, StatsBase.midpoints(first(h.edges)), weights = h.weights, bins = first(h.edges),
            label = "Energy Spectrum (σ: $(round(e_unit, report.dep_σ, digits=2)))")
        Makie.vlines!(ax, Unitful.ustrip.(e_unit, [report.edges.DEP_edge_left, report.edges.DEP_edge_right]), color = LegendMakie.BEGeOrange, label = "DEP region")
        Makie.vlines!(ax, Unitful.ustrip.(e_unit, [report.edges.sb1_edge, report.edges.sb2_edge]), color = LegendMakie.CoaxGreen, label = "Side bands")
        
        Makie.band!(ax, Unitful.ustrip.(e_unit, [report.edges.DEP_edge_left, report.edges.DEP_edge_right]), 0, maximum(h.weights)*1.2, color = (LegendMakie.BEGeOrange, 0.1))
        Makie.band!(ax, Unitful.ustrip.(e_unit, [min(report.edges.sb1_edge, report.edges.sb2_edge), report.edges.DEP_edge_left]), 0, maximum(h.weights)*1.2, color = (LegendMakie.CoaxGreen, 0.1))
        if report.edges.sb2_edge > report.edges.sb1_edge 
            Makie.band!(ax, Unitful.ustrip.(e_unit, [report.edges.DEP_edge_right, report.edges.sb2_edge]), 0, maximum(h.weights)*1.2, color = (LegendMakie.CoaxGreen, 0.1))
        end
        
        legend_position != :none && Makie.axislegend(ax, position = legend_position)
        
        Makie.current_axis!(ax)
        watermark && LegendMakie.add_watermarks!(; final, kwargs...)
        
        fig
    end

    function LegendMakie.lplot!(
            report::NamedTuple{(:lq_report, :drift_report, :lq_box, :drift_time_func, :dep_left, :dep_right)},
            e_cal, dt_eff, lq_e_corr, plot_type::Symbol = :whole;
            title::AbstractString = "", xlabel = "Drift time (a.u.)", ylabel = "LQ (a.u.)", 
            colorscale = plot_type == :whole ? Makie.log10 : Makie.identity,
            watermark::Bool = true, final::Bool = !isempty(title), kwargs...
        )
        
        # best results for figsize = (620,400)
        sel = isfinite.(e_cal) .&& (plot_type == :whole .|| report.dep_left .< e_cal .< report.dep_right)
        let l = report.lq_box.t_lower, r = report.lq_box.t_upper, b = report.lq_box.lq_lower, t = report.lq_box.lq_upper
            xlims = (2l-r, 2r-l)
            ylims = plot_type == :whole ? (9b-8t, 9t-8b) : (2b-t, 5t-4b)
            LegendMakie.lhist!(StatsBase.fit(StatsBase.Histogram, (dt_eff[sel], lq_e_corr[sel]), 
                (range(xlims..., length = (plot_type == :whole ? 200 : 50)), range(ylims..., length = (plot_type == :whole ? 200 : 50))));
                title, xlabel, ylabel, limits = (xlims, ylims), colorscale,
                colormap = :viridis, figsize = (620,400), watermark = false)
            Makie.lines!([l,l,r,r,l],[b,t,t,b,b], color = :red, linewidth = 3)
            Makie.lines!([2l-r,2r-l], report.drift_time_func.([2l-r,2r-l]), linewidth = 3, color = LegendMakie.BEGeOrange, label = "Linear fit")
        end
        Makie.axislegend(position = :lt, framevisible = true, framewidth = 1, framecolor = :lightgray)
        LegendMakie.add_watermarks!(; position = "outer top", final, kwargs...)
    end


    # SiPM
    function LegendMakie.lplot!(
            report::NamedTuple{(:peakpos, :peakpos_cal, :h_uncal, :h_calsimple)};
            cal::Bool = true, title::AbstractString = "", yscale = Makie.log10,
            legend_position = :rt, final::Bool = !isempty(title), watermark::Bool = true, kwargs...
        )

        fig = Makie.current_figure()

        # select correct histogram
        h = StatsBase.normalize(cal ? report.h_calsimple : report.h_uncal, mode = :density)

        # create main histogram plot
        ax = Makie.Axis(
            fig[1,1], 
            title = title, titlegap = 2,
            limits = (0, last(first(h.edges)), 0.99*minimum(filter(x -> x > 0, h.weights)), maximum(h.weights)*1.2),
            xticks = cal ? (0:0.5:last(first(h.edges))) : Makie.automatic,
            xlabel = "Peak Amplitudes ($(cal ? "P.E." : "ADC"))",
            ylabel = "Counts / $(round_wo_units(step(first(h.edges)), digits = 2)) $(cal ? "P.E." : "ADC")",
            yscale = yscale
        )

        Makie.stephist!(ax, StatsBase.midpoints(first(h.edges)), bins = first(h.edges), weights = h.weights, label = "Amps")
        Makie.vlines!(ax, cal ? report.peakpos_cal : report.peakpos, color = :red, label = "Peak Pos. Guess", linewidth = 1.5)
        legend_position != :none && Makie.axislegend(ax, framevisible = true, framewidth = 0, position = legend_position)

        # add watermarks
        Makie.current_axis!(ax)
        watermark && LegendMakie.add_watermarks!(; final, kwargs...)

        fig
    end


    # Dict of reports (vertical alignment)
    function LegendMakie.lplot!(
            reports::Dict{<:Any, NamedTuple}; title::AbstractString = "", 
            watermark::Bool = true, final::Bool = true, kwargs...
        )

        fig = Makie.current_figure()

        isempty(reports) && throw(ArgumentError("Cannot plot empty dictionary."))
        
        for (i,(k,report)) in enumerate(reports)
            LegendMakie.lplot!(report, title = string(k), row = i, watermark = false; kwargs...)
        end

        # add general title
        if !isempty(title)
            Makie.Label(fig[1,:,Makie.Top()], title, padding = (0,0,35,0), fontsize = 24, font = :bold)
        end

        # add watermarks
        Makie.current_axis!(first(fig.content))
        watermark && LegendMakie.add_watermarks!(; final, kwargs...)

        fig
    end

end