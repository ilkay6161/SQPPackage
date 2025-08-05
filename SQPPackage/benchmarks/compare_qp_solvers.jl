#!/usr/bin/env julia

"""
Aufgabe 2.1: QP-Löservergleich

Dieses Benchmark-Skript führt einen systematischen Vergleich aller verfügbaren
QP-Löser durch, die von der SQP-Implementierung unterstützt werden.

Zweck:
- Vergleich der Leistung verschiedener QP-Löser (OSQP, Clarabel, Ipopt, MadNLP)
- Test auf zwei verschiedenen Problemsets: eigene Testprobleme und OptimizationProblems.jl
- Erstellung von Performance-Profilen zur Visualisierung der relativen Stärken
- Speicherung der Ergebnisse als PDF-Dateien im results/ Ordner

Methodik:
- Jeder QP-Löser wird mit identischen Einstellungen getestet
- Zeitmessung für jeden Lösungsvorgang
- Erfolgsrate und Konvergenzverhalten werden erfasst
- Performance-Profile zeigen die relative Effizienz der Löser
"""

# Füge das übergeordnete Verzeichnis zum Ladepfad hinzu, um SQPPackage zu finden
push!(LOAD_PATH, joinpath(@__DIR__, ".."))
push!(LOAD_PATH, @__DIR__)

# Importiere alle benötigten Pakete
using SQPPackage          # Unser Hauptpaket mit der SQP-Implementierung
using Benchmarking       # Lokales Benchmarking-Modul
using Plots              # Für die Erstellung von Diagrammen und Performance-Profilen
using Printf             # Für formatierte Ausgaben
using Statistics         # Für statistische Funktionen (Mittelwert, Median)
using OptimizationProblems  # Externe Sammlung von Optimierungsproblemen

# Ausgabe des Programm-Headers
println("="^60)
println("QP-Solver Comparison Benchmark - Aufgabe 2.1")
println("Systematischer Vergleich aller unterstützten QP-Löser")
println("="^60)

