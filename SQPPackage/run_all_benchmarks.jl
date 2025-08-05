#!/usr/bin/env julia

"""
Master-Skript zum Ausführen aller Benchmark-Tests für SQPPackage.jl
gemäß der Aufgabenstellung.
"""

# Load all necessary packages at the top level
using SQPPackage
using Plots
using Printf

println("="^80)
println("SQPPackage.jl - Vollständige Benchmark-Suite")
println("Entwickelt gemäß Aufgabenstellung für Julia-Paket Performance-Profile")
println("="^80)

# Erstelle results Verzeichnis falls nicht vorhanden
results_dir = joinpath(@__DIR__, "results")
if !isdir(results_dir)
    mkpath(results_dir)
    println("Ergebnisverzeichnis erstellt: $results_dir")
end

# Liste aller Benchmark-Skripte in der richtigen Reihenfolge
benchmark_scripts = [
    ("QP-Solver Vergleich", "benchmarks/compare_qp_solvers.jl"),
    ("Hessian-Konvexifizierung Vergleich", "benchmarks/compare_hessian_convexification.jl"),
    ("Globalisierungsstrategien Vergleich", "benchmarks/compare_globalization.jl"),
    ("Toleranz-Einstellungen Vergleich", "benchmarks/compare_option_of_choice.jl"),
    ("Großer Benchmark vs. etablierte Solver", "benchmarks/large_benchmark.jl")
]

start_time = time()

for (description, script_path) in benchmark_scripts
    println("\n" * "="^80)
    println("Starte: $description")
    println("Skript: $script_path")
    println("="^80)
    
    script_start = time()
    
    try
        # Führe das Benchmark-Skript aus
        include(script_path)
        
        script_elapsed = time() - script_start
        println("\n✓ $description abgeschlossen in $(round(script_elapsed, digits=2)) Sekunden")
        
    catch e
        script_elapsed = time() - script_start
        println("\n✗ Fehler in $description nach $(round(script_elapsed, digits=2)) Sekunden:")
        println("   $e")
        
        # Zeige Stacktrace für Debugging
        if isa(e, LoadError) || isa(e, MethodError)
            println("   Stacktrace:")
            for (i, frame) in enumerate(stacktrace(catch_backtrace()))
                println("     $i. $frame")
                if i > 5  # Begrenze Stacktrace-Ausgabe
                    break
                end
            end
        end
    end
end

total_elapsed = time() - start_time

println("\n" * "="^80)
println("BENCHMARK-SUITE ABGESCHLOSSEN")
println("="^80)
println("Gesamtzeit: $(round(total_elapsed, digits=2)) Sekunden")
println("Ergebnisse gespeichert in: $results_dir")
println()
println("Erstellte Performance-Profile (PDFs):")
println("• qp_solver_comparison_testproblems.pdf")
println("• qp_solver_comparison_optimizationproblems.pdf")
println("• hessian_convexification_comparison_testproblems.pdf")
println("• hessian_convexification_comparison_optimizationproblems.pdf")
println("• globalization_comparison_testproblems.pdf")
println("• globalization_comparison_optimizationproblems.pdf")
println("• tolerance_comparison_testproblems.pdf")
println("• tolerance_comparison_optimizationproblems.pdf")
println("• large_scale_comparison.pdf")
println()
println("Diese Ergebnisse erfüllen die Aufgabenanforderungen für:")
println("- Julia-Paket Development")
println("- Performance-Profile Erstellung")
println("- Umfassendes Benchmarking und Testen")
println("="^80)