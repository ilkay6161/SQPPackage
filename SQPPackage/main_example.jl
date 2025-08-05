#!/usr/bin/env julia

"""
Hauptdatei für SQP-Solver Tests

"""

# Pakete laden
push!(LOAD_PATH, "src")
using SQPPackage
using ADNLPModels
using Printf
using LinearAlgebra  # <-- FEHLERBEHEBUNG: norm importieren

function fmt_num(x::Float64)
    if x == 0.0
        return " 0.00e+00"
    elseif abs(x) < 1e-10
        return @sprintf(" % .2e", x)
    else
        return @sprintf(" % .4e", x)
    end
end

function compare_solutions(name::String, x_sqp::Vector{Float64}, x_ipopt::Vector{Float64},
                           y_sqp::Vector{Float64}, y_ipopt::Vector{Float64},
                           z_sqp::Vector{Float64}, z_ipopt::Vector{Float64})
    """Vergleicht Lösungen zwischen SQP und Ipopt (x, y, z)"""
    println("="^60)
    println("Vergleich für $name:")
    println("-"^60)
    println("  x_sqp  = ", round.(x_sqp, digits=6))
    println("  x_ipopt= ", round.(x_ipopt, digits=6))
    println("  Diff x = ", round.(norm(x_sqp - x_ipopt), digits=6))

    if length(y_sqp) > 0 && length(y_ipopt) > 0
        println("  y_sqp  = ", round.(y_sqp, digits=6))
        println("  y_ipopt= ", round.(y_ipopt, digits=6))
        println("  Diff y = ", round.(norm(y_sqp - y_ipopt), digits=6))
    else
        println("  Keine Constraint-Multiplikatoren zu vergleichen")
    end

    if length(z_sqp) > 0 && length(z_ipopt) > 0
        println("  z_sqp  = ", round.(z_sqp, digits=6))
        println("  z_ipopt= ", round.(z_ipopt, digits=6))
        println("  Diff z = ", round.(norm(z_sqp - z_ipopt), digits=6))
    else
        println("  Keine Bound-Multiplikatoren zu vergleichen")
    end
    println("="^60)
end
function run_all_problems()
    """Führt alle Testprobleme aus und vergleicht SQP-Varianten mit Ipopt"""
    
    problems = [
        ("P1", create_P1),
        # ... (andere Probleme)
    ]

    println("="^80)
    println("SQP vs IPOPT Vergleichstests - MIT EIGENEM SQP UND SOC")
    println("="^80)

    for (name, prob_func) in problems
        println("\n" * "="^50)
        println("Problem: $name")
        println("="^50)

        prob = prob_func()
        
        # Konfigurationen für eigenes SQP
        sqp_configs = [
            ("Eigenes SQP ohne SOC", Settings(
                max_iter=100, 
                tol=1e-6, 
                use_globalization=true, 
                use_soc=false,  # SOC deaktiviert
                #qp_solver=:osqp,
                verbose=false
            )),
            ("Eigenes SQP mit SOC", Settings(
                max_iter=100, 
                tol=1e-6, 
                use_globalization=true, 
                use_soc=true,   # SOC aktiviert
                #qp_solver=:osqp,
                verbose=false
            ))
        ]

        # Eigenes SQP mit beiden Konfigurationen testen
        for (config_name, settings) in sqp_configs
            try
                println("\nTeste $config_name...")
                stats = sqp_method(prob, settings)
                
                println("  Status: ", stats.sqp_status)
                println("  Objective: ", fmt_num(stats.obj_val))
                println("  Primal feasibility: ", fmt_num(stats.inf_pr))
                println("  Dual feasibility: ", fmt_num(stats.inf_du))
                println("  Iterations: ", length(stats.iteration_data))
                println("  Time: ", round(stats.total_time, digits=3), "s")
                
                # Vergleiche mit Ipopt wenn möglich
                if stats.sqp_status == kkt_point
                    println("\nVergleich mit Ipopt für $config_name:")
                    x_ipopt, y_ipopt, zL_ipopt, zU_ipopt, status_ipopt = solve_with_ipopt_adnlp(prob)
                    if status_ipopt in [:first_order, :acceptable]
                        z_ipopt = zU_ipopt - zL_ipopt
                        compare_solutions(
                            config_name, 
                            stats.x, x_ipopt, 
                            stats.y, y_ipopt, 
                            stats.z, z_ipopt
                        )
                    else
                        println("  Ipopt nicht erfolgreich für Vergleich")
                    end
                end
                
            catch e
                println("  FEHLER in $config_name: $e")
                showerror(stdout, e)
                catch_backtrace()
            end
        end
        
        # Ipopt als Referenz
        try
            println("\nTeste Ipopt...")
            x_ipopt, y_ipopt, zL_ipopt, zU_ipopt, status_ipopt = solve_with_ipopt_adnlp(prob)
            println("  Status: ", status_ipopt)
            if status_ipopt in [:first_order, :acceptable]
                println("  Objective: ", fmt_num(prob.f(x_ipopt)))
                println("  Solution: ", round.(x_ipopt, digits=6))
            end
        catch err
            println("\nIpopt Fehler: ", err)
        end
    end
end

function demonstrate_soc_effect()
    """Demonstriert den Effekt von SOC auf ein spezifisches Problem"""
    
    println("\n" * "="^80)
    println("SOC-EFFEKT DEMONSTRATION")
    println("="^80)
    
    prob = create_P10()  # Ein Problem, das von SOC profitiert
    
    for use_soc in [false, true]
        config_name = use_soc ? "MIT SOC" : "OHNE SOC"
        println("\nKonfiguration: $config_name")
        
        settings = Settings(
            max_iter=100,
            tol=1e-6,
            use_globalization=true,
            use_soc=use_soc,
            qp_solver=:osqp,
            verbose=false
        )
        
        try
            stats = sqp_method(prob, settings)
            println("  Status: ", stats.sqp_status)
            println("  Iterationen: ", length(stats.iteration_data))
            println("  Finaler Objective: ", fmt_num(stats.obj_val))
            
            # Zeige SOC-Nutzung in Iterationen
            if use_soc
                soc_used = count(iter -> occursin("soc", iter.type), stats.iteration_data)
                println("  SOC-Schritte verwendet: $soc_used")
            end
        catch e
            println("  FEHLER: $e")
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    println("Starte erweiterte SQP-Solver Tests...")
    run_all_problems()
    demonstrate_soc_effect()
    println("\nAlle Tests abgeschlossen!")
end