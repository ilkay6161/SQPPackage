"""
SettingsModule.jl - Konfigurationsmanagement für den SQP-Solver

Dieses Modul enthält alle konfigurierbaren Parameter des SQP-Solvers.
Die Einstellungen sind in logische Gruppen unterteilt und mit ausführlichen
Erklärungen versehen, um eine benutzerfreundliche Konfiguration zu ermöglichen.

Struktur:
- Allgemeine SQP-Parameter
- Hessian-Konvexifizierungsparameter  
- Globalisierungsparameter
- Filter-Parameter
- QP-Solver-Konfiguration
- Benchmarking-Einstellungen
"""
module SettingsModule

# Importiere das Parameters-Paket für elegante Strukturdefinitionen
using Parameters

# Exportiere die Hauptkonfigurationsstruktur
export Settings

"""
Settings - Hauptkonfigurationsstruktur für den SQP-Solver

Diese Struktur enthält alle konfigurierbaren Parameter des SQP-Algorithmus.
Alle Parameter haben sinnvolle Standardwerte, die für die meisten Anwendungen
geeignet sind, können aber je nach Problemstellung angepasst werden.

Verwendung:
    settings = Settings()  # Standardeinstellungen
    settings = Settings(max_iter=500, tol=1e-6)  # Angepasste Einstellungen
"""
@with_kw mutable struct Settings
    
    #= ============================================================================
       ALLGEMEINE SQP-PARAMETER
       ============================================================================ =#
    
    # Algorithmus-Kontrolle
    max_iter::Int = 200                    # Maximale Anzahl SQP-Iterationen
    tol::Float64 = 1e-8                   # KKT-Toleranz für Konvergenztest
    verbose::Bool = false                 # Detaillierte Ausgabe aktivieren
    
    # Numerische Stabilität
    epsilon::Float64 = 1e-8               # Kleinste positive Zahl für numerische Stabilität
    
    #= ============================================================================
       HESSIAN-KONVEXIFIZIERUNGSPARAMETER
       ============================================================================ =#
    
    # Konvexifizierungsstrategie auswählen
    hessian_convexification::Symbol = :lm  # Verfügbare Optionen:
                                          # :none      - Keine Konvexifizierung
                                          # :lm        - Levenberg-Marquardt (empfohlen)
                                          # :project   - Eigenwerprojektion
                                          # :mirror    - Eigenwertvspiegelung
                                          # :gershgorin - Gershgorin-Regularisierung
    
    # Regularisierungsparameter
    regularization::Float64 = 1e-8        # Basis-Regularisierung für Hessian-Matrix
    min_eigenvalue::Float64 = 1e-8        # Minimaler zulässiger Eigenwert
    use_regularization::Bool = true       # Regularisierung aktivieren/deaktivieren
    
    #= ============================================================================
       GLOBALISIERUNGSPARAMETER
       ============================================================================ =#
    
    # Globalisierungsstrategie
    use_globalization::Bool = true        # Filter-basierte Liniensuche aktivieren
    use_soc::Bool = false                # Second-Order Corrections aktivieren
    
    # Second-Order Correction Parameter
    soc_improvement_threshold::Float64 = 0.5  # Mindestverbesserung für SOC-Akzeptanz
    
    # Erweiterte Terminierungskriterien
    use_advanced_termination::Bool = false    # Erweiterte Abbruchbedingungen
    
    #= ============================================================================
       FILTER-PARAMETER
       ============================================================================ =#
    
    # Filter-Skalierungsparameter
    hmax_factor::Float64 = 1.0           # Skalierungsfaktor für maximale Constraint-Verletzung
    hmin_factor::Float64 = 1e-4          # Skalierungsfaktor für minimale Constraint-Verletzung
    hmax_scaled::Float64 = 0.0           # Berechnete maximale Constraint-Verletzung (wird zur Laufzeit gesetzt)
    hmin_scaled::Float64 = 0.0           # Berechnete minimale Constraint-Verletzung (wird zur Laufzeit gesetzt)
    
    # Filter-Akzeptanzparameter
    γh::Float64 = 1e-5                   # Constraint-Verletzungstoleranz für Filter
    γf::Float64 = 1e-5                   # Zielfunktionstoleranz für Filter
    
    # Liniensuche-Parameter
    δ::Float64 = 1.0                     # Initialer Trust-Region-Radius / Schrittgröße
    γα::Float64 = 0.05                   # Schrittreduktionsfaktor in der Liniensuche
    
    # Filter-Linien-Parameter
    sh::Float64 = 1.1                    # Neigungsparameter für Constraint-Achse im Filter
    sf::Float64 = 2.3                    # Neigungsparameter für Zielfunktions-Achse im Filter
    ηf::Float64 = 1e-4                   # Toleranz für ausreichende Zielfunktionsreduktion
    
    #= ============================================================================
       QP-SOLVER-KONFIGURATION
       ============================================================================ =#
    
    # QP-Solver-Auswahl
    qp_solver::Symbol = :osqp            # Verfügbare QP-Solver:
                                         # :osqp     - OSQP (robust, empfohlen)
                                         # :clarabel - Clarabel (modern)
                                         # :ipopt    - Ipopt (für Vergleiche)
                                         # :madnlp   - MadNLP (experimentell)
    
    # OSQP-spezifische Einstellungen
    osqp_settings::Dict = Dict(          # Konfiguration für OSQP-Solver
        "verbose" => false,              # Keine Ausgabe von OSQP
        "max_iter" => 10000,            # Maximale OSQP-Iterationen
        "eps_abs" => 1e-6,              # Absolute Toleranz für OSQP
        "eps_rel" => 1e-6,              # Relative Toleranz für OSQP
        "sigma" => 1e-6,                # Proximal-Parameter für OSQP
        "rho" => 0.1,                   # ADMM-Parameter für OSQP
        "alpha" => 1.6,                 # Relaxationsparameter für OSQP
        "scaled_termination" => true,    # Skalierte Terminierung für OSQP
        "check_termination" => 250,     # Terminierungscheck-Intervall für OSQP
        "warm_start" => true            # Warmstart für aufeinanderfolgende QP-Lösungen
    )
    
    # Clarabel-spezifische Einstellungen
    clarabel_settings::Dict = Dict(      # Konfiguration für Clarabel-Solver
        :verbose => false,               # Keine Ausgabe von Clarabel
        :max_iter => 10000,             # Maximale Clarabel-Iterationen
        :tol_feas => 1e-6,              # Feasibility-Toleranz für Clarabel
        :tol_gap_abs => 1e-6,           # Absolute Gap-Toleranz für Clarabel
        :tol_gap_rel => 1e-6,           # Relative Gap-Toleranz für Clarabel
        :presolve_enable => true,       # Presolving für Clarabel aktivieren
        :equilibrate_enable => true,    # Equilibrierung für Clarabel aktivieren
        :iterative_refinement_enable => true  # Iterative Verfeinerung für Clarabel
    )
    
    #= ============================================================================
       BENCHMARKING-EINSTELLUNGEN
       ============================================================================ =#
    
    # Performance-Messung
    benchmark::Bool = false                           # Benchmarking aktivieren/deaktivieren
    benchmark_file::String = "benchmark_results.csv" # Ausgabedatei für Benchmark-Ergebnisse
    timing_precision::Int = 6                        # Dezimalstellen für Zeitmessungen
    
    # Statistik-Sammlung
    collect_statistics::Bool = true                  # Detaillierte Statistiken sammeln
    track_residuals::Bool = false                   # KKT-Residuen in jeder Iteration verfolgen
    track_filter_points::Bool = false               # Filter-Punkte verfolgen (für Debugging)
    
