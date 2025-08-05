#!/usr/bin/env julia

"""
Minimales Beispiel für SQPPackage.jl

Diese Datei demonstriert die grundlegende Verwendung des SQP-Solver-Pakets.
"""

# Aktuelles Verzeichnis zum Pfad hinzufügen und Paket laden
push!(LOAD_PATH, ".")
using SQPPackage
using ADNLPModels

println("="^60)
println("SQPPackage.jl - Minimales Beispiel")
println("="^60)

# Beispiel 1: Einfaches quadratisches Problem (P1)
println("\n--- Beispiel 1: Einfaches quadratisches Problem ---")
println("Problem: min x₁² + 2x₂²")

# Problem definieren
function f1(x)
    return x[1]^2 + 2*x[2]^2
end

x0 = [1.0, 1.0]
nlp1 = ADNLPModel(f1, x0)

# Mit Standardeinstellungen lösen
settings1 = Settings(verbose=true, max_iter=50, tol=1e-6)
stats1 = sqp_method(nlp1, settings1)

println("Lösung: x = ", round.(stats1.x, digits=6))
println("Zielfunktionswert: f(x) = ", round(stats1.obj_val, digits=6))
println("Status: ", stats1.sqp_status)

# Beispiel 2: Optimierungsproblem mit Nebenbedingungen (P2)
println("\n--- Beispiel 2: Optimierungsproblem mit Nebenbedingungen ---")
println("Problem: min x₁² + 2x₂²")
println("Nebenbedingungen: x₁ + 2x₂² = 10")
println("                   2x₁ + x₂ = 9")

# Problem definieren
function f2(x)
    return x[1]^2 + 2*x[2]^2
end

function c2(x)
    return [x[1] + 2*x[2]^2 - 10.0, 2*x[1] + x[2] - 9.0]
end

x0 = [1.2, 5.4]
nlp2 = ADNLPModel(f2, x0; c=c2, lcon=[0.0, 0.0], ucon=[0.0, 0.0])

# Mit OSQP-Solver lösen
settings2 = Settings(
    verbose=true,
    max_iter=100,
    tol=1e-6,
    qp_solver=:osqp,
    use_globalization=true
)
stats2 = sqp_method(nlp2, settings2)

println("Lösung: x = ", round.(stats2.x, digits=6))
println("Zielfunktionswert: f(x) = ", round(stats2.obj_val, digits=6))
println("Status: ", stats2.sqp_status)

# Nebenbedingungen prüfen
c_val = c2(stats2.x)
println("Nebenbedingungsverletzungen: ", round.(c_val, digits=8))

# Beispiel 3: Verwendung eines Testproblems aus dem Paket
println("\n--- Beispiel 3: Verwendung eines Testproblems aus dem Paket ---")
println("Löse Testproblem P4...")

# Testproblem P4 erstellen
nlp3 = create_P4()
settings3 = Settings(
    verbose=false,  # Weniger Ausgabe für übersichtlichere Darstellung
    max_iter=100,
    tol=1e-6,
    qp_solver=:osqp,
    use_globalization=true,
    hessian_convexification=:lm
)

stats3 = sqp_method(nlp3, settings3)

println("Lösung: x = ", round.(stats3.x, digits=6))
println("Zielfunktionswert: f(x) = ", round(stats3.obj_val, digits=6))
println("Status: ", stats3.sqp_status)
println("Iterationen: ", length(stats3.iteration_data))
println("Gesamtzeit: ", round(stats3.total_time, digits=3), " Sekunden")

# Beispiel 4: Vergleich verschiedener QP-Solver
println("\n--- Beispiel 4: Vergleich verschiedener QP-Solver ---")
println("Dasselbe Problem mit unterschiedlichen QP-Solvern lösen...")

qp_solvers = [:osqp, :clarabel]
nlp4 = create_P2()

for solver in qp_solvers
    try
        settings = Settings(
            verbose=false,
            max_iter=100,
            tol=1e-6,
            qp_solver=solver,
            use_globalization=true
        )
        
        stats = sqp_method(nlp4, settings)
        
        println("QP-Solver: ", solver)
        println("  Status: ", stats.sqp_status)
        println("  Lösung: ", round.(stats.x, digits=6))
        println("  Iterationen: ", length(stats.iteration_data))
        println("  Zeit: ", round(stats.total_time, digits=3), " s")
        println()
    catch e
        println("QP-Solver $solver fehlgeschlagen: ", e)
    end
end

println("="^60)
println("Minimales Beispiel abgeschlossen!")
println("="^60)
