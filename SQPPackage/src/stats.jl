"""
StatsModule.jl - Statistiken und Statusverwaltung für den SQP-Solver

Dieses Modul definiert alle Datenstrukturen für die Verfolgung des Solver-Status,
der Konvergenzstatistiken und der Performance-Metriken während der SQP-Optimierung.

Komponenten:
- SQPStatus: Aufzählung aller möglichen Solver-Zustände
- Stats: Hauptdatenstruktur für alle Solver-Statistiken
- Hilfsfunktionen für Statistik-Management und -Ausgabe
"""
module StatsModule

# Importiere Base-Enums für Statusdefinitionen
using Base.Enums

# Exportiere alle öffentlichen Schnittstellen
export SQPStatus, Stats
export kkt_point, max_iter, qp_failed, infeasible, restoration_phase, unbounded
export create_stats, update_stats!, print_stats, is_converged

#= ================================================================================
   STATUS-DEFINITIONEN
   ================================================================================ =#

"""
SQPStatus - Aufzählung aller möglichen SQP-Solver-Zustände

Diese Enumeration definiert alle möglichen Ausgangszustände des SQP-Algorithmus
und ermöglicht eine präzise Klassifikation des Solver-Verhaltens.

Status-Bedeutungen:
- kkt_point: Optimale Lösung gefunden (KKT-Bedingungen erfüllt)
- max_iter: Maximale Iterationsanzahl erreicht
- qp_failed: QP-Subproblem konnte nicht gelöst werden
- unbounded: Problem ist unbeschränkt (Zielfunktion → -∞)
- infeasible: Problem ist unzulässig (keine feasible Lösung)
- restoration_phase: Algorithmus in Wiederherstellungsphase
"""
@enum SQPStatus begin
    kkt_point           # Optimale Lösung gefunden - KKT-Bedingungen erfüllt
    max_iter           # Maximale Iterationsanzahl erreicht ohne Konvergenz
    qp_failed          # QP-Subproblem fehlgeschlagen oder nicht lösbar
    unbounded          # Problem unbeschränkt (obj → -∞)
    infeasible         # Problem unzulässig (keine feasible Lösung existiert)
    restoration_phase  # Algorithmus versucht Feasibility wiederherzustellen
end

#= ================================================================================
   STATISTIKEN-DATENSTRUKTUR
   ================================================================================ =#