"""
Hauptfunktion für den QP-Löser-Vergleich

Diese Funktion orchestriert den gesamten Benchmark-Prozess:
1. Definition der zu testenden Problemsets
2. Konfiguration der QP-Löser
3. Durchführung der Tests
4. Erstellung der Performance-Profile
5. Speicherung der Ergebnisse
"""
function run_qp_solver_comparison()
    # Definition der beiden Testsets
    # - TestProblems: Unsere eigenen definierten Probleme P1-P8
    # - OptimizationProblems: Externe Sammlung aus OptimizationProblems.jl
    problem_sets = [
        ("TestProblems", true),           # (Name, verwende_eigene_testprobleme)
        ("OptimizationProblems", false)   # Externe Probleme
    ]

    # Liste aller zu vergleichenden QP-Löser
    # Diese entsprechen den in der SQP-Implementierung verfügbaren Lösern
    qp_solvers = [:osqp, :clarabel, :ipopt, :madnlp]

    # Iteriere über beide Problemsets
    for (set_name, use_test_problems) in problem_sets
        println("\nTeste auf $set_name...")
        println("Lade und konfiguriere Probleme...")

        # Problemauswahl basierend auf dem aktuellen Set
        if use_test_problems
            # Verwende unsere eigenen Testprobleme P1 bis P8
            # Diese sind speziell für SQP-Tests entwickelt und decken verschiedene
            # Problemtypen ab (unrestringiert, Gleichheitsnebenbedingungen, etc.)
            test_problems = [:P1, :P2, :P3, :P4, :P5, :P6, :P7, :P8]
        else
            # Filtere OptimizationProblems.jl für geeignete Testprobleme
            try
                meta = OptimizationProblems.meta  # Metadaten aller verfügbaren Probleme
                
                # Auswahlkriterien für OptimizationProblems:
                # - 5 bis 30 Variablen (moderate Problemgröße für QP-Vergleich)
                # - 1 bis 20 Nebenbedingungen (Probleme mit Constraints)
                # Diese Größen sind optimal für QP-Löser-Vergleiche
                filtered = meta[(5 .<= meta.nvar .<= 30) .& (1 .<= meta.ncon .<= 20), [:name]]
                
                # Wähle maximal 15 Probleme für repräsentativen aber handhabaren Test
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
        n_problems = length(test_problems)   # Anzahl der Testprobleme
        n_solvers = length(qp_solvers)       # Anzahl der QP-Löser
        
        # Matrix zur Speicherung der Laufzeiten
        # Zeilen: Probleme, Spalten: Löser
        # Werte: Laufzeit in Sekunden (Inf bei Fehlschlag)
        times = Matrix{Float64}(undef, n_problems, n_solvers)

        println("Teste $(n_problems) Probleme mit $(n_solvers) QP-Lösern...")
        println("Format: Löser: Zeit[s] [Iterationen] oder FAIL/ERROR")

        # Hauptschleife: Teste jeden QP-Löser auf jedem Problem
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

                # Teste jeden QP-Löser auf dem aktuellen Problem
                for (j, qp_solver) in enumerate(qp_solvers)
                    try
                        # Konfiguriere Einstellungen für den spezifischen QP-Löser
                        settings = Settings(
                            qp_solver=qp_solver,              # Aktueller QP-Löser
                            verbose=false,                    # Keine ausführliche Ausgabe
                            max_iter=200,                     # Erhöhte Iterationszahl für gründliche Tests
                            tol=1e-8,                         # Strenge Toleranz für Genauigkeit
                            use_globalization=true,           # Verwende Globalisierungsstrategien
                            hessian_convexification=:lm       # Konsistente Hessian-Konvexifizierung
                        )

                        # Zeitmessung für den Lösungsvorgang
                        start_time = time()
                        stats = sqp_method(nlp, settings)    # Führe SQP-Verfahren aus
                        elapsed = time() - start_time

                        # Bewerte das Ergebnis und speichere die Zeit
                        if stats.sqp_status == kkt_point     # Erfolgreiche Konvergenz
                            times[i, j] = elapsed
                            print("$(qp_solver): $(round(elapsed, digits=3))s [$(stats.niter) iter] ")
                        else                                  # Konvergenz fehlgeschlagen
                            times[i, j] = Inf
                            print("$(qp_solver): FAIL [$(stats.sqp_status)] ")
                        end
                    catch e
                        # Fehlerbehandlung bei Löser-spezifischen Problemen
                        times[i, j] = Inf
                        print("$(qp_solver): ERROR [$(typeof(e))] ")
                        # Spezielle Hinweise für QuadraticModels-basierte Löser
                        if qp_solver == :ipopt || qp_solver == :madnlp
                            print("(QuadraticModels möglicherweise nicht verfügbar) ")
                        end
                    end
                end
                println()  # Neue Zeile nach jedem Problem
            catch e
                println("FEHLER beim Erstellen des Problems")
                times[i, :] .= Inf  # Markiere alle Löser als fehlgeschlagen für dieses Problem
            end
        end

        # Erstelle Performance-Profil für die Visualisierung
        solver_names = string.(qp_solvers)
        plt = performance_profile(times, solver_names, 
                                title="QP-Löser Vergleich - $set_name",
                                logscale=true)  # Logarithmische Skala für bessere Darstellung

        # Stelle sicher, dass das results/ Verzeichnis existiert
        results_dir = joinpath(@__DIR__, "..", "results")
        if !isdir(results_dir)
            mkpath(results_dir)
            println("Erstelle results/ Verzeichnis...")
        end

        # Speichere das Performance-Profil als PDF
        filename = joinpath(results_dir, "qp_solver_comparison_$(lowercase(set_name)).pdf")
        savefig(plt, filename)
        println("Ergebnisse gespeichert in: $filename")

        # Ausgabe detaillierter Zusammenfassungsstatistiken
        println("\nZusammenfassung für $set_name:")
        println("="^50)
        for (j, solver) in enumerate(qp_solvers)
            # Berechne Erfolgsstatistiken
            solved = sum(isfinite.(times[:, j]))        # Anzahl erfolgreich gelöster Probleme
            total = size(times, 1)                      # Gesamtanzahl der Probleme
            success_rate = round(100 * solved / total, digits=1)  # Erfolgsrate in Prozent
            
            if solved > 0
                # Berechne Zeitstatistiken nur für erfolgreiche Läufe
                finite_times = times[isfinite.(times[:, j]), j]
                avg_time = round(mean(finite_times), digits=4)      # Durchschnittszeit
                median_time = round(median(finite_times), digits=4) # Medianzeit
                min_time = round(minimum(finite_times), digits=4)   # Schnellste Zeit
                max_time = round(maximum(finite_times), digits=4)   # Langsamste Zeit
                
                println("  $solver: $solved/$total gelöst ($success_rate%) | Ø: $(avg_time)s | Med: $(median_time)s | Bereich: [$(min_time)s, $(max_time)s]")
            else
                println("  $solver: $solved/$total gelöst ($success_rate%) | Keine erfolgreichen Läufe")
            end
        end
        println("="^50)
    end
end

# Hauptprogramm ausführen
println("Starte QP-Löser-Vergleich...")
run_qp_solver_comparison()

# Abschlussmeldung
println("\n" * "="^60)
println("QP-Löser-Vergleich abgeschlossen!")
println("Die Ergebnisse wurden als PDF-Dateien im results/ Ordner gespeichert.")
println("Performance-Profile zeigen die relative Effizienz der verschiedenen QP-Löser.")
println("="^60)