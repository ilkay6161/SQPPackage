# Aufgaben 2.1 und 2.2 - Vollständige Dokumentation

## Überblick

Diese Dokumentation beschreibt die Implementierung und vollständige Kommentierung der Aufgaben 2.1 (QP-Löservergleich) und 2.2 (Analyse der Hessian-Konvexifizierung) für die SQP-Implementierung.

## Aufgabe 2.1: QP-Löservergleich

### Zweck und Ziele
- **Systematischer Vergleich** aller verfügbaren QP-Löser der SQP-Implementierung
- **Leistungsbewertung** auf zwei verschiedenen Problemsets
- **Performance-Profile** zur Visualisierung der relativen Stärken und Schwächen
- **PDF-Ausgabe** der Ergebnisse im `results/` Ordner

### Implementierte QP-Löser
1. **OSQP** - Open Source Quadratic Programming Solver
   - Spezialisiert auf große, dünn besetzte QP-Probleme
   - Verwendet ADMM (Alternating Direction Method of Multipliers)
   - Robust und schnell für viele Problemtypen

2. **Clarabel** - Moderner conic solver
   - Unterstützt verschiedene Kegeltypen
   - Gute numerische Stabilität
   - Effizient für gemischt-ganzzahlige Probleme

3. **Ipopt** - Interior Point Optimizer (über QuadraticModels)
   - Klassischer Interior-Point-Algorithmus
   - Sehr robust für nichtlineare Probleme
   - Kann bei QP-Subproblemen langsamer sein

4. **MadNLP** - Modern Algorithmic Differentiation for NLP (über QuadraticModels)
   - Neuere Interior-Point-Implementierung
   - Optimiert für moderne Rechnerarchitekturen
   - Gute Performance bei größeren Problemen

### Testproblemsets

#### 1. Eigene Testprobleme (P1-P8)
- **P1**: Unrestringiertes quadratisches Problem
- **P2**: Quadratisches Problem mit linearen Gleichheitsnebenbedingungen
- **P3**: Quartisches Problem mit linearen Nebenbedingungen
- **P4**: Nichtlineares Problem mit Variablengrenzen
- **P5-P8**: Weitere nichtlineare Probleme verschiedener Komplexität

#### 2. OptimizationProblems.jl
- Auswahlkriterien: 5-30 Variablen, 1-20 Nebenbedingungen
- Maximal 15 repräsentative Probleme
- Fokus auf moderate Problemgrößen für QP-Löser-Vergleiche

### Benchmark-Methodik
1. **Einheitliche Konfiguration** für alle QP-Löser
2. **Zeitmessung** für jeden Lösungsvorgang
3. **Erfolgsraten-Analyse** (Konvergenz vs. Fehlschlag)
4. **Performance-Profile** nach Dolan-Moré Standard
5. **Statistische Auswertung** (Mittelwert, Median, Bereiche)

### Ausgabe und Ergebnisse
- **PDF-Dateien** im `results/` Ordner:
  - `qp_solver_comparison_testproblems.pdf`
  - `qp_solver_comparison_optimizationproblems.pdf`
- **Performance-Profile** mit logarithmischer Skalierung
- **Detaillierte Statistiken** für jeden QP-Löser

## Aufgabe 2.2: Analyse der Hessian-Konvexifizierung

### Zweck und Ziele
- **Vergleich aller implementierten Konvexifizierungstechniken**
- **Analyse des Einflusses** auf Konvergenzverhalten und Rechenleistung
- **Bestimmung der optimalen Regularisierungsstrategie**
- **Performance-Profile** für verschiedene Konvexifizierungsmethoden

### Implementierte Konvexifizierungsstrategien

#### 1. `:none` - Keine Konvexifizierung
```julia
# Verwendet die ursprüngliche Hesse-Matrix unverändert
H_new = H_original
```
- **Vorteile**: Exakte Hesse-Information, keine Rechenkosten
- **Nachteile**: Kann bei indefiniten Matrizen fehlschlagen
- **Anwendung**: Theoretische Studien, gut konditionierte Probleme

#### 2. `:lm` - Levenberg-Marquardt Regularisierung
```julia
# H_new = H + λI mit λ = max(0, -λ_min + ε)
λ_min = minimum(eigvals(H))
if λ_min < 0
    H_new = H + (abs(λ_min) + ε) * I
end
```
- **Vorteile**: Kostengünstig, bewahrt Struktur
- **Nachteile**: Gleichmäßige Diagonaladdition kann zu stark regularisieren
- **Kosten**: O(n³) für Eigenwertberechnung
- **Anwendung**: Standard-Wahl für viele Probleme

#### 3. `:project` - Eigenwerk-Projektion
```julia
# H_new = Q * max(Λ, εI) * Q^T
E = eigen(H)
Λ_proj = max.(E.values, ε)
H_new = E.vectors * Diagonal(Λ_proj) * E.vectors'
```
- **Vorteile**: Minimale Änderung im Frobenius-Norm-Sinn
- **Nachteile**: Teuer, zerstört Dünnbesetztheit
- **Kosten**: O(n³) für vollständige Eigenwertzerlegung
- **Anwendung**: Kleine/mittlere Probleme, wo Genauigkeit wichtig ist

