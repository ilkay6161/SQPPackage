# benchmarking.jl
module Benchmarking
using LinearAlgebra, Printf, Plots
using ADNLPModels
using SQPPackage: SQPPackage.StatsModule, SQPPackage.ResidualsModule

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
    # Create logarithmically spaced points from 1 to 100
    τ = exp.(range(log(1), log(100), length=100))
    
    # Create plot with better styling
    plt = Plots.plot(
        xlabel="Performance Ratio τ", 
        ylabel="Fraction of Problems Solved ρ(τ)", 
        title=title, 
        legend=:bottomright,
        grid=true,
        gridwidth=1,
        gridcolor=:gray,
        gridalpha=0.3,
        size=(800, 600),
        dpi=300,
        fontsize=12
    )
    
    # Define colors for different solvers/strategies
    colors = [:blue, :red, :green, :orange, :purple, :brown, :pink, :gray, :cyan, :magenta]
    
    for (i, solver) in enumerate(names)
        # Calculate performance ratios, handling infinite values properly
        finite_mask = isfinite.(times[:, i])
        if !any(finite_mask)
            # If no finite times for this solver, plot at ρ = 0
            Plots.plot!(plt, τ, zeros(length(τ)), 
                       label="$solver (no solutions)", 
                       lw=3, 
                       linestyle=:dash,
                       color=colors[mod(i-1, length(colors)) + 1])
            continue
        end
        
        # For each problem, find the minimum time across all solvers
        min_times = [minimum(times[j, isfinite.(times[j, :])]) for j in 1:size(times, 1) if any(isfinite.(times[j, :]))]
        
        if isempty(min_times)
            continue
        end
        
        # Calculate ratios only for problems where this solver succeeded
        r = fill(Inf, size(times, 1))
        for j in 1:size(times, 1)
            if finite_mask[j] && any(isfinite.(times[j, :]))
                min_time_for_problem = minimum(times[j, isfinite.(times[j, :])])
                r[j] = times[j, i] / min_time_for_problem
            end
        end
        
        # Calculate ρ(τ) - fraction of problems solved within τ times the best
        ρ = [count(r .<= t) / size(times, 1) for t in τ]
        
        Plots.plot!(plt, τ, ρ, 
                   label=solver, 
                   lw=3, 
                   color=colors[mod(i-1, length(colors)) + 1])
    end
    
    # Set axis limits and scale
    Plots.ylims!(plt, 0, 1)
    if logscale
        Plots.plot!(plt, xscale=:log10)
        Plots.xlims!(plt, 1, 100)
    else
        Plots.xlims!(plt, 1, 20)  # Focus on more relevant range for linear scale
    end
    
    # Add horizontal lines for reference
    Plots.hline!(plt, [0.5, 0.8], color=:gray, linestyle=:dot, alpha=0.5, label="")
    
    return plt
end
end