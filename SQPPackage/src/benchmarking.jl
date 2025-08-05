# benchmarking.jl
"""
Benchmarking-Modul für die SQP-Implementierung

Dieses Modul stellt Funktionen zur Verfügung, um die Leistung verschiedener
SQP-Konfigurationen zu bewerten und zu vergleichen. Es enthält Funktionen zur:
- Berechnung von Residuen (primal und dual)
- Erstellung von Performance-Profilen für Solver-Vergleiche
- Analyse der Konvergenzqualität

Das Modul ist speziell für die Evaluation von:
- QP-Löser-Vergleichen (OSQP, Clarabel, Ipopt, MadNLP)
- Hessian-Konvexifizierungsstrategien
- Globalisierungsverfahren
- Allgemeine SQP-Parameter-Optimierung
"""
module Benchmarking

# Importiere benötigte Pakete
using LinearAlgebra    # Für Normen und lineare Algebra-Operationen
using Printf          # Für formatierte Ausgaben
using Plots          # Für die Erstellung von Performance-Profilen
using ADNLPModels    # Für die Arbeit mit automatisch differenzierten NLP-Modellen

# Importiere interne Module
using SQPPackage: SQPPackage.StatsModule, SQPPackage.ResidualsModule

# Exportiere die öffentlichen Funktionen des Moduls
export get_primal_residual, get_dual_residual, performance_profile

"""
    get_primal_residual(nlp::ADNLPModel, x::Vector{Float64}, c::Vector{Float64})

Berechnet das primale Residuum (Constraint-Verletzung) für eine gegebene Lösung.

Das primale Residuum misst, wie stark die aktuellen Variablenwerte x und 
Constraint-Werte c die Problembedingungen verletzen. Dies umfasst:
- Gleichheitsnebenbedingungen: |c_i - target_i| 
- Ungleichheitsnebenbedingungen: max(0, c_i - upper_i, lower_i - c_i)
- Variablengrenzen: max(0, x_i - upper_i, lower_i - x_i)

Parameter:
- nlp: Das NLP-Modell mit Metadaten über Grenzen und Constraints
- x: Aktuelle Variablenwerte
- c: Aktuelle Constraint-Werte

Rückgabe:
- Float64: Maximale Verletzung aller Constraints und Grenzen
"""
function get_primal_residual(nlp::ADNLPModel, x::Vector{Float64}, c::Vector{Float64})
    # Hole die Variablen- und Constraint-Grenzen aus dem NLP-Modell
    lvar, uvar = nlp.meta.lvar, nlp.meta.uvar  # Untere und obere Variablengrenzen
    lcon, ucon = nlp.meta.lcon, nlp.meta.ucon  # Untere und obere Constraint-Grenzen
    
    # Initialisiere die verschiedenen Verletzungsmaße
    h_eq = 0.0    # Maximale Verletzung von Gleichheitsnebenbedingungen
    h_ineq = 0.0  # Maximale Verletzung von Ungleichheitsnebenbedingungen
    
    # Berechne Constraint-Verletzungen
    for i in eachindex(c)
        if lcon[i] ≈ ucon[i]  # Gleichheitsnebenbedingung (untere ≈ obere Grenze)
            # Für Gleichheitsnebenbedingungen: Abstand vom Sollwert
            h_eq = max(h_eq, abs(c[i] - ucon[i]))
        else  # Ungleichheitsnebenbedingung
            # Für Ungleichheitsnebenbedingungen: Verletzung der Grenzen
            violation = max(0.0, c[i] - ucon[i], lcon[i] - c[i])
            h_ineq = max(h_ineq, violation)
        end
    end
    
    # Berechne Variablengrenzen-Verletzungen
    h_bounds = 0.0
    for i in eachindex(x)
        # Prüfe obere Grenzen (falls endlich)
        if isfinite(uvar[i]) 
            h_bounds = max(h_bounds, max(0.0, x[i] - uvar[i])) 
        end
        # Prüfe untere Grenzen (falls endlich)
        if isfinite(lvar[i]) 
            h_bounds = max(h_bounds, max(0.0, lvar[i] - x[i])) 
        end
    end
    
    # Rückgabe der maximalen Verletzung über alle Kategorien
    return max(h_eq, h_ineq, h_bounds)
end

"""
    get_dual_residual(nlp::ADNLPModel, x::Vector, y::Vector, zL::Vector, zU::Vector, g::Vector)

Berechnet das duale Residuum (Gradientenresiduum der Lagrange-Funktion).

Das duale Residuum misst die Verletzung der Stationaritätsbedingung:
∇L(x,y,z) = ∇f(x) + A(x)ᵀy + (zU - zL) = 0

wo:
- ∇f(x) der Gradient der Zielfunktion ist (g)
- A(x) die Jacobi-Matrix der Constraints ist
- y die Lagrange-Multiplikatoren für Constraints sind
- zL, zU die Multiplikatoren für untere/obere Variablengrenzen sind

Parameter:
- nlp: Das NLP-Modell
- x: Aktuelle Variablenwerte
- y: Lagrange-Multiplikatoren für Constraints
- zL: Multiplikatoren für untere Variablengrenzen
- zU: Multiplikatoren für obere Variablengrenzen  
- g: Gradient der Zielfunktion bei x

Rückgabe:
- Float64: Unendlichnorm des Lagrange-Gradienten (Stationaritätsmaß)
"""
function get_dual_residual(nlp::ADNLPModel, x::Vector, y::Vector, zL::Vector, zU::Vector, g::Vector)
    # Berechne die Jacobi-Matrix der Constraints bei x
    # Falls keine Constraints vorhanden, verwende leere Matrix
    A = nlp.meta.ncon > 0 ? jac(nlp, x) : zeros(0, length(x))
    
    # Berechne den Gradienten der Lagrange-Funktion
    # ∇L = ∇f + Aᵀy + (zU - zL)
    grad_lag = g + A' * y + (zU - zL)
    
    # Rückgabe der Unendlichnorm als Maß für die Stationarität
    return norm(grad_lag, Inf)
