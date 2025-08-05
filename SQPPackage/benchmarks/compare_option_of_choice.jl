#!/usr/bin/env julia

"""
Aufgabe 2.4: Algorithmische Option Ihrer Wahl - Filter-Parameter-Konfigurationen

Dieses Benchmark-Skript untersucht den Einfluss verschiedener Filter-Parameter-Konfigurationen
auf die Leistung des SQP-Lösers. Filter-Parameter sind kritisch für die Robustheit und
Effizienz des SQP-Verfahrens.

Untersuchte Filter-Parameter:
- γh (Einschränkungsverletzung-Toleranz): Bestimmt die Akzeptanz neuer Iterationspunkte
- γf (Zielfunktions-Toleranz): Kontrolliert die erforderliche Verbesserung der Zielfunktion  
- sh/sf (Neigungsparameter): Steuern die Filter-Linien für Constraint-Verletzung und Zielfunktion
- δ (Trust-Region-Radius): Anfängliche Schrittgröße für die Liniensuche

Theoretischer Hintergrund:
- Filter-Methoden ermöglichen flexible Akzeptanzkriterien ohne Penalty-Parameter
- Verschiedene Parameter-Sets können die Konvergenzgeschwindigkeit stark beeinflussen
- Aggressive Parameter: Schneller aber weniger robust
- Konservative Parameter: Langsamer aber stabiler
- Adaptive Parameter: Versuchen optimalen Kompromiss zu finden

Zweck:
- Identifikation optimaler Filter-Parameter-Konfigurationen
- Analyse des Trade-offs zwischen Geschwindigkeit und Robustheit
- Vergleich verschiedener Parameter-Philosophien (aggressiv vs. konservativ)
- Performance-Profile zur Visualisierung der Parameter-Auswirkungen
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
println("Filter Parameter Configuration Benchmark - Aufgabe 2.4")
println("Analyse verschiedener Filter-Parameter-Konfigurationen")
println("="^60)

"""
Hauptfunktion für den Filter-Parameter-Vergleich

Diese Funktion testet systematisch verschiedene Konfigurationen der Filter-Parameter:
1. Standard-Konfiguration (ausgewogen)
2. Aggressive Konfiguration (schnell aber riskant)  
3. Konservative Konfiguration (robust aber langsam)
4. Adaptive Konfiguration (experimentell)

