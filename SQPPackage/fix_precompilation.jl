#!/usr/bin/env julia

"""
Hilfsskript zur Behebung von Precompilation-Problemen

Dieses Skript löscht den Precompilation-Cache und führt eine saubere 
Neuinstallation der Abhängigkeiten durch.
"""

println("="^60)
println("Behebung von Precompilation-Problemen")
println("="^60)

# Schritt 1: Aktuelles Verzeichnis anzeigen
println("Aktuelles Arbeitsverzeichnis: ", pwd())

# Schritt 2: Julia-Cache löschen
println("\nSchritt 1: Lösche Julia-Precompilation-Cache...")
try
    # Pfad zum Julia-Cache-Verzeichnis
    julia_cache = joinpath(homedir(), ".julia", "compiled")
    if isdir(julia_cache)
        println("Cache-Verzeichnis gefunden: $julia_cache")
        println("Lösche Cache...")
        rm(julia_cache; recursive=true, force=true)
        println("✓ Cache erfolgreich gelöscht!")
    else
        println("Kein Cache-Verzeichnis gefunden.")
    end
catch e
    println("⚠ Warnung beim Löschen des Caches: $e")
    println("Sie können den Cache manuell unter ~/.julia/compiled/ löschen")
end

# Schritt 3: Pakete neu installieren
println("\nSchritt 2: Installiere Abhängigkeiten neu...")
using Pkg

try
    # Aktiviere das Projekt
    Pkg.activate(".")
    println("✓ Projekt aktiviert")
    
    # Entferne alte Abhängigkeiten
    println("Bereinige Abhängigkeiten...")
    Pkg.resolve()
    
    # Installiere alle Abhängigkeiten neu
    println("Installiere Abhängigkeiten...")
    Pkg.instantiate()
    println("✓ Abhängigkeiten installiert")
    
    # Precompiliere das Paket
    println("Precompiliere SQPPackage...")
    Pkg.precompile()
    println("✓ Precompilation abgeschlossen")
    
catch e
    println("❌ Fehler bei der Paketinstallation: $e")
    println("Versuchen Sie manuell:")
    println("  julia --project=. -e \"using Pkg; Pkg.resolve(); Pkg.instantiate(); Pkg.precompile()\"")
end

println("\n" * "="^60)
println("Bereinigung abgeschlossen!")
println("Sie können jetzt versuchen, die Benchmark-Skripte auszuführen:")
println("  julia --project=. benchmarks/compare_qp_solvers.jl")
println("  julia --project=. benchmarks/compare_hessian_convexification.jl")
println("="^60)