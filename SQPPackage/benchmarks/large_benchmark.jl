#!/usr/bin/env julia

"""
Aufgabe 2.5: Finaler Löservergleich - Möge der Beste gewinnen!

Dieses umfassende Benchmark-Skript führt einen finalen Vergleich zwischen der
optimalen SQP-Konfiguration (basierend auf den Ergebnissen der Aufgaben 2.1-2.4)
und den etablierten NLP-Lösern MadNLP und Ipopt durch.

Vergleichspartner:
1. SQP-Optimal: Beste Konfiguration aus den vorherigen Aufgaben
2. Ipopt: Etablierter Interior-Point-Löser (Referenz-Standard)
3. MadNLP: Moderner AD-basierter Interior-Point-Löser

Testkriterien:
- Faire Vergleichsbedingungen (gleiche Toleranzen, Zeitlimits)
- Umfassende Problemsets (TestProblems + OptimizationProblems.jl ≥250 Variablen)
- Detaillierte Performance-Analyse mit verschiedenen Metriken
- Robustheitsanalyse bei verschiedenen Problemtypen

Bewertungsmetriken:
- Erfolgsrate (Prozent gelöster Probleme)
- Durchschnittliche Laufzeit pro Problem
- Performance-Profile für relative Effizienz
- Robustheit bei verschiedenen Problemgrößen und -typen

Ziel: Objektive Bewertung der SQP-Implementierung im Vergleich zu professionellen Lösern
"""

# Füge das übergeordnete Verzeichnis zum Ladepfad hinzu, um SQPPackage zu finden
push!(LOAD_PATH, joinpath(@__DIR__, ".."))
push!(LOAD_PATH, @__DIR__)

# Importiere alle benötigten Pakete
using SQPPackage              # Unser Hauptpaket mit der SQP-Implementierung
using Benchmarking           # Lokales Benchmarking-Modul
using Plots                  # Für die Erstellung von Diagrammen
using Printf                 # Für formatierte Ausgaben
using Statistics             # Für statistische Funktionen (Mittelwert, Median)

# Versuche Vergleichslöser zu laden
IPOPT_AVAILABLE = false
MADNLP_AVAILABLE = false
OPTIMIZATION_PROBLEMS_AVAILABLE = false

try
    using NLPModelsIpopt
    global IPOPT_AVAILABLE = true
    println("✓ Ipopt verfügbar für Vergleich")
catch e
    global IPOPT_AVAILABLE = false
    println("⚠ Ipopt nicht verfügbar: $e")
end

try
    using MadNLP
    global MADNLP_AVAILABLE = true
    println("✓ MadNLP verfügbar für Vergleich") 
catch e
    global MADNLP_AVAILABLE = false
    println("⚠ MadNLP nicht verfügbar: $e")
end

try
    using OptimizationProblems
    global OPTIMIZATION_PROBLEMS_AVAILABLE = true
    println("✓ OptimizationProblems.jl verfügbar")
catch e
    global OPTIMIZATION_PROBLEMS_AVAILABLE = false
    println("⚠ OptimizationProblems.jl nicht verfügbar: $e")
end

# Ausgabe des Programm-Headers
println("\n" * "="^60)
println("Finaler Löservergleich - Aufgabe 2.5")
println("SQP-Optimal vs. Ipopt vs. MadNLP")
println("="^60)

"""
Hilfsfunktion zur Problemerzeugung
"""
function get_problem(problem_name, use_test_problems)
    if use_test_problems
        return eval(Symbol("create_", problem_name))()
    else
        return getfield(OptimizationProblems.ADNLPProblems, problem_name)()
    end
end

"""
Filtert OptimizationProblems.jl nach geeigneten Kriterien für den finalen Vergleich
"""
function filter_optimization_problems(min_vars, max_vars, has_constraints=true)
    if !OPTIMIZATION_PROBLEMS_AVAILABLE
        return Symbol[]
    end
    
    try
        meta = OptimizationProblems.meta
        
        # Filtere nach Problemgröße und Constraints
        if has_constraints
            filtered = meta[(min_vars .<= meta.nvar .<= max_vars) .& (meta.ncon .> 0), [:name]]
        else
            filtered = meta[(min_vars .<= meta.nvar .<= max_vars), [:name]]
        end
        
        return Symbol.(filtered.name)
    catch e
        println("Fehler beim Filtern der OptimizationProblems: $e")
        return Symbol[]
    end
end

"""
Löst ein Problem mit Ipopt
"""
function solve_with_ipopt(nlp, max_time, tol)
    if !IPOPT_AVAILABLE
        return (Inf, :unavailable, 0)
    end
    
    try
        # Konfiguriere Ipopt mit fairen Einstellungen
        stats = NLPModelsIpopt.ipopt(nlp, 
            print_level=0,           # Keine Ausgabe
            max_cpu_time=max_time,   # Zeitlimit
            tol=tol,                 # Optimierungstoleranz
            constr_viol_tol=tol,     # Constraint-Toleranz
            max_iter=1000            # Iterationslimit
        )
        
        elapsed = stats.elapsed_time
        status = stats.status == :first_order ? :solved : stats.status
        niter = stats.iter
        
        return (elapsed, status, niter)
    catch e
        return (Inf, :error, 0)
    end