"""
Stats - Hauptdatenstruktur für alle SQP-Solver-Statistiken

Diese Struktur sammelt alle relevanten Informationen über den Optimierungsprozess,
einschließlich der finalen Lösung, Konvergenzmetriken, Performance-Statistiken
und detaillierte Iterationsdaten.

Felder:
- Lösungsdaten: x, y, z (Primal-, Dual-, Slack-Variablen)
- Zielfunktionswert und Konvergenzmetriken
- Solver-Status und Iterationsinformationen  
- Performance-Metriken (Funktionsauswertungen, Laufzeit)
- Historische Daten für Konvergenzanalyse
"""
mutable struct Stats
    
    #= ============================================================================
       LÖSUNGSDATEN
       ============================================================================ =#
    
    # Primale Variablen (Lösung des Optimierungsproblems)
    x::Vector{Float64}              # Entscheidungsvariablen der optimalen Lösung
    
    # Duale Variablen (Lagrange-Multiplikatoren)
    y::Vector{Float64}              # Duale Variablen für Gleichheitsnebenbedingungen
    z::Vector{Float64}              # Duale Variablen für Ungleichheitsnebenbedingungen
    
    #= ============================================================================
       ZIELFUNKTION UND KONVERGENZMETRIKEN
       ============================================================================ =#
    
    # Zielfunktionswert an der aktuellen Lösung
    obj_val::Float64                # Wert der Zielfunktion f(x) an der Lösung
    
    # KKT-Residuen (Maß für Optimalität)
    inf_pr::Float64                 # Primal Infeasibility (||c(x)||∞)
    inf_du::Float64                 # Dual Infeasibility (||∇L(x,y,z)||∞)
    inf_comp::Float64               # Complementarity Gap (||diag(z)s||∞)
    
    #= ============================================================================
       STATUS UND ITERATIONSINFORMATIONEN
       ============================================================================ =#
    
    # Solver-Status
    qp_status::SQPStatus            # Status des letzten QP-Subproblems
    sqp_status::SQPStatus           # Gesamtstatus des SQP-Algorithmus
    qp_solve_status::Symbol         # Detaillierter QP-Solver-Status (:solved, :failed, etc.)
    
    # Iterationsinformationen
    iter::Int                       # Aktuelle SQP-Iterationsnummer
    niter::Int                      # Gesamtanzahl der SQP-Iterationen (Alias für iter)
    
    #= ============================================================================
       PERFORMANCE-METRIKEN
       ============================================================================ =#
    
    # Funktionsauswertungen (für Performance-Analyse)
    obj_evals::Int                  # Anzahl Zielfunktions-Auswertungen
    grad_evals::Int                 # Anzahl Gradienten-Berechnungen
    cons_evals::Int                 # Anzahl Constraint-Auswertungen
    jac_evals::Int                  # Anzahl Jacobian-Berechnungen
    hess_evals::Int                 # Anzahl Hessian-Berechnungen
    
    # Laufzeit-Statistiken
    total_time::Float64             # Gesamtlaufzeit des Algorithmus in Sekunden
    qp_time::Float64               # Gesamtzeit für QP-Subprobleme in Sekunden
    
    #= ============================================================================
       HISTORISCHE DATEN UND KONVERGENZANALYSE
       ============================================================================ =#
    
    # Vorherige Iteration (für Konvergenzanalyse)
    x_prev::Vector{Float64}         # Primale Variablen der vorherigen Iteration
    obj_val_prev::Float64           # Zielfunktionswert der vorherigen Iteration
    
    # Iterationshistorie für detaillierte Analyse
    iteration_data::Vector{Dict{String,Any}}  # Historie aller Iterationsdaten
    residual_history::Vector{Vector{Float64}} # Verlauf der KKT-Residuen
    
    #= ============================================================================
       KONSTRUKTOR
       ============================================================================ =#
    
    """
    Hauptkonstruktor für Stats-Struktur
    
    Erstellt eine neue Stats-Instanz mit den grundlegenden Solver-Informationen.
    Alle Performance-Metriken und historischen Daten werden auf Standardwerte initialisiert.
    """
    function Stats(x::Vector{Float64}, y::Vector{Float64}, z::Vector{Float64}, 
                   obj_val::Float64, inf_pr::Float64, inf_du::Float64, inf_comp::Float64,
                   qp_status::SQPStatus, sqp_status::SQPStatus, iter::Int)
        new(
            # Lösungsdaten
            copy(x), copy(y), copy(z),
            
            # Zielfunktion und Konvergenz
            obj_val, inf_pr, inf_du, inf_comp,
            
            # Status
            qp_status, sqp_status, :unknown,
            
            # Iterationen
            iter, iter,  # iter und niter sind identisch
            
            # Performance-Metriken (alle auf 0 initialisiert)
            0, 0, 0, 0, 0,          # Funktionsauswertungen
            0.0, 0.0,               # Laufzeiten
            
            # Historische Daten
            copy(x),                # x_prev als Kopie von x
            obj_val,                # obj_val_prev
            Vector{Dict{String,Any}}(),  # Leere Iterationshistorie
            Vector{Vector{Float64}}()    # Leere Residuen-Historie
        )
    end
    
    """
    Vereinfachter Konstruktor für grundlegende Stats-Erstellung
    """
    function Stats(n_vars::Int, n_cons::Int)
        Stats(
            zeros(n_vars),          # x
            zeros(n_cons),          # y  
            zeros(n_cons),          # z
            0.0,                    # obj_val
            Inf,                    # inf_pr
            Inf,                    # inf_du  
            Inf,                    # inf_comp
            qp_failed,              # qp_status
            max_iter,               # sqp_status
            0                       # iter
        )
    end
    
end # struct Stats

#= ================================================================================
   HILFSFUNKTIONEN FÜR STATISTIK-MANAGEMENT
   ================================================================================ =#

"""
    create_stats(n_vars::Int, n_cons::Int) -> Stats

Erstellt eine neue Stats-Instanz mit den angegebenen Problemdimensionen.
Alle Werte werden auf sichere Standardwerte initialisiert.
"""
function create_stats(n_vars::Int, n_cons::Int)
    return Stats(n_vars, n_cons)
end