end

"""
    performance_profile(times, names; title="Performance Profile", logscale=false)

Erstellt ein Performance-Profil zur Visualisierung der relativen Solver-Leistung.

Performance-Profile sind ein Standard-Werkzeug in der Optimierung, um die
relative Effizienz verschiedener Algorithmen zu vergleichen. Sie zeigen für
jeden Solver den Anteil der Probleme an, die innerhalb eines bestimmten
Faktors τ der besten Zeit gelöst werden können.

Mathematik:
- Für jedes Problem j und Solver s: r_j,s = t_j,s / min_s(t_j,s)
- ρ_s(τ) = |{j : r_j,s ≤ τ}| / |J|
- Dabei ist t_j,s die Zeit von Solver s auf Problem j

Interpretation:
- ρ_s(1) = Anteil der Probleme, wo Solver s der schnellste war
- ρ_s(∞) = Anteil der Probleme, die Solver s überhaupt lösen konnte
- Höhere Kurven = bessere Performance

Parameter:
- times: Matrix [n_problems × n_solvers] mit Laufzeiten (Inf bei Fehlschlag)
- names: Array von Solver-Namen für die Legende
- title: Titel des Plots
- logscale: Ob logarithmische x-Achse verwendet werden soll

Rückgabe:
- Plots.Plot: Das erstellte Performance-Profil-Diagramm
"""
function performance_profile(times, names; title="Performance Profile", logscale=false)
    # Erstelle logarithmisch verteilte τ-Werte von 1 bis 100
    # Diese repräsentieren die Performance-Ratios (1x bis 100x der besten Zeit)
    τ = exp.(range(log(1), log(100), length=100))
    
    # Erstelle das Basis-Plot mit verbesserter Styling
    plt = Plots.plot(
        xlabel="Performance Ratio τ",                    # x-Achse: Faktor der besten Zeit
        ylabel="Fraction of Problems Solved ρ(τ)",      # y-Achse: Anteil gelöster Probleme
        title=title, 
        legend=:bottomright,                             # Legende unten rechts
        grid=true,                                       # Gitter einblenden
        gridwidth=1,                                     # Gitterlinienbreite
        gridcolor=:gray,                                 # Gitterfarbe
        gridalpha=0.3,                                   # Gittertransparenz
        size=(800, 600),                                 # Plotgröße
        dpi=300,                                         # Auflösung für PDF-Export
        fontsize=12                                      # Schriftgröße
    )
    
    # Definiere verschiedene Farben für die Solver/Strategien
    colors = [:blue, :red, :green, :orange, :purple, :brown, :pink, :gray, :cyan, :magenta]
    
    # Erstelle eine Kurve für jeden Solver/jede Strategie
    for (i, solver) in enumerate(names)
        # Identifiziere Probleme, die dieser Solver erfolgreich gelöst hat
        finite_mask = isfinite.(times[:, i])
        
        if !any(finite_mask)
            # Falls dieser Solver kein Problem lösen konnte
            Plots.plot!(plt, τ, zeros(length(τ)), 
                       label="$solver (keine Lösungen)", 
                       lw=3, 
                       linestyle=:dash,                   # Gestrichelte Linie
                       color=colors[mod(i-1, length(colors)) + 1])
            continue
        end
        
        # Für jedes Problem: finde die beste Zeit über alle Solver
        min_times = [minimum(times[j, isfinite.(times[j, :])]) for j in 1:size(times, 1) if any(isfinite.(times[j, :]))]
        
        if isempty(min_times)
            continue  # Überspringe, falls keine Solver erfolgreich waren
        end
        
        # Berechne Performance-Ratios für diesen Solver
        r = fill(Inf, size(times, 1))  # Initialisiere mit Unendlich
        for j in 1:size(times, 1)
            if finite_mask[j] && any(isfinite.(times[j, :]))
                # Berechne Ratio: Zeit dieses Solvers / beste Zeit für dieses Problem
                min_time_for_problem = minimum(times[j, isfinite.(times[j, :])])
                r[j] = times[j, i] / min_time_for_problem
            end
        end
        
        # Berechne ρ(τ): Anteil der Probleme mit Ratio ≤ τ
        ρ = [count(r .<= t) / size(times, 1) for t in τ]
        
        # Zeichne die Performance-Kurve für diesen Solver
        Plots.plot!(plt, τ, ρ, 
                   label=solver, 
                   lw=3,                                  # Linienbreite
                   color=colors[mod(i-1, length(colors)) + 1])
    end
    
    # Konfiguriere Achsenlimits und Skalierung
    Plots.ylims!(plt, 0, 1)                             # y-Achse: 0 bis 1 (0% bis 100%)
    
    if logscale
        # Logarithmische x-Achse für große Performance-Unterschiede
        Plots.plot!(plt, xscale=:log10)
        Plots.xlims!(plt, 1, 100)
    else
        # Lineare x-Achse, fokussiert auf relevanten Bereich
        Plots.xlims!(plt, 1, 20)  # Fokus auf 1x bis 20x der besten Zeit
    end
    
    # Füge Referenzlinien hinzu (50% und 80% der Probleme gelöst)
    Plots.hline!(plt, [0.5, 0.8], 
                color=:gray, 
                linestyle=:dot, 
                alpha=0.5, 
                label="")
    
    return plt
end

end  # Ende des Benchmarking-Moduls