Die Filter-Parameter kontrollieren die Akzeptanzkriterien für neue Iterationspunkte
im SQP-Verfahren und haben großen Einfluss auf Konvergenzverhalten und Robustheit.
"""
function run_filter_parameter_comparison()
    # Definition der beiden Testsets
    # - TestProblems: Unsere eigenen definierten Probleme P1-P8
    # - OptimizationProblems: Externe Sammlung aus OptimizationProblems.jl
    problem_sets = [
        ("TestProblems", true),           # (Name, verwende_eigene_testprobleme)
        ("OptimizationProblems", false)   # Externe Probleme
    ]

    # Definition verschiedener Filter-Parameter-Konfigurationen
    # Format: (Name, γh, γf, sh, sf, δ, γα)
    # γh: Constraint-Toleranz, γf: Zielfunktions-Toleranz
    # sh/sf: Neigungsparameter, δ: Trust-Region-Radius, γα: Schrittreduktion
    filter_configs = [
        ("Standard", 1e-5, 1e-5, 1.1, 2.3, 1.0, 0.05),        # Ausgewogene Standard-Parameter
        ("Aggressiv", 1e-3, 1e-3, 1.05, 1.5, 2.0, 0.1),       # Schnelle aber riskante Parameter
        ("Konservativ", 1e-6, 1e-6, 1.2, 3.0, 0.5, 0.02),     # Robuste aber langsamere Parameter
        ("Adaptive", 1e-4, 1e-4, 1.15, 2.0, 1.5, 0.075)       # Experimentelle adaptive Parameter
    ]

    # Iteriere über beide Problemsets
    for (set_name, use_test_problems) in problem_sets
        println("\nTeste auf $set_name...")
        println("Lade und konfiguriere Probleme für Filter-Parameter-Analyse...")

        # Problemauswahl basierend auf dem aktuellen Set
        if use_test_problems
            # Verwende unsere eigenen Testprobleme P1 bis P8
            # Diese sind speziell für SQP-Tests entwickelt und eignen sich gut
            # für die Analyse von Filter-Parameter-Auswirkungen
            test_problems = [:P1, :P2, :P3, :P4, :P5, :P6, :P7, :P8]
        else
            # Filtere OptimizationProblems.jl für geeignete Testprobleme
            try
                meta = OptimizationProblems.meta  # Metadaten aller verfügbaren Probleme
                
                # Auswahlkriterien für OptimizationProblems:
                # - 5 bis 30 Variablen (moderate Problemgröße für Parameter-Analyse)
                # - 1 bis 20 Nebenbedingungen (Probleme mit Constraints für Filter-Tests)
                # Diese Größen sind optimal für die Analyse von Filter-Parameter-Effekten
                filtered = meta[(5 .<= meta.nvar .<= 30) .& (1 .<= meta.ncon .<= 20), [:name]]
                
                # Wähle maximal 15 Probleme für repräsentativen aber handhabaren Test
                # Fokus auf Probleme mit Nebenbedingungen (wichtig für Filter-Tests)
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
        n_configs = length(filter_configs)      # Anzahl der Filter-Konfigurationen
        
        # Matrix zur Speicherung der Laufzeiten
        # Zeilen: Probleme, Spalten: Filter-Konfigurationen
        # Werte: Laufzeit in Sekunden (Inf bei Fehlschlag)
        times = Matrix{Float64}(undef, n_problems, n_configs)

        println("Teste $(n_problems) Probleme mit $(n_configs) Filter-Parameter-Konfigurationen...")
        println("Format: Konfiguration: Zeit[s] [Iterationen] oder FAIL/ERROR")
        println("Verwende optimale Basis-Konfiguration: QP-Solver=:osqp, Konvexifizierung=:lm, Globalisierung=Ein")

        # Hauptschleife: Teste jede Filter-Konfiguration auf jedem Problem
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

                # Teste jede Filter-Parameter-Konfiguration auf dem aktuellen Problem
                for (j, (name, γh, γf, sh, sf, δ, γα)) in enumerate(filter_configs)
                    try
                        # Konfiguriere Einstellungen für die spezifische Filter-Parameter-Konfiguration
                        # Verwende die besten Basis-Einstellungen aus den vorherigen Aufgaben
                        settings = Settings(
                            # Beste Basis-Konfiguration
                            qp_solver=:osqp,                     # Bester QP-Löser aus Aufgabe 2.1
                            hessian_convexification=:lm,         # Beste Konvexifizierung aus Aufgabe 2.2
                            use_globalization=true,              # Beste Globalisierung aus Aufgabe 2.3
                            use_soc=true,                        # Second-Order Corrections aktiviert
                            
                            # Standard-Parameter
                            verbose=false,                       # Keine ausführliche Ausgabe
                            max_iter=200,                        # Erhöhte Iterationszahl für gründliche Tests
                            tol=1e-8,                           # Strenge Toleranz für Genauigkeit
                            
                            # Spezifische Filter-Parameter (das ist der Test-Fokus!)
                            γh=γh,                              # Constraint-Verletzung-Toleranz
                            γf=γf,                              # Zielfunktions-Toleranz
                            sh=sh,                              # Neigungsparameter für Constraints
                            sf=sf,                              # Neigungsparameter für Zielfunktion
                            δ=δ,                                # Initialer Trust-Region-Radius
                            γα=γα                               # Schrittreduktionsfaktor
                        )

                        # Zeitmessung für den Lösungsvorgang
                        start_time = time()
                        stats = sqp_method(nlp, settings)       # Führe SQP-Verfahren aus
                        elapsed = time() - start_time

                        # Bewerte das Ergebnis und speichere die Zeit
                        if stats.sqp_status == kkt_point        # Erfolgreiche Konvergenz
                            times[i, j] = elapsed
                            print("$(name): $(round(elapsed, digits=3))s [$(stats.niter) iter] ")
                        else                                     # Konvergenz fehlgeschlagen
                            times[i, j] = Inf
                            print("$(name): FAIL [$(stats.sqp_status)] ")
                        end
                    catch e
                        # Fehlerbehandlung bei konfiguration-spezifischen Problemen
                        times[i, j] = Inf
                        print("$(name): ERROR [$(typeof(e))] ")
                    end
                end
                println()  # Neue Zeile nach jedem Problem
            catch e
                println("FEHLER beim Erstellen des Problems")
                times[i, :] .= Inf  # Markiere alle Konfigurationen als fehlgeschlagen für dieses Problem
            end
        end

        # Erstelle Performance-Profil für die Visualisierung
        config_names = [c[1] for c in filter_configs]
        plt = performance_profile(times, config_names, 
                                title="Filter-Parameter Konfigurationen Vergleich - $set_name",
                                logscale=true)  # Logarithmische Skala für bessere Darstellung

        # Stelle sicher, dass das results/ Verzeichnis existiert
        results_dir = joinpath(@__DIR__, "..", "results")
        if !isdir(results_dir)
            mkpath(results_dir)
            println("Erstelle results/ Verzeichnis...")
        end

        # Speichere das Performance-Profil als PDF
        filename = joinpath(results_dir, "filter_parameter_comparison_$(lowercase(set_name)).pdf")
        savefig(plt, filename)
        println("Ergebnisse gespeichert in: $filename")

        # Ausgabe detaillierter Zusammenfassungsstatistiken
        println("\nZusammenfassung für $set_name:")
        println("="^70)
        for (j, (name, γh, γf, sh, sf, δ, γα)) in enumerate(filter_configs)
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
                println("    Parameter: γh=$γh, γf=$γf, sh=$sh, sf=$sf, δ=$δ, γα=$γα")
            else
                println("  $name: $solved/$total gelöst ($success_rate%) | Keine erfolgreichen Läufe")
                println("    Parameter: γh=$γh, γf=$γf, sh=$sh, sf=$sf, δ=$δ, γα=$γα")
            end
        end
        println("="^70)
        
        # Zusätzliche Analyse der Filter-Parameter-Konfigurationen
        println("\nAnalyse der Filter-Parameter-Konfigurationen:")
        println("- Standard: Ausgewogene Parameter für allgemeine Anwendungen")
        println("- Aggressiv: Schnelle Konvergenz aber weniger robust bei schwierigen Problemen")
        println("- Konservativ: Sehr robust aber möglicherweise langsamer")
        println("- Adaptive: Experimentelle Parameter für optimalen Trade-off")
        println("\nFilter-Parameter-Bedeutung:")
        println("  γh, γf: Kleinere Werte → strengere Akzeptanzkriterien")
        println("  sh, sf: Größere Werte → steilere Filter-Linien")
        println("  δ: Größere Werte → aggressivere Schritte")
        println("  γα: Größere Werte → weniger Schrittreduktion")
    end
end

# Hauptprogramm ausführen
println("Starte Filter-Parameter-Konfigurationen-Vergleich...")
run_filter_parameter_comparison()

# Abschlussmeldung
println("\n" * "="^60)
println("Filter-Parameter-Konfigurationen-Vergleich abgeschlossen!")
println("Die Ergebnisse wurden als PDF-Dateien im results/ Ordner gespeichert.")
println("Performance-Profile zeigen die relative Effizienz verschiedener Filter-Parameter-Sets.")
println("Empfehlung: Verwenden Sie 'Standard' für allgemeine Anwendungen oder")
println("'Konservativ' für besonders schwierige/kritische Probleme.")
println("="^60)