end

"""
Löst ein Problem mit MadNLP
"""
function solve_with_madnlp(nlp, max_time, tol)
    if !MADNLP_AVAILABLE
        return (Inf, :unavailable, 0)
    end
    
    try
        # Konfiguriere MadNLP mit fairen Einstellungen
        solver = MadNLP.MadNLPSolver(nlp,
            print_level=MadNLP.ERROR,     # Keine Ausgabe
            max_cpu_time=max_time,        # Zeitlimit  
            tol=tol,                      # Optimierungstoleranz
            constr_viol_tol=tol,          # Constraint-Toleranz
            max_iter=1000                 # Iterationslimit
        )
        
        start_time = time()
        MadNLP.solve!(solver)
        elapsed = time() - start_time
        
        status = MadNLP.get_status(solver)
        niter = MadNLP.get_iter(solver)
        
        # Konvertiere MadNLP Status zu Standard-Format
        if status == :SOLVE_SUCCEEDED
            status = :solved
        elseif status == :SOLVED_TO_ACCEPTABLE_LEVEL
            status = :solved
        else
            status = :failed
        end
        
        return (elapsed, status, niter)
    catch e
        return (Inf, :error, 0)
    end
end

"""
Löst ein Problem mit der optimalen SQP-Konfiguration
"""
function solve_with_sqp_optimal(nlp, max_time, tol)
    try
        # Beste Konfiguration basierend auf den Ergebnissen der Aufgaben 2.1-2.4
        settings = Settings(
            # Beste Grundkonfiguration aus den vorherigen Aufgaben
            qp_solver=:osqp,                      # Bester QP-Löser (Aufgabe 2.1)
            hessian_convexification=:lm,          # Beste Konvexifizierung (Aufgabe 2.2)
            use_globalization=true,               # Globalisierung aktiviert (Aufgabe 2.3)
            use_soc=true,                         # Second-Order Corrections (Aufgabe 2.3)
            
            # Optimale Filter-Parameter (Aufgabe 2.4)
            γh=1e-5,                              # Standard Filter-Parameter
            γf=1e-5,
            sh=1.1,
            sf=2.3,
            δ=1.0,
            γα=0.05,
            
            # Faire Vergleichsparameter
            tol=tol,                              # Gleiche Toleranz wie Konkurrenz
            max_iter=1000,                        # Gleiches Iterationslimit
            verbose=false                         # Keine Ausgabe
        )
        
        start_time = time()
        stats = sqp_method(nlp, settings)
        elapsed = time() - start_time
        
        # Prüfe Zeitlimit
        if elapsed > max_time
            return (Inf, :time_limit, stats.niter)
        end
        
        # Konvertiere SQP Status
        status = stats.sqp_status == kkt_point ? :solved : :failed
        
        return (elapsed, status, stats.niter)
    catch e
        return (Inf, :error, 0)
    end
end

