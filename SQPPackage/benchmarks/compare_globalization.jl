#!/usr/bin/env julia

"""
Aufgabe 2.3: Globalisierungsstrategien-Vergleich

Dieses Benchmark-Skript untersucht die Auswirkungen verschiedener Globalisierungsstrategien
auf die Leistung des SQP-Lösers. Getestet werden:

Globalisierungsoptionen:
- Keine Globalisierung (lokales Newton-Verfahren)
- Nur Liniensuche (ohne Second-Order Corrections)
- Liniensuche mit Second-Order Corrections (SOC)
- Nur Second-Order Corrections (ohne Liniensuche)

Zweck:
- Analyse des Einflusses von Globalisierungsstrategien auf Konvergenz
- Vergleich der Robustheit verschiedener Ansätze
- Identifikation der optimalen Globalisierungskonfiguration
- Performance-Profile zur Visualisierung der Strategien
- Verwendung der besten QP-Löser und Konvexifizierungsstrategien

Theoretischer Hintergrund:
- Liniensuche sorgt für Abstieg in der Merit-Funktion
- Second-Order Corrections verbessern die lokale Konvergenzrate
- Filter-Methoden ermöglichen flexible Akzeptanzkriterien
- Kombination beider Techniken kann optimale Robustheit bieten
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
using OptimizationProblems   # Externe Sammlung von Optimierungsproblemen

# Ausgabe des Programm-Headers
println("="^60)
println("Globalization Strategy Comparison Benchmark - Aufgabe 2.3")
println("Analyse verschiedener Globalisierungsstrategien")
println("="^60)

"""
Hauptfunktion für den Globalisierungsstrategien-Vergleich

Diese Funktion testet systematisch verschiedene Kombinationen von:
1. Liniensuche (ein/aus)
2. Second-Order Corrections (ein/aus)
3. Filter-basierte Akzeptanzkriterien

