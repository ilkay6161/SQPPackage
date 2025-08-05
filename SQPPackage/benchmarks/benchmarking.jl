module Benchmarking
using LinearAlgebra, Printf
import Plots
using SQPPackage.StatsModule, SQPPackage.ResidualsModule
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
    # Ersetze logspace durch eine korrekte geometrische Sequenz
    τ = 10 .^ range(0, 2, length=100)  # Werte von 10^0=1 bis 10^2=100
    
    plt = Plots.plot(xlabel="τ", ylabel="ρ(τ)", title=title, legend=:bottomright)
    
    for (i, solver) in enumerate(names)
        r = times[:,i] ./ minimum(times, dims=2)
        # Setze NaN/Inf-Werte auf eine hohe Zahl
        r[isnan.(r)] = Inf
        ρ = [count(r .<= t) / size(times,1) for t in τ]
        Plots.plot!(plt, τ, ρ, label=solver, lw=2)
    end
    
    if logscale
        Plots.plot!(plt, xscale=:log10)
    end
    
    return plt
end
end