"""
Hauptfunktion für den finalen Löservergleich
"""
function run_final_solver_comparison()
    # Faire Vergleichsparameter
    MAX_TIME = 3600.0    # 1 Stunde Zeitlimit pro Problem
    TOLERANCE = 1e-6     # Gemeinsame Optimierungstoleranz
    
    # Definition der zu vergleichenden Löser
    solvers = [
        ("SQP_Optimal", solve_with_sqp_optimal),
        ("Ipopt", solve_with_ipopt),
        ("MadNLP", solve_with_madnlp)
    ]
    
    # Filter verfügbare Löser
    available_solvers = []
    for (name, solver_func) in solvers
        if name == "SQP_Optimal" || 
           (name == "Ipopt" && IPOPT_AVAILABLE) || 
           (name == "MadNLP" && MADNLP_AVAILABLE)
            push!(available_solvers, (name, solver_func))
        end
    end
    
    if length(available_solvers) < 2
        println("❌ Nicht genügend Löser verfügbar für Vergleich!")
        return
    end
    
    println("Verfügbare Löser: $(join([s[1] for s in available_solvers], ", "))")
    
    # Definition der Problemsets
    problem_sets = [
        ("TestProblems", true, [:P1, :P2, :P3, :P4, :P5, :P6, :P7, :P8]),
        ("Large_OptimizationProblems", false, filter_optimization_problems(250, 1000, true))
    ]
    
    # Hauptschleife über Problemsets
    for (set_name, use_test_problems, test_problems) in problem_sets
        if isempty(test_problems) && !use_test_problems
            println("⚠ Keine geeigneten OptimizationProblems gefunden (≥250 Variablen)")
            continue
        end
        
        println("\n" * "="^60)
        println("Teste auf $set_name ($(length(test_problems)) Probleme)")
        println("="^60)
        
        # Initialisierung der Ergebnismatrizen
        n_problems = length(test_problems)
        n_solvers = length(available_solvers)
        
        times = Matrix{Float64}(undef, n_problems, n_solvers)
        statuses = Matrix{Symbol}(undef, n_problems, n_solvers)
        iterations = Matrix{Int}(undef, n_problems, n_solvers)
        
        # Benchmark-Hauptschleife
        for (i, problem_name) in enumerate(test_problems)
            print("Problem $problem_name: ")
            
            try
                nlp = get_problem(problem_name, use_test_problems)
                
                for (j, (solver_name, solver_func)) in enumerate(available_solvers)
                    elapsed, status, niter = solver_func(nlp, MAX_TIME, TOLERANCE)
                    
                    times[i, j] = elapsed
                    statuses[i, j] = status
                    iterations[i, j] = niter
                    
                    if status == :solved
                        print("$(solver_name): $(round(elapsed, digits=3))s ")
                    else
                        print("$(solver_name): $(status) ")
                    end
                end
                println()
                
            catch e
                println("FEHLER beim Problem $problem_name: $e")
                times[i, :] .= Inf
                statuses[i, :] .= :error
                iterations[i, :] .= 0
            end
        end
        
        # Erstelle Performance-Profil
        solver_names = [s[1] for s in available_solvers]
        plt = performance_profile(times, solver_names,
                                title="Finaler Löservergleich - $set_name",
                                logscale=true)
        
        # Speichere Ergebnisse
        results_dir = joinpath(@__DIR__, "..", "results")
        if !isdir(results_dir)
            mkpath(results_dir)
        end
        
        filename = joinpath(results_dir, "final_solver_comparison_$(lowercase(set_name)).pdf")
        savefig(plt, filename)
        println("\n📊 Performance-Profil gespeichert: $filename")
        
        # Detaillierte Statistiken
        println("\n" * "="^60)
        println("FINALE ERGEBNISSE - $set_name")
        println("="^60)
        
        for (j, solver_name) in enumerate(solver_names)
            solved = sum(statuses[:, j] .== :solved)
            total = n_problems
            success_rate = round(100 * solved / total, digits=1)
            
            if solved > 0
                successful_times = times[statuses[:, j] .== :solved, j]
                avg_time = round(mean(successful_times), digits=4)
                median_time = round(median(successful_times), digits=4)
                total_time = round(sum(successful_times), digits=2)
                
                successful_iters = iterations[statuses[:, j] .== :solved, j]
                avg_iters = round(mean(successful_iters), digits=1)
                
                println("🏆 $solver_name:")
                println("   Erfolgsrate: $solved/$total ($success_rate%)")
                println("   Durchschnittszeit: $(avg_time)s")
                println("   Medianzeit: $(median_time)s") 
                println("   Gesamtzeit: $(total_time)s")
                println("   Ø Iterationen: $(avg_iters)")
            else
                println("❌ $solver_name:")
                println("   Erfolgsrate: $solved/$total ($success_rate%)")
                println("   Keine erfolgreichen Läufe")
            end
            println()
        end
        
        # Relative Performance-Bewertung
        if length(solver_names) >= 2
            sqp_idx = findfirst(x -> contains(x, "SQP"), solver_names)
            if sqp_idx !== nothing
                sqp_success = sum(statuses[:, sqp_idx] .== :solved)
                sqp_rate = round(100 * sqp_success / n_problems, digits=1)
                
                println("🎯 SQP-BEWERTUNG:")
                if sqp_rate >= 70
                    println("   🌟 AUSGEZEICHNET! ($sqp_rate% Erfolgsrate)")
                    println("   Die SQP-Implementierung zeigt professionelle Qualität!")
                elseif sqp_rate >= 50
                    println("   ✅ GUT! ($sqp_rate% Erfolgsrate)")
                    println("   Solide Implementierung mit guter Robustheit!")
                elseif sqp_rate >= 30
                    println("   ⚠ BEFRIEDIGEND ($sqp_rate% Erfolgsrate)")
                    println("   Funktionsfähig, aber Verbesserungspotential vorhanden.")
                else
                    println("   ❌ VERBESSERUNGSBEDARF ($sqp_rate% Erfolgsrate)")
                    println("   Weitere Optimierungen empfohlen.")
                end
            end
        end
    end
    
    # Gesamtfazit
    println("\n" * "="^60)
    println("FAZIT DES FINALEN LÖSERVERGLEICHS")
    println("="^60)
    println("✅ Vergleich mit etablierten professionellen NLP-Lösern durchgeführt")
    println("📊 Performance-Profile zeigen relative Stärken und Schwächen")
    println("🎯 SQP-Implementierung wurde gegen jahrelang entwickelte Konkurrenz getestet")
    println("📈 Ergebnisse dokumentieren aktuellen Entwicklungsstand")
    println()
    println("💡 HINWEIS:")
    println("Ipopt und MadNLP wurden über viele Jahre von Expertenteams entwickelt.")
    println("Eine Erfolgsrate von >70% für die SQP-Implementierung wäre bereits")
    println("ein außergewöhnlicher Erfolg für ein Studienprojekt!")
    println("="^60)
end

# Hauptprogramm ausführen
println("Starte finalen Löservergleich...")
println("Lade Vergleichslöser...")

run_final_solver_comparison()

println("\n🏁 Finaler Löservergleich abgeschlossen!")
println("Alle Ergebnisse wurden im results/ Ordner gespeichert.")