#!/usr/bin/env julia

"""
Aufgabe 2.2: Analyse der Hessian-Konvexifizierung

Dieses Benchmark-Skript untersucht verschiedene Optionen zur Konvexifizierung 
der Hesse-Matrix, um die optimale Regularisierungsstrategie für den SQP-Löser 
zu bestimmen.

Zweck:
- Vergleich aller implementierten Konvexifizierungstechniken (:none, :lm, :project, :mirror, :gershgorin)
- Analyse des Einflusses auf Konvergenzverhalten und Rechenleistung
- Test auf eigenen Testproblemen und OptimizationProblems.jl
- Erstellung von Performance-Profilen zur Visualisierung der Strategien
- Speicherung der Ergebnisse als PDF-Dateien im results/ Ordner

Konvexifizierungsstrategien:
- :none - Keine Konvexifizierung (Hessian unverändert)
- :lm - Levenberg-Marquardt (Diagonaladdition bei negativen Eigenwerten)
- :project - Projektion (negative Eigenwerte auf Epsilon projiziert)
- :mirror - Spiegelung (Betrag der Eigenwerte, mindestens Epsilon)
- :gershgorin - Gershgorin-Kreise (Diagonalanpassung basierend auf Gershgorin-Abschätzung)

Methodik:
- Jede Strategie wird mit identischen Einstellungen getestet
- Verwendung eines konsistenten QP-Lösers (OSQP) für faire Vergleiche
- Zeitmessung und Erfolgsratenanalyse
- Performance-Profile zeigen relative Stärken der Strategien
"""

# Füge das übergeordnete Verzeichnis zum Ladepfad hinzu, um SQPPackage zu finden
push!(LOAD_PATH, joinpath(@__DIR__, ".."))

# Importiere alle benötigten Pakete
using SQPPackage              # Unser Hauptpaket mit der SQP-Implementierung
using SQPPackage.Benchmarking # Benchmarking-Funktionen für Performance-Profile
using Plots                  # Für die Erstellung von Diagrammen
using Printf                 # Für formatierte Ausgaben
using Statistics             # Für statistische Funktionen (Mittelwert, Median)
using OptimizationProblems   # Externe Sammlung von Optimierungsproblemen

# Ausgabe des Programm-Headers
println("="^60)
println("Hessian Convexification Comparison Benchmark - Aufgabe 2.2")
println("Analyse verschiedener Hessian-Konvexifizierungsstrategien")
println("="^60)

