module SettingsModule
using Parameters
export Settings

@with_kw mutable struct Settings
    # Grundlegende SQP-Einstellungen
    max_iter::Int = 200          # Maximale Anzahl der Iterationen für den SQP-Algorithmus.
    tol::Float64 = 1e-8          # Toleranz für die KKT-Bedingungen zur Bestimmung der Konvergenz.
    verbose::Bool = false       # Wenn true, werden detaillierte Informationen während des Optimierungsprozesses ausgegeben.

    # Einstellungen für die Konvexifizierung
    regularization::Float64 = 1e-8  # Regularisierungsparameter, der zur Diagonalen der Hesse-Matrix hinzugefügt wird, um die Positive Definitheit zu gewährleisten.
    min_eigenvalue::Float64 = 1e-8  # Mindestzulässiger Eigenwert für die Hesse-Matrix; wenn kleiner, wird Regularisierung angewendet.
    use_regularization::Bool = true  # Ob Regularisierung verwendet werden soll, wenn die Hesse-Matrix nicht positiv definit ist.
    hessian_convexification::Symbol = :lm  # Methode zur Konvexifizierung der Hesse-Matrix: :none (keine Konvexifizierung), :lm (Levenberg-Marquardt), :project (Projektion), :mirror (Spiegelung), :gershgorin (Gershgorin-Scheibe).
    epsilon::Float64 = 1e-8          # Kleine Zahl für numerische Stabilität, z. B. in der Linien- oder Trust-Region-Suche.

    # Einstellungen für die Globalisierung
    use_globalization::Bool = true  # Ob eine Globalisierungsstrategie (Linien- oder Trust-Region-Suche) verwendet werden soll, um die Konvergenz zu gewährleisten.
    use_advanced_termination::Bool = false  # Ob erweiterte Abbruchkriterien verwendet werden sollen, z. B. basierend auf Stationaritätsmaßen.
    use_soc::Bool = false        # Ob die Second-Order Correction (SOC) verwendet werden soll, um die Konvergenz zu verbessern.
    soc_improvement_threshold::Float64 = 0.5

    # Filter-Parameter
    hmax_factor::Float64 = 1.0   # Faktor zur Skalierung der maximal zulässigen Einschränkungsverletzung (h) im Filter.
    hmin_factor::Float64 = 1e-4  # Faktor zur Skalierung der minimal zulässigen Einschränkungsverletzung (h) im Filter.
    hmax_scaled::Float64 = 0.0   # Skalierte maximale Einschränkungsverletzung, berechnet während der Initialisierung basierend auf der Problemgröße.
    hmin_scaled::Float64 = 0.0   # Skalierte minimale Einschränkungsverletzung, berechnet während der Initialisierung.
    γh::Float64 = 1e-5           # Parameter zur Steuerung des Kompromisses zwischen Zielfunktion und Einschränkungsverletzung im Filter.
    γf::Float64 = 1e-5           # Ein weiterer Parameter für den Filter, möglicherweise im Zusammenhang mit der Neigung der Filterlinien.
    δ::Float64 = 1.0             # Initialer Schritt oder Trust-Region-Radius.
    γα::Float64 = 0.05           # Reduktionsfaktor für die Schrittgröße in der Linien-Suche.
    sh::Float64 = 1.1            # Neigungsparameter für die Achse der Einschränkungsverletzung im Filter.
    sf::Float64 = 2.3            # Neigungsparameter für die Achse der Zielfunktion im Filter.
    ηf::Float64 = 1e-4           # Toleranz für ausreichende Abnahme der Zielfunktion.

    # QP-Löser-Einstellungen
    qp_solver::Symbol = :osqp     # Wahl des QP-Lösers für Subprobleme: :osqp, :clarabel, :simple.
    osqp_settings::Dict = Dict(  
        "verbose" => false,
        "max_iter" => 10000,
        "eps_abs" => 1e-6,
        "eps_rel" => 1e-6
    )
 # Einstellungen für den OSQP-Löser, z. B. Ausführlichkeit und absolute Toleranz.
    clarabel_settings::Dict = Dict(:verbose => false)  # Einstellungen für den Clarabel-Löser, z. B. Ausführlichkeit.

    # Benchmark-Einstellungen
    benchmark::Bool = false              # Wenn true, wird die Benchmarking des Optimierungsprozesses aktiviert.
    benchmark_file::String = "benchmark_results.csv"  # Datei, in der die Benchmark-Ergebnisse gespeichert werden.
       
end

end