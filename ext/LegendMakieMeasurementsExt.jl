# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

module LegendMakieMeasurementsExt

    import LegendMakie

    import LaTeXStrings
    import Makie
    import Measurements
    import Unitful

    import LegendMakie: pt, aoecorrectionplot!, energycalibrationplot!

    # extends LegendMakie.default_xlims in LegendMakieExt.jl
    # for the cases where μ and σ have uncertainties
    function LegendMakie.default_xlims(report::NamedTuple{(:f_fit, :h, :μ, :σ, :gof),<:Tuple{Any,Any,M,M,Any}}
        ) where {M <: Union{Measurements.Measurement, Unitful.Quantity{<:Measurements.Measurement}}}
        Unitful.ustrip.(Measurements.value.((report.μ - 5*report.σ, report.μ + 5*report.σ)))
    end

    # function to compose labels when errorbars are scaled
    function label_errscaling(xerrscaling::Real, yerrscaling::Real)
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
            watermark::Bool = true, final::Bool = (title != ""), kwargs...
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


end