Dabei werden die besten QP-Löser und Konvexifizierungsstrategien aus den
vorherigen Aufgaben verwendet, um einen fairen Vergleich zu gewährleisten.
"""
function run_globalization_comparison()
    # Definition der beiden Testsets
    # - TestProblems: Unsere eigenen definierten Probleme P1-P8
    # - OptimizationProblems: Externe Sammlung aus OptimizationProblems.jl
    problem_sets = [
        ("TestProblems", true),           # (Name, verwende_eigene_testprobleme)
        ("OptimizationProblems", false)   # Externe Probleme
    ]

    # Definition der zu vergleichenden Globalisierungsstrategien
    # Format: (Name, use_globalization, use_soc)
    # use_globalization aktiviert Filter-basierte Liniensuche
    # use_soc aktiviert Second-Order Corrections
    strategies = [
        ("Keine_Globalisierung", false, false),    # Pures Newton-Verfahren (riskant aber schnell)
        ("Nur_Liniensuche", true, false),          # Standard Globalisierung ohne SOC
        ("Liniensuche_mit_SOC", true, true),       # Vollständige Globalisierung (empfohlen)
        ("Nur_SOC", false, true)                   # SOC ohne Liniensuche (experimentell)
    ]

    # Iteriere über beide Problemsets
    for (set_name, use_test_problems) in problem_sets
        println("\nTeste auf $set_name...")
        println("Lade und konfiguriere Probleme für Globalisierungsanalyse...")

        # Problemauswahl basierend auf dem aktuellen Set
        if use_test_problems
            # Verwende unsere eigenen Testprobleme P1 bis P8
            # Diese sind speziell für SQP-Tests entwickelt und eignen sich gut
            # für die Analyse von Globalisierungsstrategien
            test_problems = [:P1, :P2, :P3, :P4, :P5, :P6, :P7, :P8]
        else
            # Filtere OptimizationProblems.jl für geeignete Testprobleme
            try
                meta = OptimizationProblems.meta  # Metadaten aller verfügbaren Probleme
                
                # Auswahlkriterien für OptimizationProblems:
                # - 5 bis 30 Variablen (moderate Problemgröße für Globalisierungsanalyse)
                # - 1 bis 20 Nebenbedingungen (Probleme mit Constraints)
                # Diese Größen sind optimal für die Analyse von Globalisierungseffekten
                filtered = meta[(5 .<= meta.nvar .<= 30) .& (1 .<= meta.ncon .<= 20), [:name]]
                
                # Wähle maximal 15 Probleme für repräsentativen aber handhabaren Test
                # Fokus auf Probleme, die von Globalisierung profitieren können
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
        n_problems = length(test_problems)    # Anzahl der Testprobleme
        n_strategies = length(strategies)     # Anzahl der Globalisierungsstrategien
        
        # Matrix zur Speicherung der Laufzeiten
        # Zeilen: Probleme, Spalten: Globalisierungsstrategien
        # Werte: Laufzeit in Sekunden (Inf bei Fehlschlag)
        times = Matrix{Float64}(undef, n_problems, n_strategies)

        println("Teste $(n_problems) Probleme mit $(n_strategies) Globalisierungsstrategien...")
        println("Format: Strategie: Zeit[s] [Iterationen] oder FAIL/ERROR")
        println("Verwende optimale Konfiguration: QP-Solver=:osqp, Konvexifizierung=:lm")

        # Hauptschleife: Teste jede Globalisierungsstrategie auf jedem Problem
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

                # Teste jede Globalisierungsstrategie auf dem aktuellen Problem
                for (j, (name, use_glob, use_soc)) in enumerate(strategies)
                    try
                        # Konfiguriere Einstellungen für die spezifische Globalisierungsstrategie
                        # Verwende die besten Einstellungen aus den vorherigen Aufgaben
                        settings = Settings(
                            use_globalization=use_glob,         # Aktuelle Globalisierungsstrategie
                            use_soc=use_soc,                    # Second-Order Corrections ein/aus
                            verbose=false,                      # Keine ausführliche Ausgabe
                            max_iter=200,                       # Erhöhte Iterationszahl für gründliche Tests
                            tol=1e-8,                          # Strenge Toleranz für Genauigkeit
                            qp_solver=:osqp,                   # Bester QP-Löser aus Aufgabe 2.1
                            hessian_convexification=:lm        # Beste Konvexifizierung aus Aufgabe 2.2
                        )

                        # Zeitmessung für den Lösungsvorgang
                        start_time = time()
                        stats = sqp_method(nlp, settings)     # Führe SQP-Verfahren aus
                        elapsed = time() - start_time

                        # Bewerte das Ergebnis und speichere die Zeit
                        if stats.sqp_status == kkt_point      # Erfolgreiche Konvergenz
                            times[i, j] = elapsed
                            print("$(name): $(round(elapsed, digits=3))s [$(stats.niter) iter] ")
                        else                                   # Konvergenz fehlgeschlagen
                            times[i, j] = Inf
                            print("$(name): FAIL [$(stats.sqp_status)] ")
                        end
                    catch e
                        # Fehlerbehandlung bei strategie-spezifischen Problemen
                        times[i, j] = Inf
                        print("$(name): ERROR [$(typeof(e))] ")
                    end
                end
                println()  # Neue Zeile nach jedem Problem
            catch e
                println("FEHLER beim Erstellen des Problems")
                times[i, :] .= Inf  # Markiere alle Strategien als fehlgeschlagen für dieses Problem
            end
        end

        # Erstelle Performance-Profil für die Visualisierung
        strategy_names = [s[1] for s in strategies]
        plt = performance_profile(times, strategy_names, 
                                title="Globalisierungsstrategien Vergleich - $set_name",
                                logscale=true)  # Logarithmische Skala für bessere Darstellung

        # Stelle sicher, dass das results/ Verzeichnis existiert
        results_dir = joinpath(@__DIR__, "..", "results")
        if !isdir(results_dir)
            mkpath(results_dir)
            println("Erstelle results/ Verzeichnis...")
        end

        # Speichere das Performance-Profil als PDF
        filename = joinpath(results_dir, "globalization_comparison_$(lowercase(set_name)).pdf")
        savefig(plt, filename)
        println("Ergebnisse gespeichert in: $filename")

        # Ausgabe detaillierter Zusammenfassungsstatistiken
        println("\nZusammenfassung für $set_name:")
        println("="^60)
        for (j, (name, use_glob, use_soc)) in enumerate(strategies)
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
                
                println("  $name: $solved/$total gelöst ($success_rate%) | Ø: $(avg_time)s | Med: $(median_time)s | Bereich: [$(min_time)s, $(max_time)s]")
                println("    Globalisierung: $(use_glob ? "Ein" : "Aus"), SOC: $(use_soc ? "Ein" : "Aus")")
            else
                println("  $name: $solved/$total gelöst ($success_rate%) | Keine erfolgreichen Läufe")
                println("    Globalisierung: $(use_glob ? "Ein" : "Aus"), SOC: $(use_soc ? "Ein" : "Aus")")
            end
        end
        println("="^60)
        
        # Zusätzliche Analyse der Globalisierungsstrategien
        println("\nAnalyse der Globalisierungsstrategien:")
        println("- Keine_Globalisierung: Schnell aber riskant, nur für gut konditionierte Probleme")
        println("- Nur_Liniensuche: Standard-Globalisierung, guter Kompromiss aus Robustheit und Geschwindigkeit")
        println("- Liniensuche_mit_SOC: Beste Robustheit, besonders für schwierige Probleme empfohlen")
        println("- Nur_SOC: Experimentell, lokale Verbesserungen ohne globale Garantien")
    end
end

# Hauptprogramm ausführen
println("Starte Globalisierungsstrategien-Vergleich...")
run_globalization_comparison()

# Abschlussmeldung
println("\n" * "="^60)
println("Globalisierungsstrategien-Vergleich abgeschlossen!")
println("Die Ergebnisse wurden als PDF-Dateien im results/ Ordner gespeichert.")
println("Performance-Profile zeigen die relative Effizienz der verschiedenen Globalisierungsstrategien.")
println("Empfehlung: Verwenden Sie 'Liniensuche_mit_SOC' für maximale Robustheit.")
println("="^60)