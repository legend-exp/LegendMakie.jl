# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

module LegendMakieLegendSpecFitsExt

    import LegendMakie

    import KernelDensity
    import LaTeXStrings
    import Makie
    import Measurements
    import StatsBase
    import Unitful

    import LegendMakie: aoecorrectionplot!, energycalibrationplot!
    import Unitful: @u_str

    # Default color palette
    function get_default_color(i::Int)
        colors = Makie.wong_colors()
        colors[(i - 1) % end + 1]
    end

    function round_wo_units end
    round_wo_units(x::Real; digits=2) = round(x, sigdigits=digits)
    round_wo_units(x::Unitful.Quantity; kwargs...) = round_wo_units(Unitful.ustrip(x); kwargs...)*Unitful.unit(x)
    function round_wo_units(m::Measurements.Measurement; digits::Int=2)
        # copied from the truncated_print function in Measurements.jl
        val = if iszero(m.err) || !isfinite(m.err)
            m.val
        else
            err_digits = -Base.hidigit(m.err, 10) + digits
            val_digits = if isfinite(m.val)
                max(-Base.hidigit(m.val, 10) + 2, err_digits)
            else
                err_digits
            end
            round(m.val, digits = val_digits)
        end
        Measurements.measurement(val, round(m.err, sigdigits=digits))
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


    Makie.@recipe(EnergyCalibrationPlot, report) do scene
        Makie.Attributes(
            color = LegendMakie.AchatBlue,
            plot_ribbon = true,
            plot_gof = true,
            xerrscaling = 1,
            yerrscaling = 1
        )
    end

    # Needed for creatings legend using Makie recipes
    # https://discourse.julialang.org/t/makie-defining-legend-output-for-a-makie-recipe/121567
    function Makie.get_plots(p::EnergyCalibrationPlot)
        return p.plots
    end
    
    function Makie.plot!(p::EnergyCalibrationPlot{<:Tuple{<:NamedTuple{(:par, :f_fit, :x, :y, :gof)}}})
        
        report = p.report[]
        xerrscaling = p.xerrscaling[]
        yerrscaling = p.yerrscaling[]

        # plot fit
        xfit = 0:1:1.2*Measurements.value(maximum(report.x))
        yfit = report.f_fit.(xfit)
        yfit_m = Measurements.value.(yfit)
        Makie.lines!(xfit, yfit_m, label = "Best Fit" * ((!isempty(report.gof) && p.plot_gof[] && isfinite(report.gof.pvalue)) ? " (p = $(round(report.gof.pvalue, digits=2))| χ²/ndf = $(round(report.gof.chi2min, digits=2)) / $(report.gof.dof))" : ""), color = p.color)
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

        p
    end


    # energy calibration plots (calibration function and FWHM)
    function LegendMakie.lplot!(
            report::NamedTuple{(:par, :f_fit, :x, :y, :gof)};
            additional_pts::NamedTuple = NamedTuple(),
            title::AbstractString = "", titlesize = 18, 
            xticks = Makie.WilkinsonTicks(6, k_min = 5), xtickformat = Makie.automatic,
            xlims = (0, 1.2*Measurements.value(maximum(report.x))), ylims = nothing,
            xlabel = "Energy (ADC)", ylabel = "Energy (calibrated)", 
            show_residuals::Bool = true, plot_ribbon::Bool = true, plot_gof::Bool = true, legend_position = :lt,
            xerrscaling::Real = 1, yerrscaling::Real = 1, row::Int = 1, col::Int = 1,
            watermark::Bool = true, final::Bool = !isempty(title), kwargs...
        )
        
        fig = Makie.current_figure()
            
        g = Makie.GridLayout(fig[row,col])
        ax = Makie.Axis(g[1,1],
            limits = (xlims, ylims);
            title, titlesize, xlabel, ylabel, xticks, xtickformat
        )
        
        LegendMakie.energycalibrationplot!(ax, report; plot_ribbon, xerrscaling, yerrscaling, plot_gof)
        legend_position != :none && Makie.axislegend(ax, position = legend_position)
    
        # plot additional points
        if !isempty(additional_pts) && !isempty(additional_pts.x) && !isempty(additional_pts.y)
            xvalues = Measurements.value.(additional_pts.x)
            yvalues = Measurements.value.(additional_pts.y)
            Makie.errorbars!(ax, xvalues, yvalues, Measurements.uncertainty.(additional_pts.x) .* xerrscaling, direction = :x, color = :black)
            Makie.errorbars!(ax, xvalues, yvalues, Measurements.uncertainty.(additional_pts.y) .* yerrscaling, color = :black)
            ap = Makie.scatter!(ax, xvalues, yvalues, marker = :circle, color = :silver, strokewidth = 1, strokecolor = :black)
            Makie.axislegend(ax, [ap], ["Data not used for fit" * label_errscaling(xerrscaling, yerrscaling)], position = :rb)
        end
        
        if !isempty(report.gof) && show_residuals

            ax.xticklabelsize = 0
            ax.xticksize = 0
            ax.xlabel = ""

            ax2 = Makie.Axis(g[2,1], yticks = -3:3:3, limits = (xlims,(-5,5)); xlabel, xticks, xtickformat, ylabel = "Residuals (σ)")
            LegendMakie.residualplot!(ax2, (x = Measurements.value.(report.x), residuals_norm = report.gof.residuals_norm))
            # add the additional points
            if !isempty(additional_pts) && length(additional_pts.x) == length(additional_pts.residuals_norm) > 0
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

    # plot report from fit_calibration
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
            additional_pts = if !isempty(additional_pts) && !isempty(additional_pts.µ) && !isempty(additional_pts.peaks)
                # strip the units from the additional points
                μ_strip = Unitful.unit(first(additional_pts.μ)) != Unitful.NoUnits ? Unitful.ustrip.(report.e_unit, additional_pts.μ) : additional_pts.μ
                p_strip = Unitful.unit(first(additional_pts.peaks)) != Unitful.NoUnits ? Unitful.ustrip.(report.e_unit, additional_pts.peaks) : additional_pts.peaks    
                μ_cal = report.f_fit.(μ_strip)
                (x = μ_strip, y = p_strip, residuals_norm = (Measurements.value.(μ_cal) .- Measurements.value.(p_strip))./ Measurements.uncertainty.(μ_cal))
            else
                NamedTuple()
            end,
            xlabel = "Energy (ADC)", ylabel = "Energy ($(report.e_unit))", 
            xlims = (0, 1.1*Measurements.value(maximum(report.x))),
            xtickformat = x -> string.(round.(Int, x)); kwargs...
        )
    end

    # plot report from fit_fwhm
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
            additional_pts = if !isempty(additional_pts) && !isempty(additional_pts.peaks) && !isempty(additional_pts.fwhm)
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
            title::AbstractString = "", yscale = Makie.log10, show_residuals::Bool = true, 
            sf_in_title::Bool = true, watermark::Bool = true, final::Bool = true, kwargs...
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

        ax = Makie.Axis(g[1,1], ylabel = "Counts / $(round(step(first(report.survived.h.edges)), digits=2)) keV", 
            limits = (xlims, ylims); yscale, xlabel, title = sf_in_title ? "$title Survival fraction: $(round(report.sf * 100, digits = 2))%" : title, xticks)
        
        before_data = Makie.plot!(ax, report.survived.h, color = (:gray, 0.5), fillto = 0.5)
        before_fit  = Makie.lines!(ax, range(xlims..., length = 1000), x -> report.survived.f_fit(x) * step(first(report.survived.h.edges)), color = :black)
        Makie.axislegend(ax, [before_data, before_fit], ["Data Survived", "Best Fit" * (!isempty(report.survived.gof) ? " (p = $(round(report.survived.gof.pvalue, digits=2)))" : "")], position = :lt)
        after_data  = Makie.plot!(ax, report.cut.h, color = (:lightgray, 0.5), fillto = 0.5)
        after_fit   = Makie.lines!(ax, range(xlims..., length = 1000), x -> report.cut.f_fit(x) * step(first(report.cut.h.edges)), color = (:gray, 0.5))
        Makie.axislegend(ax, [after_data, after_fit],  ["Data Cut", "Best Fit" * (!isempty(report.cut.gof) ? " (p = $(round(report.cut.gof.pvalue, digits=2)))" : "")], position = :rt)

        if !isempty(report.survived.gof) && show_residuals
            ax2 = Makie.Axis(g[2,1], yticks = -3:3:3, limits = (extrema(first(report.survived.h.edges)), (-5,5)), xlabel = xlabel, xticks = xticks, ylabel = "Residuals (σ)")
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

            if row == 1 && watermark
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
            xlims = extrema(first(report.h_cal.edges)), title::AbstractString = "", titlesize = 18, yscale = Makie.log10,
            ylims = yscale == Makie.log10 ? (10, maximum(report.h_cal.weights)*4) : (0, maximum(report.h_cal.weights)*1.2),
            xlabel = "Peak amplitudes (P.E.)", ylabel = "Counts", xerrscaling = 1,
            row::Int = 1, col::Int = 1, xticks = Makie.automatic, yticks = Makie.automatic,
            legend_position = :rt, watermark::Bool = true, final::Bool = !isempty(title), kwargs...
        )

        fig = Makie.current_figure()

        # create plot
        g = Makie.GridLayout(fig[row,col])
        ax = Makie.Axis(g[1,1], 
            title = title, titlefont = :bold, limits = (xlims, ylims); 
            xlabel, ylabel, xticks, yticks, yscale, titlesize
        )

        Makie.hist!(ax, StatsBase.midpoints(first(report.h_cal.edges)), weights = report.h_cal.weights, bins = first(report.h_cal.edges), color = LegendMakie.DiamondGrey, label = "Amplitudes", fillto = 1e-2)
        Makie.lines!(range(extrema(first(report.h_cal.edges))..., length = 1000), x -> report.f_fit(x), linewidth = 2, color = :black, label = ifelse(show_label, "Best Fit" * (!isempty(report.gof) ? " (p = $(round(report.gof.pvalue, digits=2)))" : ""), nothing))

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

    # plot report from filter optimzations, e.g. fit_enc_sigmas, fit_fwhm_ft, fit_sf_wl 
    function LegendMakie.lplot!(
            report::NamedTuple{(:x, :minx, :y, :miny)};
            title::AbstractString = "", xunit = Unitful.unit(first(report.x)), yunit = Unitful.unit(first(report.y)),
            xlabel = "", ylabel = "", xlegendlabel = xlabel, ylegendlabel = ylabel, obj = "Min.", xticks = Makie.WilkinsonTicks(6, k_min = 5),  
            xlims = Unitful.ustrip.(xunit, extrema(report.x) .+ (-1, 1) .* (report.x[2] - report.x[1])),
            ylims = max.(0, Unitful.ustrip.(yunit, extrema(Measurements.value.(report.y)) .- (-1, 1) .* (-)(extrema(Measurements.value.(report.y))...) .* 0.1)),
            legend_position = :rt, watermark::Bool = true, final::Bool = !isempty(title), kwargs...
        )

        fig = Makie.current_figure()

        ax = Makie.Axis(fig[1,1];
            title, limits = (xlims, ylims), xticks,
            xlabel = (xlabel * ifelse(xunit == Unitful.NoUnits, "", " ($xunit)")) |> typeof(xlabel),
            ylabel = (ylabel * ifelse(yunit == Unitful.NoUnits, "", " ($yunit)")) |> typeof(ylabel)
        )

        Makie.errorbars!(ax, Unitful.ustrip.(xunit, report.x), Unitful.ustrip.(yunit, Measurements.value.(report.y)), Unitful.ustrip.(yunit, Measurements.uncertainty.(report.y)))
        Makie.scatter!(ax, Unitful.ustrip.(xunit, report.x), Unitful.ustrip.(yunit, Measurements.value.(report.y)), label = ylegendlabel)
        Makie.hlines!(ax, [Unitful.ustrip(yunit, Measurements.value(report.miny))], color = :red, 
            label = "$(obj) $(ylegendlabel) $(let v = round_wo_units(report.miny, digits = 2); isnan(Measurements.uncertainty(v)) ? Measurements.value(v) : v end)\n($(xlegendlabel): $(report.minx))")
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
            xlabel = "Flat-Top Time", ylabel = "FWHM", xlegendlabel = "FT", ylegendlabel = "FWHM", obj = "Opt.", kwargs...
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

    # plot report from singlefits, e.g. fit_single_trunc_gauss
    function LegendMakie.lplot!(
            report::NamedTuple{(:f_fit, :h, :μ, :σ, :gof)};
            title::AbstractString = "", titlesize = 18, 
            show_residuals::Bool = true, row::Int = 1, col::Int = 1,
            ylims = (minimum(filter(x -> x > 0, report.h.weights)),nothing), xlabel = "", xticks = Makie.WilkinsonTicks(6, k_min=5), digits = 2,
            xlims = Unitful.ustrip.(Measurements.value.((report.μ - 5*report.σ, report.μ + 5*report.σ))), 
            yscale = Makie.log10,
            legend_position = :lt, watermark::Bool = true, final::Bool = !isempty(title), kwargs...
        )

        fig = Makie.current_figure()
        
        g = Makie.GridLayout(fig[row,col])
        ax = Makie.Axis(g[1,1], 
            titlefont = :bold, limits = (xlims, ylims), ylabel = "Normalized Counts";
            yscale, title, xlabel, xticks, titlesize 
        )
        
        # Create histogram
        Makie.plot!(ax, report.h, label = "Data")
        
        _x = range(extrema(xlims)..., length = 1000)
        Makie.lines!(_x, report.f_fit.(_x), color = :red, 
            label = "Normal Fit\nμ = $(round_wo_units(report.μ; digits))\nσ = $(round_wo_units(report.σ; digits))")
        
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

    # plot QC cut window fits
    function LegendMakie.lplot!(report::NamedTuple{(:f_fit, :h, :μ, :σ, :gof, :low_cut, :high_cut)}; show_residuals::Bool = true, legend_position = :lt, kwargs...)
        n_σ = round_wo_units(Measurements.value((report.µ - report.low_cut) / report.σ), digits=1)
        # plot simpel gaussian fit
        fig = LegendMakie.lplot!(
            NamedTuple{(:f_fit, :h, :μ, :σ, :gof)}(report); 
            xlims = Unitful.ustrip.(Measurements.value.((report.μ - 2.5*n_σ*report.σ, report.μ + 1.5*n_σ*report.σ))),
            legend_position=:none, show_residuals = show_residuals,
            kwargs...)
        
        # get axis and plot the cut window
        ax = if !isempty(report.gof) && show_residuals
            fig.content[end-1]
        else
            fig.content[end]
        end
        Makie.current_axis!(ax)

        Makie.vspan!(ax, Unitful.ustrip.(Measurements.value.((report.low_cut, report.high_cut)))..., color=LegendMakie.CoaxGreen, alpha=0.05, label=nothing)
        Makie.vlines!(ax, Unitful.ustrip.(Measurements.value.([report.low_cut, report.high_cut])), linewidth=2.5, color=LegendMakie.CoaxGreen, label="$(n_σ)σ cut window")
        if legend_position != :none 
            Makie.axislegend(ax, position = legend_position)
        end
        fig
    end

    # plot reports from fit_peaks
    function LegendMakie.lplot!(
            report::NamedTuple{(:v, :h, :f_fit, :f_components, :gof)};
            xunit = u"keV", xlabel = "Energy ($xunit)", ylabel = "Counts / $(round(step(first(report.h.edges)), digits = 2)) $xunit",
            title::AbstractString = "", titlesize = 18, legend_position = :lt,
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
            titlefont = :bold, limits = (xlims, ylims), yscale = Makie.log10;
            title, xlabel, ylabel, yticks, titlesize
        )

        data = Makie.hist!(ax, StatsBase.midpoints(first(report.h.edges)), weights = report.h.weights, bins = first(report.h.edges), color = LegendMakie.DiamondGrey)
        fit = Makie.lines!(range(extrema(first(report.h.edges))..., length = 1000), x -> report.f_fit(x) * step(first(report.h.edges)), color = :black)
        
        if legend_position != :none 
            Makie.axislegend(ax, show_label ? [data, fit] : [data],
                show_label ? ["Data", "Best Fit" * (!isempty(report.gof) ? " (p = $(round(report.gof.pvalue, digits=2)))" : "")] : ["Data"], 
                position = :lt)
        end

        if show_components
            for (idx, component) in enumerate(keys(report.f_components.funcs))
                Makie.lines!(
                    range(extrema(first(report.h.edges))..., length = 1000), 
                    x -> report.f_components.funcs[component](x) * step(first(report.h.edges)), 
                    color = report.f_components.colors[component], 
                    label = ifelse(show_label, report.f_components.labels[component], nothing),
                    linestyle = report.f_components.linestyles[component],
                    linewidth = 4
                )
            end
    
            if legend_position != :none 
                Makie.axislegend(ax, position = :rt)
            end
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

    # plot report from simple_calibration
    function LegendMakie.lplot!(
            report::NamedTuple{(:h_calsimple, :h_uncal, :c, :peak_guess, :peakhists, :peakstats)};
            cal::Bool = true, h = StatsBase.normalize(cal ? report.h_calsimple : report.h_uncal, mode = :density),
            title::AbstractString = "", titlegap = 2, titlesize = 18, label = "Energy",
            xlims = (0, cal ? 3000 : 1.2*report.peak_guess), xlabel = "Energy ($(cal ? "keV" : "ADC"))", 
            xticks = cal ? (0:300:3000) : (0:50000:1.2*report.peak_guess),
            ylims = extrema(filter(x -> x > 0, h.weights)) .* (0.99, 1.2 * 1.1), 
            ylabel = "Counts / $(round(step(first(h.edges)), digits = 2)) $(cal ? "keV" : "ADC")", 
            yscale = Makie.log10,
            watermark::Bool = true, final::Bool = !isempty(title), kwargs...
        )
        
        fig = Makie.current_figure()
        
        # select correct histogram
        peak_guess = cal ? Unitful.ustrip(report.c * report.peak_guess) : report.peak_guess

        # create main histogram plot
        ax = Makie.Axis(
            fig[1,1];
            title, titlegap = titlegap, titlesize = titlesize,
            limits = (xlims, ylims),
            xticks, xlabel, ylabel, yscale
        )
        
        Makie.stephist!(ax, StatsBase.midpoints(first(h.edges)), bins = first(h.edges), weights = h.weights, label = "Energy")
        Makie.vlines!(ax, [peak_guess], color = :red, label = "FEP Guess", linewidth = 1.5)
        Makie.axislegend(ax, position = :ct)
        
        # add watermarks
        Makie.current_axis!(ax)
        watermark && LegendMakie.add_watermarks!(; final, kwargs...)
        
        fig
    end

    # plot report from fit_aoe_corrections
    function LegendMakie.lplot!( 
            report::NamedTuple{(:par, :f_fit, :x, :y, :gof, :e_unit, :label_y, :label_fit)}; 
            title::AbstractString = "", titlesize = 18, show_residuals::Bool = true,
            xticks = 500:250:2250, xlims = (500,2300), ylims = nothing,
            legend_position = :rt, row::Int = 1, col::Int = 1, 
            watermark::Bool = true, final::Bool = !isempty(title), kwargs...
        )

        fig = Makie.current_figure()

        # create plot
        g = Makie.GridLayout(fig[row,col])
        ax = Makie.Axis(g[1,1], 
            titlefont = :bold, limits = (xlims, ylims),
            xlabel = "E ($(report.e_unit))", ylabel = report.label_y * " (a.u.)";
            title, xticks
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

    # plot report fit_aoe_compton_combined
    function LegendMakie.lplot!( 
            report::NamedTuple{(:par, :f_fit, :x, :y, :gof, :e_unit, :label_y, :label_fit)},
            com_report::NamedTuple{(:values, :label_y, :label_fit, :energy)};
            legend_position = :rt, row::Int = 1, col::Int = 1, kwargs...
        )

        fig = LegendMakie.lplot!(report, legend_position = :none, col = col; kwargs...)

        g = last(Makie.contents(fig[row,col]))
        ax = Makie.contents(g)[1]
        Makie.lines!(ax, com_report.energy, com_report.values, linewidth = 4, color = :red, linestyle = :dash, label = LaTeXStrings.latexstring("\\fontfamily{Roboto}" * com_report.label_fit))
        Makie.axislegend(ax, position = legend_position, framevisible = true, framecolor = :lightgray, backgroundcolor = :white)

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
            xlabelsize = 16,
            ylabelsize = 16,
            xticklabelsize = 13,
            yticklabelsize = 13,
            yticks = (exp10.(0:10), "1" .* join.(fill.("0", 0:10))),
            limits = (extrema(first(report.dep_h_before.edges)), (0.9, max(100, maximum(report.dep_h_before.weights)) * 1.2))
        )
        Makie.stephist!(ax_inset, StatsBase.midpoints(first(report.dep_h_before.edges)),    weights = replace(report.dep_h_before.weights, 0 => 1e-10),    bins = first(report.dep_h_before.edges),    color = (LegendMakie.AchatBlue, 0.5))
        Makie.stephist!(ax_inset, StatsBase.midpoints(first(report.dep_h_after_low.edges)), weights = replace(report.dep_h_after_low.weights, 0 => 1e-10), bins = first(report.dep_h_after_low.edges), color = (LegendMakie.BEGeOrange, 1))
        Makie.stephist!(ax_inset, StatsBase.midpoints(first(report.dep_h_after_ds.edges)),  weights = replace(report.dep_h_after_ds.weights, 0 => 1e-10),  bins = first(report.dep_h_after_ds.edges),  color = (LegendMakie.CoaxGreen, 0.5))

        # add watermarks
        Makie.current_axis!(ax)
        watermark && LegendMakie.add_watermarks!(; final, kwargs...)

        fig
    end


    # plot report from ctc_energy
    function LegendMakie.lplot!(
            report::NamedTuple{(:peak, :window, :fct, :bin_width, :bin_width_qdrift, :e_peak, :e_ctc, :qdrift_peak, :h_before, :h_after, :fwhm_before, :fwhm_after, :report_before, :report_after)};
            title::AbstractString = "", titlesize = 18, titlegap = 0, e_unit = u"keV", 
            label_before = "Before correction", label_after = "After correction",  
            xlabel = "Energy ($e_unit)", ylabel = "Qdrift / E (a.u.)",
            xlims = (StatsBase.midpoints(first(report.h_before.edges))[argmax(report.h_before.weights)] - 3 * Unitful.ustrip(e_unit, Measurements.value(report.fwhm_before)),
            StatsBase.midpoints(first(report.h_after.edges))[argmax(report.h_after.weights)] + 3 * Unitful.ustrip(e_unit, Measurements.value(report.fwhm_after))), 
            xticks = Makie.WilkinsonTicks(4, k_min = 3, k_max = 5), watermark::Bool = true, kwargs...
        )

        # Best results for figsize (600,600)
        fig = Makie.current_figure()

        g = Makie.GridLayout(fig[1,1])

        ax = Makie.Axis(g[1,1], limits = (xlims...,0,nothing), ylabel = "Counts / $(round(step(first(report.h_before.edges)), digits = 2)) $e_unit"; xticks)
        before = Makie.plot!(ax, report.h_before, color = :darkgrey, label = label_before)
        after  = Makie.plot!(ax, report.h_after, color = (:purple, 0.5), label = label_after)
        ax_legend = Makie.Axis(g[1,2])
        Makie.hidedecorations!(ax_legend)
        Makie.hidespines!(ax_legend)
        Makie.axislegend(ax_legend, [before, after], [label_before, label_after], position = (0,1))

        ax2 = Makie.Axis(g[2,1], limits = (xlims...,0,1-1e-5), yticks = 0:0.2:1; xlabel, ylabel, xticks)
        k_before = KernelDensity.kde((Unitful.ustrip.(e_unit, report.e_peak), report.qdrift_peak ./ maximum(report.qdrift_peak)))
        k_after = KernelDensity.kde((Unitful.ustrip.(e_unit, report.e_ctc), report.qdrift_peak ./ maximum(report.qdrift_peak)))
        Makie.contourf!(ax2, k_before.x, k_before.y, k_before.density, levels = 15, colormap = :binary)
        Makie.contour!(ax2, k_before.x, k_before.y, k_before.density, levels = 15 - 1, color = :white)
        Makie.contour!(ax2, k_after.x, k_after.y, k_after.density, levels = 15 - 1, colormap = :plasma)
        Makie.lines!(ax2, [0], [0], label = label_before, color = :darkgrey)
        Makie.lines!(ax2, [0], [0], label = label_after, color = (:purple, 0.5))
        #Makie.axislegend(ax2, position = :lb)

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
            Makie.Label(g[1,:,Makie.Top()], title, padding = (0,0,titlegap,0), fontsize = titlesize, font = :bold)
        end

        # add watermarks
        Makie.current_axis!(ax3)
        watermark && LegendMakie.add_watermarks!(; kwargs...)

        fig
    end


    # plot report from ctc_aoe
    function LegendMakie.lplot!( 
            report::NamedTuple{(:peak, :window, :fct, :bin_width, :bin_width_qdrift, :aoe_peak, :aoe_ctc, :aoe_ctc_norm, :qdrift_peak, :h_before, :h_after, :h_after_norm, :σ_before, :σ_after, :σ_after_norm, :report_before, :report_after, :report_after_norm)};
            label_before = "Before correction", label_after = "After correction", levels = 15,
            xlims = (-9,5), ylims = StatsBase.quantile.(Ref(report.qdrift_peak), (0.005, 0.995)), xticks = Makie.WilkinsonTicks(6,k_min=5), yticks = Makie.WilkinsonTicks(6,k_min=4),
            title::AbstractString = "", titlesize = 18, titlegap = 0, norm::Bool = false,
            xlabel = "A/E classifier", ylabel = "Qdrift / E",
            watermark::Bool = true, kwargs...
        )

        # Best results for figsize (600,600)
        fig = Makie.current_figure()
        
        g = Makie.GridLayout(fig[1,1])
        
        ax = Makie.Axis(g[1,1], limits = (xlims,(0,nothing)), ylabel = "Counts / $(round(step(first(report.h_before.edges)), digits = 2))")
        h_before = Makie.plot!(ax, report.h_before, color = :darkgrey)
        h_after  = Makie.plot!(ax, norm ? report.h_after_norm : report.h_after, color = (:purple, 0.5))
        
        ax3 = Makie.Axis(g[1,2])
        Makie.hidedecorations!(ax3)
        Makie.hidespines!(ax3)
        Makie.axislegend(ax3, [h_before, h_after], [label_before, label_after], position = :lt)
        
        ax2 = Makie.Axis(g[2,1]; limits = (xlims, ylims), xticks, yticks, xlabel, ylabel)
        k_before = KernelDensity.kde((report.aoe_peak, report.qdrift_peak))
        k_after = KernelDensity.kde((norm ? report.aoe_ctc_norm : report.aoe_ctc, report.qdrift_peak))
        Makie.contourf!(ax2, k_before.x, k_before.y, k_before.density, levels = levels, colormap = :binary)
        Makie.contour!(ax2, k_before.x, k_before.y, k_before.density, levels = levels - 1, color = :white)
        Makie.contour!(ax2, k_after.x, k_after.y, k_after.density, levels = levels - 1, colormap = :plasma)
        # Makie.lines!(ax2, [0], [0], label = label_before, color = :darkgrey)
        # Makie.lines!(ax2, [0], [0], label = label_after, color = (:purple, 0.5))
        # Makie.axislegend(position = :lb)
        
        ax3 = Makie.Axis(g[2,2], limits = ((0,nothing),ylims), xlabel = "Counts / 0.1")
        Makie.plot!(ax3, StatsBase.fit(StatsBase.Histogram, report.qdrift_peak, 0:0.1:ylims[2]+0.1), color = :darkgrey, direction = :x)
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
            Makie.Label(g[1,:,Makie.Top()], title, padding = (0,0,titlegap,0), fontsize = titlesize, font = :bold)
        end
        
        # add watermarks
        Makie.current_axis!(ax3)
        watermark && LegendMakie.add_watermarks!(; kwargs...)
        
        fig
    end


    # LQ plots
    function LegendMakie.lplot!(
            report::NamedTuple{(:hist_dep, :hist_sb1, :hist_sb2, :hist_subtracted, :hist_corrected)};
            title::AbstractString = "", titlesize = 18, titlegap = 2, legend_position = :rt, 
            xlabel = Makie.rich("LQ", Makie.subscript(" ctc")), 
            ylabel = "Counts / $(round(step(first(report.hist_dep.edges)), digits = 2))", 
            xticks = Makie.WilkinsonTicks(6, k_min = 5),
            xlims = nothing, ylims = (0.9, maximum(report.hist_dep.weights)*1.2), yscale = Makie.log10,
            watermark::Bool = true, final::Bool = !isempty(title), kwargs...
        )
    
        
        fig = Makie.current_figure()
        ax = Makie.Axis(fig[1,1]; limits = (xlims, ylims), title, titlesize, titlegap, xlabel, ylabel, xticks, yscale)
        
        let h = report.hist_dep, h1 = report.hist_sb1, h2 = report.hist_sb2
        Makie.stephist!(ax, first(h.edges)  .- step(first(h.edges))/2,  bins = [first(first(h.edges))-step(first(h.edges)); first(h.edges)],    weights = replace([0.; h.weights], 0 => 1e-10), label = "DEP")
        Makie.stephist!(ax, first(h1.edges) .- step(first(h1.edges))/2, bins = [first(first(h1.edges))-step(first(h1.edges)); first(h1.edges)], weights = replace([0.; h1.weights], 0 => 1e-10), label = "Sideband 1")
        Makie.stephist!(ax, first(h2.edges) .- step(first(h2.edges))/2, bins = [first(first(h1.edges))-step(first(h1.edges)); first(h1.edges)], weights = replace([0.; h2.weights], 0 => 1e-10), label = "Sideband 2")
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
            xlabelsize = 16,
            ylabelsize = 16,
            xticklabelsize = 13,
            yticklabelsize = 13,
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
            title::AbstractString = "", titlesize = 18, titlegap = 2,
            h = StatsBase.fit(StatsBase.Histogram, Unitful.ustrip.(e_unit, report.e_cal), 1500:1:1650),
            xlims = extrema(first(h.edges)), ylims = (0, maximum(h.weights)*1.2), 
            xticks = Makie.WilkinsonTicks(6,k_min=5), xlabel = "Energy ($e_unit)", ylabel = "Counts / 1 $(e_unit)",
            legend_position = :lt, watermark::Bool = true, final::Bool = !isempty(title), kwargs...
        )
        
        fig = Makie.current_figure()
        
        ax = Makie.Axis(fig[1,1], limits = (xlims, ylims); title, titlesize, titlegap, xlabel, ylabel, xticks)
        
        Makie.stephist!(ax, StatsBase.midpoints(first(h.edges)), weights = h.weights, bins = first(h.edges),
            label = "Energy (σ: $(round(e_unit, report.dep_σ, digits=2)))")
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
            title::AbstractString = "", xlabel = "Qdrift/E (a.u.)", ylabel = "LQ/E (a.u.)", 
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
            Makie.lines!([2l-r,2r-l], report.drift_time_func.([2l-r,2r-l]), linewidth = 3, 
                color = LegendMakie.BEGeOrange, label = "Best Fit")
        end
        Makie.axislegend(position = :lt, framevisible = plot_type == :whole, framewidth = 1, framecolor = :lightgray)
        LegendMakie.add_watermarks!(; position = "outer top", final, kwargs...)
    end


    # plot report of sipm_simple_calibration
    function LegendMakie.lplot!(
            report::NamedTuple{(:peakpos, :peakpos_cal, :h_uncal, :h_calsimple)};
            cal::Bool = true, title::AbstractString = "", titlesize = 18, titlegap = 2,
            h = cal ? report.h_calsimple : report.h_uncal,
            label = "Amplitudes", peak_label = "Reconstructed\npeak positions",
            xlims = (0, last(first(h.edges))), ylims = (0.99*minimum(filter(x -> x > 0, h.weights)), maximum(h.weights)*1.2),
            yscale = Makie.log10, xlabel = "Peak Amplitudes ($(cal ? "P.E." : "ADC"))",
            ylabel = "Counts / $(round_wo_units(step(first(h.edges)), digits = 2)) $(cal ? "P.E." : "ADC")",
            xticks = cal ? (0:0.5:last(first(h.edges))) : Makie.WilkinsonTicks(6, k_min=5),
            legend_position = :rt, final::Bool = !isempty(title), watermark::Bool = true, kwargs...
        )

        # create histogram
        fig = LegendMakie.lplot!(h; limits = (xlims, ylims), title, titlesize, titlegap, xticks, xlabel, ylabel, yscale, label, legend_position = :none, kwargs...)
        ax = Makie.current_axis()
    
        # add peak positions
        Makie.vlines!(ax, cal ? report.peakpos_cal : report.peakpos, color = :red, label = peak_label, linewidth = 1.5)
        legend_position != :none && Makie.axislegend(ax, framevisible = true, framewidth = 0, position = legend_position)

        # add watermarks
        Makie.current_axis!(ax)
        watermark && LegendMakie.add_watermarks!(; final, kwargs...)

        fig
    end


    # Dict of reports (vertical alignment)
    function LegendMakie.lplot!(
            reports::AbstractDict{<:Any, NamedTuple}; title::AbstractString = "", 
            watermark::Bool = true, final::Bool = true, titlesize = 20, subplot_titlesize = 18, kwargs...
        )

        fig = Makie.current_figure()

        isempty(reports) && throw(ArgumentError("Cannot plot empty dictionary."))
        
        for (i,(k,report)) in enumerate(reports)
            LegendMakie.lplot!(report, title = string(k), titlesize = subplot_titlesize, row = i, watermark = false; kwargs...)
        end

        # add general title
        if !isempty(title)
            Makie.Label(fig[1,:,Makie.Top()], title, padding = (0,0,35,0), fontsize = titlesize, font = :bold)
        end

        # add watermarks
        Makie.current_axis!(first(fig.content))
        watermark && LegendMakie.add_watermarks!(; final, kwargs...)

        fig
    end

end