"""
    update_stats!(stats::Stats, x::Vector, y::Vector, z::Vector, 
                  obj_val::Float64, residuals::Vector{Float64})

Aktualisiert die Stats-Struktur mit neuen Iterationsdaten.
Diese Funktion wird am Ende jeder SQP-Iteration aufgerufen.
"""
function update_stats!(stats::Stats, x::Vector, y::Vector, z::Vector, 
                      obj_val::Float64, residuals::Vector{Float64})
    # Speichere vorherige Werte für Konvergenzanalyse
    stats.x_prev .= stats.x
    stats.obj_val_prev = stats.obj_val
    
    # Aktualisiere aktuelle Werte
    stats.x .= x
    stats.y .= y  
    stats.z .= z
    stats.obj_val = obj_val
    
    # Aktualisiere Residuen
    if length(residuals) >= 3
        stats.inf_pr = residuals[1]
        stats.inf_du = residuals[2] 
        stats.inf_comp = residuals[3]
    end
    
    # Erhöhe Iterationszähler
    stats.iter += 1
    stats.niter = stats.iter
    
    # Füge zur Historie hinzu
    push!(stats.residual_history, copy(residuals))
    
    # Speichere detaillierte Iterationsdaten
    iter_data = Dict{String,Any}(
        "iteration" => stats.iter,
        "obj_val" => obj_val,
        "inf_pr" => stats.inf_pr,
        "inf_du" => stats.inf_du,
        "inf_comp" => stats.inf_comp,
        "timestamp" => time()
    )
    push!(stats.iteration_data, iter_data)
end

"""
    is_converged(stats::Stats, tol::Float64) -> Bool

Prüft, ob der Solver basierend auf den KKT-Bedingungen konvergiert ist.
"""
function is_converged(stats::Stats, tol::Float64)
    return (stats.inf_pr <= tol && 
            stats.inf_du <= tol && 
            stats.inf_comp <= tol)
end

"""
    print_stats(stats::Stats)

Gibt eine übersichtliche Zusammenfassung der Solver-Statistiken aus.
"""
function print_stats(stats::Stats)
    println("="^60)
    println("SQP-SOLVER STATISTIKEN")
    println("="^60)
    
    # Status-Information
    println("Status:")
    println("  SQP-Status: $(stats.sqp_status)")
    println("  QP-Status: $(stats.qp_status)")
    println("  Iterationen: $(stats.iter)")
    
    # Lösungsqualität
    println("\nLösungsqualität:")
    println("  Zielfunktionswert: $(round(stats.obj_val, digits=6))")
    println("  Primal Infeasibility: $(round(stats.inf_pr, digits=8))")
    println("  Dual Infeasibility: $(round(stats.inf_du, digits=8))")
    println("  Complementarity Gap: $(round(stats.inf_comp, digits=8))")
    
    # Performance-Metriken
    println("\nPerformance:")
    println("  Gesamtzeit: $(round(stats.total_time, digits=3))s")
    println("  QP-Zeit: $(round(stats.qp_time, digits=3))s")
    println("  Zielfunktions-Auswertungen: $(stats.obj_evals)")
    println("  Gradienten-Berechnungen: $(stats.grad_evals)")
    println("  Hessian-Berechnungen: $(stats.hess_evals)")
    
    # Konvergenzverhalten
    if length(stats.residual_history) > 1
        println("\nKonvergenzverhalten:")
        println("  Startwerte: $(round.(stats.residual_history[1], digits=6))")
        println("  Endwerte: $(round.(stats.residual_history[end], digits=6))")
    end
    
    println("="^60)
end

"""
    get_convergence_rate(stats::Stats) -> Float64

Berechnet die durchschnittliche Konvergenzrate basierend auf der Residuen-Historie.
"""
function get_convergence_rate(stats::Stats)
    if length(stats.residual_history) < 2
        return NaN
    end
    
    # Berechne die Reduktion der größten Residue
    initial_residual = maximum(stats.residual_history[1])
    final_residual = maximum(stats.residual_history[end])
    
    if initial_residual <= 0 || final_residual <= 0
        return NaN
    end
    
    # Durchschnittliche logarithmische Reduktionsrate
    n_iters = length(stats.residual_history) - 1
    return (log(initial_residual) - log(final_residual)) / n_iters
end

end # module StatsModule