end # struct Settings

#= ================================================================================
   HILFSFUNKTIONEN FÜR EINSTELLUNGEN
   ================================================================================ =#

"""
    validate_settings!(settings::Settings)

Validiert und korrigiert die Einstellungen, um Konsistenz und numerische Stabilität 
zu gewährleisten. Diese Funktion wird automatisch bei der Solver-Initialisierung aufgerufen.

Validierungen:
- Positive Werte für Toleranzen und Iterationslimits
- Konsistente Filter-Parameter
- Gültige QP-Solver-Auswahl
- Numerische Stabilität der Parameter
"""
function validate_settings!(settings::Settings)
    # Grundlegende Parametergrenzen prüfen
    settings.max_iter = max(1, settings.max_iter)           # Mindestens eine Iteration
    settings.tol = max(1e-16, settings.tol)                # Numerisch sinnvolle Toleranz
    settings.epsilon = max(1e-16, settings.epsilon)         # Numerische Stabilität
    
    # Regularisierungsparameter validieren
    settings.regularization = max(0.0, settings.regularization)
    settings.min_eigenvalue = max(0.0, settings.min_eigenvalue)
    
    # Filter-Parameter validieren
    settings.γh = max(0.0, settings.γh)                    # Nicht-negative Filter-Parameter
    settings.γf = max(0.0, settings.γf)
    settings.δ = max(settings.epsilon, settings.δ)         # Positive Schrittgröße
    settings.γα = clamp(settings.γα, 0.01, 0.5)           # Sinnvoller Reduktionsfaktor
    
    # Filter-Neigungsparameter validieren
    settings.sh = max(1.0, settings.sh)                    # Neigung mindestens 1
    settings.sf = max(1.0, settings.sf)                    # Neigung mindestens 1
    settings.ηf = clamp(settings.ηf, 1e-6, 0.1)           # Sinnvolle Zielfunktionstoleranz
    
    # QP-Solver validieren
    valid_qp_solvers = [:osqp, :clarabel, :ipopt, :madnlp]
    if !(settings.qp_solver in valid_qp_solvers)
        @warn "Ungültiger QP-Solver $(settings.qp_solver), verwende :osqp"
        settings.qp_solver = :osqp
    end
    
    # Hessian-Konvexifizierung validieren  
    valid_convex_methods = [:none, :lm, :project, :mirror, :gershgorin]
    if !(settings.hessian_convexification in valid_convex_methods)
        @warn "Ungültige Konvexifizierungsmethode $(settings.hessian_convexification), verwende :lm"
        settings.hessian_convexification = :lm
    end
    
    return settings
end

"""
    print_settings(settings::Settings)

Gibt eine übersichtliche Zusammenfassung der aktuellen Einstellungen aus.
Nützlich für Debugging und Dokumentation von Experimenten.
"""
function print_settings(settings::Settings)
    println("="^60)
    println("SQP-SOLVER EINSTELLUNGEN")
    println("="^60)
    
    println("Allgemeine Parameter:")
    println("  Maximale Iterationen: $(settings.max_iter)")
    println("  KKT-Toleranz: $(settings.tol)")
    println("  Verbosität: $(settings.verbose)")
    
    println("\nHessian-Konvexifizierung:")
    println("  Methode: $(settings.hessian_convexification)")
    println("  Regularisierung: $(settings.regularization)")
    println("  Min. Eigenwert: $(settings.min_eigenvalue)")
    
    println("\nGlobalisierung:")
    println("  Filter-Liniensuche: $(settings.use_globalization)")
    println("  Second-Order Corrections: $(settings.use_soc)")
    
    println("\nQP-Solver:")
    println("  Gewählter Solver: $(settings.qp_solver)")
    
    println("="^60)
end

end # module SettingsModule