#### 4. `:mirror` - Eigenwerk-Spiegelung
```julia
# H_new = Q * max(|Λ|, εI) * Q^T  
E = eigen(H)
Λ_mirror = max.(abs.(E.values), ε)
H_new = E.vectors * Diagonal(Λ_mirror) * E.vectors'
```
- **Vorteile**: Bewahrt Eigenwert-Größenordnungen
- **Nachteile**: Kann ursprüngliche Matrix stark verändern
- **Kosten**: O(n³) für vollständige Eigenwertzerlegung
- **Anwendung**: Schlecht konditionierte Probleme

#### 5. `:gershgorin` - Gershgorin-Kreise Abschätzung
```julia
# Basierend auf Gershgorin-Theorem
for i in 1:n
    r_i = sum(abs, H[i, :]) - abs(H[i, i])  # Radius
    λ_i = H[i, i] - r_i                      # Untere Grenze
    λ_min = min(λ_min, λ_i)
end
if λ_min < 0
    H_new = H + (abs(λ_min) + ε) * I
end
```
- **Vorteile**: Sehr kostengünstig, bewahrt Dünnbesetztheit
- **Nachteile**: Konservative Abschätzung, Über-Regularisierung möglich
- **Kosten**: O(n²) für Radius-Berechnung
- **Anwendung**: Große Probleme, wo Effizienz wichtig ist

### Benchmark-Methodik
1. **Konsistenter QP-Löser** (OSQP) für faire Vergleiche
2. **Identische Problemsets** wie in Aufgabe 2.1
3. **Zeitmessung und Konvergenzanalyse** für jede Strategie
4. **Performance-Profile** zur Visualisierung
5. **Detaillierte Statistiken** für jede Konvexifizierungsmethode

### Ausgabe und Ergebnisse
- **PDF-Dateien** im `results/` Ordner:
  - `hessian_convexification_comparison_testproblems.pdf`
  - `hessian_convexification_comparison_optimizationproblems.pdf`
- **Performance-Profile** mit Strategievergleich
- **Empfehlungen** für verschiedene Problemtypen

## Technische Implementierung

### Performance-Profile
```julia
# Mathematische Definition:
# r_{j,s} = t_{j,s} / min_s(t_{j,s})  (Performance-Ratio)
# ρ_s(τ) = |{j : r_{j,s} ≤ τ}| / |J|  (Erfolgsanteil)

function performance_profile(times, names; logscale=false)
    τ = exp.(range(log(1), log(100), length=100))
    # Für jeden Solver/jede Strategie:
    # - Berechne Performance-Ratios
    # - Bestimme Erfolgsanteile ρ(τ)
    # - Visualisiere als Kurve
end
```

### Interpretation der Performance-Profile
- **ρ(1)**: Anteil der Probleme, wo der Solver/die Strategie am schnellsten war
- **ρ(∞)**: Anteil der Probleme, die überhaupt gelöst werden konnten
- **Höhere Kurven**: Bessere Performance
- **Steile Anstiege**: Robuste Performance bei verschiedenen Problemtypen

### Dateistruktur
```
SQPPackage/
├── benchmarks/
│   ├── compare_qp_solvers.jl           # Aufgabe 2.1
│   └── compare_hessian_convexification.jl  # Aufgabe 2.2
├── src/
│   ├── benchmarking.jl                 # Performance-Profile
│   ├── convexify.jl                    # Konvexifizierungsstrategien
│   ├── qp_interface.jl                 # QP-Löser Interface
│   └── sqp_method.jl                   # Haupt-SQP-Algorithmus
├── results/                            # PDF-Ausgaben
└── AUFGABEN_DOKUMENTATION.md          # Diese Dokumentation
```

## Verwendung

### Aufgabe 2.1 ausführen:
```bash
cd SQPPackage
julia --project=. benchmarks/compare_qp_solvers.jl
```

### Aufgabe 2.2 ausführen:
```bash
cd SQPPackage  
julia --project=. benchmarks/compare_hessian_convexification.jl
```

### Ergebnisse anzeigen:
```bash
ls results/
# Erwartete Dateien:
# - qp_solver_comparison_testproblems.pdf
# - qp_solver_comparison_optimizationproblems.pdf
# - hessian_convexification_comparison_testproblems.pdf
# - hessian_convexification_comparison_optimizationproblems.pdf
```

## Empfehlungen basierend auf den Analysen

### QP-Löser-Wahl:
- **OSQP**: Erste Wahl für die meisten Probleme (Balance aus Geschwindigkeit und Robustheit)
- **Clarabel**: Für Probleme mit speziellen Kegel-Constraints
- **Ipopt/MadNLP**: Für sehr große oder spezielle nichtlineare Probleme

### Konvexifizierungsstrategie-Wahl:
- **Kleine Probleme (n < 100)**: `:project` für optimale Genauigkeit
- **Mittlere Probleme (100 ≤ n < 1000)**: `:lm` als guter Kompromiss
- **Große Probleme (n ≥ 1000)**: `:gershgorin` für Effizienz
- **Schlecht konditionierte Probleme**: `:mirror` für Robustheit
- **Theoretische Studien**: `:none` zum Vergleich mit exakter Hesse-Matrix

## Fazit

Die vollständig kommentierten und verbesserten Benchmark-Skripte ermöglichen eine systematische Analyse der SQP-Implementierung. Die Performance-Profile und detaillierten Statistiken bieten wertvolle Einblicke in die relativen Stärken verschiedener QP-Löser und Konvexifizierungsstrategien, wodurch fundierte Entscheidungen für die Optimierung der SQP-Performance getroffen werden können.