"""
Hauptfunktion für den Hessian-Konvexifizierungsvergleich

Diese Funktion orchestriert den gesamten Benchmark-Prozess:
1. Definition der zu testenden Problemsets
2. Konfiguration der Konvexifizierungsstrategien
3. Durchführung der Tests mit konsistentem QP-Löser
4. Erstellung der Performance-Profile
5. Speicherung der Ergebnisse und Analyse

Die Funktion testet systematisch alle verfügbaren Konvexifizierungsmethoden
um zu bestimmen, welche Strategie für verschiedene Problemtypen optimal ist.
"""
function run_hessian_convexification_comparison()
    # Definition der beiden Testsets
    # - TestProblems: Unsere eigenen definierten Probleme P1-P8
    # - OptimizationProblems: Externe Sammlung aus OptimizationProblems.jl
    problem_sets = [
        ("TestProblems", true),           # (Name, verwende_eigene_testprobleme)
        ("OptimizationProblems", false)   # Externe Probleme
    ]

    # Liste aller zu vergleichenden Hessian-Konvexifizierungsstrategien
    # Diese entsprechen allen in ConvexifyModule implementierten Methoden
    convex_strategies = [:none, :lm, :project, :mirror, :gershgorin]

    # Iteriere über beide Problemsets
    for (set_name, use_test_problems) in problem_sets
        println("\nTeste auf $set_name...")
        println("Lade und konfiguriere Probleme für Konvexifizierungsanalyse...")

        # Problemauswahl basierend auf dem aktuellen Set
        if use_test_problems
            # Verwende unsere eigenen Testprobleme P1 bis P8
            # Diese sind speziell für SQP-Tests entwickelt und eignen sich gut
            # für die Analyse von Hessian-Konvexifizierungsstrategien
            test_problems = [:P1, :P2, :P3, :P4, :P5, :P6, :P7, :P8]
        else
            # Filtere OptimizationProblems.jl für geeignete Testprobleme
            try
                meta = OptimizationProblems.meta  # Metadaten aller verfügbaren Probleme
                
                # Auswahlkriterien für OptimizationProblems:
                # - 5 bis 30 Variablen (moderate Problemgröße für Konvexifizierungsanalyse)
                # - 1 bis 20 Nebenbedingungen (Probleme mit Constraints)
                # Diese Größen sind optimal für die Analyse von Hessian-Eigenschaften
                filtered = meta[(5 .<= meta.nvar .<= 30) .& (1 .<= meta.ncon .<= 20), [:name]]
                
                # Wähle maximal 15 Probleme für repräsentativen aber handhabaren Test
                # Fokus auf Probleme, die von Konvexifizierung profitieren können
                selected_problems = filtered.name[1:min(15, length(filtered.name))]
                test_problems = Symbol.(selected_problems)
                println("Ausgewählte $(length(test_problems)) OptimizationProblems: $(join(test_problems, ", "))")
            catch e
                println("OptimizationProblems nicht verfügbar oder Fehler aufgetreten: $e")
                println("Überspringe OptimizationProblems Testset...")
                continue  # Gehe zum nächsten Problemset
            end
        end

        # Initialisierung der Datenstrukturen für Zeitmessungen
        n_problems = length(test_problems)      # Anzahl der Testprobleme
        n_strategies = length(convex_strategies) # Anzahl der Konvexifizierungsstrategien
        
        # Matrix zur Speicherung der Laufzeiten
        # Zeilen: Probleme, Spalten: Konvexifizierungsstrategien
        # Werte: Laufzeit in Sekunden (Inf bei Fehlschlag)
        times = Matrix{Float64}(undef, n_problems, n_strategies)

        println("Teste $(n_problems) Probleme mit $(n_strategies) Konvexifizierungsstrategien...")
        println("Format: Strategie: Zeit[s] [Iterationen] oder FAIL/ERROR")

        # Hauptschleife: Teste jede Konvexifizierungsstrategie auf jedem Problem
        for (i, problem_name) in enumerate(test_problems)
            print("Problem $problem_name: ")

            # Erstelle das aktuelle Optimierungsproblem
            try
                if use_test_problems
                    # Dynamisch die entsprechende Erstellungsfunktion aufrufen
                    # z.B. create_P1() für Problem P1
                    nlp = eval(Symbol("create_", problem_name))()
                else
                    # Hole Problem aus OptimizationProblems.jl
                    nlp = getfield(OptimizationProblems.ADNLPProblems, problem_name)()
                end

                # Teste jede Konvexifizierungsstrategie auf dem aktuellen Problem
                for (j, strategy) in enumerate(convex_strategies)
                    try
                        # Konfiguriere Einstellungen für die spezifische Konvexifizierungsstrategie
                        settings = Settings(
                            hessian_convexification=strategy,    # Aktuelle Konvexifizierungsstrategie
                            verbose=false,                       # Keine ausführliche Ausgabe
                            max_iter=200,                        # Erhöhte Iterationszahl für gründliche Tests
                            tol=1e-8,                           # Strenge Toleranz für Genauigkeit
                            qp_solver=:osqp,                    # Konsistenter QP-Löser für faire Vergleiche
                            use_globalization=true              # Verwende Globalisierungsstrategien
                        )

                        # Zeitmessung für den Lösungsvorgang
                        start_time = time()
                        stats = sqp_method(nlp, settings)      # Führe SQP-Verfahren aus
                        elapsed = time() - start_time

                        # Bewerte das Ergebnis und speichere die Zeit
                        if stats.sqp_status == kkt_point       # Erfolgreiche Konvergenz
                            times[i, j] = elapsed
                            print("$(strategy): $(round(elapsed, digits=3))s [$(stats.niter) iter] ")
                        else                                    # Konvergenz fehlgeschlagen
                            times[i, j] = Inf
                            print("$(strategy): FAIL [$(stats.sqp_status)] ")
                        end
                    catch e
                        # Fehlerbehandlung bei strategie-spezifischen Problemen
                        times[i, j] = Inf
                        print("$(strategy): ERROR [$(typeof(e))] ")
                    end
                end
                println()  # Neue Zeile nach jedem Problem
            catch e
                println("FEHLER beim Erstellen des Problems")
                times[i, :] .= Inf  # Markiere alle Strategien als fehlgeschlagen für dieses Problem
            end
        end

        # Erstelle Performance-Profil für die Visualisierung
        strategy_names = string.(convex_strategies)
        plt = performance_profile(times, strategy_names, 
                                title="Hessian-Konvexifizierung Vergleich - $set_name",
                                logscale=true)  # Logarithmische Skala für bessere Darstellung

        # Stelle sicher, dass das results/ Verzeichnis existiert
        results_dir = joinpath(@__DIR__, "..", "results")
        if !isdir(results_dir)
            mkpath(results_dir)
            println("Erstelle results/ Verzeichnis...")
        end

        # Speichere das Performance-Profil als PDF
        filename = joinpath(results_dir, "hessian_convexification_comparison_$(lowercase(set_name)).pdf")
        savefig(plt, filename)
        println("Ergebnisse gespeichert in: $filename")

        # Ausgabe detaillierter Zusammenfassungsstatistiken
        println("\nZusammenfassung für $set_name:")
        println("="^60)
        for (j, strategy) in enumerate(convex_strategies)
            # Berechne Erfolgsstatistiken
            solved = sum(isfinite.(times[:, j]))           # Anzahl erfolgreich gelöster Probleme
            total = size(times, 1)                         # Gesamtanzahl der Probleme
            success_rate = round(100 * solved / total, digits=1)  # Erfolgsrate in Prozent
            
            if solved > 0
                # Berechne Zeitstatistiken nur für erfolgreiche Läufe
                finite_times = times[isfinite.(times[:, j]), j]
                avg_time = round(mean(finite_times), digits=4)      # Durchschnittszeit
                median_time = round(median(finite_times), digits=4) # Medianzeit
                min_time = round(minimum(finite_times), digits=4)   # Schnellste Zeit
                max_time = round(maximum(finite_times), digits=4)   # Langsamste Zeit
                
                println("  $strategy: $solved/$total gelöst ($success_rate%) | Ø: $(avg_time)s | Med: $(median_time)s | Bereich: [$(min_time)s, $(max_time)s]")
            else
                println("  $strategy: $solved/$total gelöst ($success_rate%) | Keine erfolgreichen Läufe")
            end
        end
        println("="^60)
        
        # Zusätzliche Analyse der Konvexifizierungsstrategien
        println("\nAnalyse der Konvexifizierungsstrategien:")
        println("- :none zeigt die Baseline ohne Regularisierung")
        println("- :lm (Levenberg-Marquardt) ist oft robust und effizient")
        println("- :project kann bei schlecht konditionierten Problemen helfen")
        println("- :mirror bewahrt die Skalierung der ursprünglichen Hessian")
        println("- :gershgorin bietet eine günstige Approximation")
    end
end

# Hauptprogramm ausführen
println("Starte Hessian-Konvexifizierungsvergleich...")
run_hessian_convexification_comparison()

# Abschlussmeldung
println("\n" * "="^60)
println("Hessian-Konvexifizierungsvergleich abgeschlossen!")
println("Die Ergebnisse wurden als PDF-Dateien im results/ Ordner gespeichert.")
println("Performance-Profile zeigen die relative Effizienz der verschiedenen Konvexifizierungsstrategien.")
println("Verwenden Sie diese Ergebnisse, um die optimale Regularisierungsstrategie für Ihren Löser zu wählen.")
println("="^60)