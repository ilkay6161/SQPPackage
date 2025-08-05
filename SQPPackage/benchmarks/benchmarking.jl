module Benchmarking
using LinearAlgebra, Printf
import Plots
using ADNLPModels

export get_primal_residual, get_dual_residual, performance_profile

function get_primal_residual(nlp::ADNLPModel, x::Vector{Float64}, c::Vector{Float64})
    lvar, uvar = nlp.meta.lvar, nlp.meta.uvar
    lcon, ucon = nlp.meta.lcon, nlp.meta.ucon
    h_eq = 0.0
    h_ineq = 0.0
    
    # Constraint violations
    for i in eachindex(c)
        if lcon[i] ≈ ucon[i]
            h_eq = max(h_eq, abs(c[i] - ucon[i]))
        else
            violation = max(0.0, c[i] - ucon[i], lcon[i] - c[i])
            h_ineq = max(h_ineq, violation)
        end
    end
    
    # Variable bound violations
    h_bounds = 0.0
    for i in eachindex(x)
        if isfinite(uvar[i]) h_bounds = max(h_bounds, max(0.0, x[i] - uvar[i])) end
        if isfinite(lvar[i]) h_bounds = max(h_bounds, max(0.0, lvar[i] - x[i])) end
    end
    
    return max(h_eq, h_ineq, h_bounds)
end

function get_dual_residual(nlp::ADNLPModel, x::Vector, y::Vector, zL::Vector, zU::Vector, g::Vector)
    A = nlp.meta.ncon > 0 ? jac(nlp, x) : zeros(0, length(x))
    grad_lag = g + A' * y + (zU - zL)
    return norm(grad_lag, Inf)
end

function performance_profile(times, names; title="Performance Profile", logscale=false)
    # Logarithmisch verteilte τ-Werte
    τ = exp.(range(log(1), log(100), length=100))
    
    # Erstelle Plot mit besserem Styling
    plt = Plots.plot(
        xlabel="Performance Ratio τ", 
        ylabel="Fraction of Problems Solved ρ(τ)", 
        title=title, 
        legend=:bottomright,
        grid=true,
        size=(800, 600),
        dpi=300
    )
    
    # Farben für verschiedene Solver
    colors = [:blue, :red, :green, :orange, :purple, :brown, :pink, :gray]
    
    for (i, solver) in enumerate(names)
        # Identifiziere erfolgreiche Läufe
        finite_mask = isfinite.(times[:, i])
        
        if !any(finite_mask)
            # Keine erfolgreichen Läufe
            Plots.plot!(plt, τ, zeros(length(τ)), 
                       label="$solver (keine Lösungen)", 
                       lw=3, 
                       linestyle=:dash,
                       color=colors[mod(i-1, length(colors)) + 1])
            continue
        end
        
        # Berechne Performance-Ratios
        r = fill(Inf, size(times, 1))
        for j in 1:size(times, 1)
            if any(isfinite.(times[j, :]))  # Mindestens ein Solver hat das Problem gelöst
                min_time = minimum(times[j, isfinite.(times[j, :])])
                if finite_mask[j]
                    r[j] = times[j, i] / min_time
                end
            end
        end
        
        # Berechne ρ(τ)
        ρ = [count(r .<= t) / size(times, 1) for t in τ]
        
        Plots.plot!(plt, τ, ρ, 
                   label=solver, 
                   lw=3,
                   color=colors[mod(i-1, length(colors)) + 1])
    end
    
    # Achsenkonfiguration
    Plots.ylims!(plt, 0, 1)
    if logscale
        Plots.plot!(plt, xscale=:log10)
        Plots.xlims!(plt, 1, 100)
    else
        Plots.xlims!(plt, 1, 20)
    end
    
    # Referenzlinien
    Plots.hline!(plt, [0.5, 0.8], color=:gray, linestyle=:dot, alpha=0.5, label="")
    
    return plt
end
end