"""
ConvexifyModule - Hessian-Konvexifizierungsmodul

Dieses Modul implementiert verschiedene Strategien zur Konvexifizierung der 
Hesse-Matrix im SQP-Verfahren. Die Konvexifizierung ist notwendig, da:

1. Das SQP-Verfahren in jeder Iteration ein quadratisches Teilproblem löst
2. QP-Löser positive definite Matrizen für Konvergenzgarantien benötigen
3. Die exakte Hesse-Matrix kann indefinit oder negativ definit sein
4. Konvexifizierung stellt positive Definitheit sicher

Implementierte Strategien:
- :none - Keine Modifikation (kann bei indefiniten Matrizen fehlschlagen)
- :lm - Levenberg-Marquardt: H + λI mit λ ≥ -λ_min + ε
- :project - Projektion: H = QΛ₊Qᵀ mit Λ₊ = max(Λ, εI)
- :mirror - Spiegelung: H = Q|Λ|Qᵀ mit |Λ| = max(|Λ|, εI)
- :gershgorin - Gershgorin-Kreise: Diagonalmodifikation basierend auf Gershgorin-Abschätzung

Jede Strategie hat spezifische Vor- und Nachteile bezüglich:
- Rechenkosten (Eigenwertzerlegung vs. Diagonalmodifikation)
- Nähe zur ursprünglichen Hesse-Matrix
- Robustheit bei schlecht konditionierten Problemen
- Konvergenzverhalten des SQP-Verfahrens
"""
module ConvexifyModule

# Importiere notwendige Module für lineare Algebra und dünn besetzte Matrizen
using LinearAlgebra   # Für Eigenwertzerlegung, Normen, Diagonalmatrizen
using SparseArrays    # Für die Arbeit mit dünn besetzten Matrizen (Sparse Matrices)

# Importiere den Settings-Typ aus dem übergeordneten Modul
import ..SettingsModule: Settings

# Exportiere die öffentlichen Funktionen
export convexify_hessian!, convexify_hessian

"""
    convexify_hessian!(H::Union{Matrix{Float64}, Symmetric{Float64, SparseMatrixCSC{Float64, Int64}}}, settings::Settings)

Konvexifiziert die Hesse-Matrix H in-place entsprechend der gewählten Strategie.

Diese Funktion modifiziert die übergebene Hesse-Matrix direkt, um positive 
Definitheit zu gewährleisten. Die spezifische Konvexifizierungsstrategie wird
durch settings.hessian_convexification bestimmt.

Algorithmus-Übersicht:
1. Konvertierung in dichte Matrix (falls sparse)
2. Validitätsprüfung (NaN/Inf-Behandlung)
3. Strategiebasierte Konvexifizierung
4. Rückgabe der modifizierten Matrix

Parameter:
- H: Hesse-Matrix (dicht oder dünn besetzt, wird modifiziert)
- settings: Konfigurationsobjekt mit Konvexifizierungsparametern
  - settings.hessian_convexification: Gewählte Strategie
  - settings.epsilon: Numerische Toleranz/Regularisierungsparameter

Rückgabe:
- Matrix{Float64}: Die konvexifizierte Hesse-Matrix (positive definit)

Seiteneffekte:
- H wird direkt modifiziert (in-place Operation)
"""
function convexify_hessian!(H::Union{Matrix{Float64}, LinearAlgebra.Symmetric{Float64, SparseArrays.SparseMatrixCSC{Float64, Int64}}}, settings::Settings)
    # Schritt 1: Konvertierung in dichte Matrix für einheitliche Behandlung
    # Sparse-Matrizen werden für Eigenwertzerlegung in dichte Matrizen umgewandelt
    H_dense = isa(H, SparseArrays.SparseMatrixCSC) || isa(H, LinearAlgebra.Symmetric{Float64, SparseArrays.SparseMatrixCSC{Float64, Int64}}) ? Matrix(H) : H
    n = size(H_dense, 1) # Dimension der quadratischen Matrix
    ϵ = settings.epsilon # Numerische Toleranz aus den Benutzereinstellungen

    # Schritt 2: Robuste Behandlung numerischer Probleme
    # Prüfe auf ungültige Werte (NaN oder Inf), die durch numerische Instabilitäten entstehen können
    if any(x -> !isfinite(x), H_dense)
        println("WARNUNG: Hessian enthält NaN oder Inf - wird durch Identitätsmatrix ersetzt")
        # Fallback: Ersetze durch skalierte Einheitsmatrix (garantiert positive definit)
        H_dense = Matrix(I, n, n) * ϵ
        return H_dense
    end

    # Schritt 3: Strategiebasierte Konvexifizierung
    strategy = settings.hessian_convexification # Hole die gewählte Konvexifizierungsstrategie

    if strategy == :none
        # Strategie 1: Keine Konvexifizierung
        # Verwendet die ursprüngliche Hesse-Matrix unverändert
        # Vorteil: Exakte Hesse-Information, keine zusätzlichen Kosten
        # Nachteil: Kann bei indefiniten Matrizen zu QP-Solver-Fehlern führen
        return H_dense 
        
    elseif strategy == :lm
        # Strategie 2: Levenberg-Marquardt-Regularisierung
        # Algorithmus: H_new = H + λI mit λ = max(0, -λ_min + ε)
        # Berechne den kleinsten Eigenwert der symmetrischen Matrix
        Lambda_min = minimum(eigvals(LinearAlgebra.Symmetric(H_dense)))
        
        if Lambda_min < 0
            # Falls negativer Eigenwert: Addiere Regularisierungsterm zur Diagonale
            add_val = abs(Lambda_min) + ϵ # Regularisierungsparameter
            for i in 1:n
                H_dense[i, i] += add_val # Diagonaladdition: H_ii = H_ii + λ
            end
        end
        # Vorteil: Kostengünstig (nur Eigenwertberechnung), bewahrt Struktur
        # Nachteil: Kann die Hesse-Matrix stark verändern bei großen negativen Eigenwerten
        
    elseif strategy == :project
        # Strategie 3: Eigenwerk-Projektion
        # Algorithmus: H_new = Q * max(Λ, εI) * Q^T
        # Führe vollständige Eigenwertzerlegung durch: H = QΛQ^T
        E = eigen(LinearAlgebra.Symmetric(H_dense))
        
        # Projiziere negative Eigenwerte auf ε (macht sie positiv)
        Lambda_proj = max.(E.values, ϵ)
        
        # Rekonstruiere Matrix: H_new = Q * Λ_proj * Q^T
        H_dense .= E.vectors * LinearAlgebra.Diagonal(Lambda_proj) * E.vectors'
        # Vorteil: Minimale Änderung im Frobenius-Norm-Sinn
        # Nachteil: Teuer (vollständige Eigenwertzerlegung), kann Dünnbesetztheit zerstören
        
    elseif strategy == :mirror
        # Strategie 4: Eigenwerk-Spiegelung
        # Algorithmus: H_new = Q * max(|Λ|, εI) * Q^T
        # Führe vollständige Eigenwertzerlegung durch
        E = eigen(LinearAlgebra.Symmetric(H_dense))
        
        # Nimm Betrag aller Eigenwerte (spiegelt negative an der Null-Achse)
        # Stelle sicher, dass alle Eigenwerte mindestens ε sind
        Lambda_mirror = max.(abs.(E.values), ϵ)
        
        # Rekonstruiere Matrix mit gespiegelten Eigenwerten
        H_dense .= E.vectors * LinearAlgebra.Diagonal(Lambda_mirror) * E.vectors'
        # Vorteil: Bewahrt die "Größenordnung" der ursprünglichen Eigenwerte
        # Nachteil: Kann die ursprüngliche Matrix stärker verändern als Projektion
        
    elseif strategy == :gershgorin
        # Strategie 5: Gershgorin-Kreise-Abschätzung
        # Algorithmus: Modifiziere Diagonale basierend auf Gershgorin-Theorem
        # Gershgorin-Theorem: Alle Eigenwerte liegen in Vereinigung der Gershgorin-Kreise
        # Kreis i: Zentrum = H_ii, Radius = Σ_{j≠i} |H_ij|
        
        Lambda_min = Inf # Initialisiere minimal geschätzte untere Eigenwergrenze
        for i in 1:n
            # Berechne Radius des i-ten Gershgorin-Kreises
            r_i = sum(abs, H_dense[i, :]) - abs(H_dense[i, i])
            
            # Untere Grenze des i-ten Kreises (konservative Eigenwertabschätzung)
            Lambda_i = H_dense[i, i] - r_i
            
            # Finde die kleinste untere Grenze über alle Kreise
            Lambda_min = min(Lambda_min, Lambda_i)
        end
        
        if Lambda_min < 0
            # Falls geschätzte untere Grenze negativ: Regularisiere Diagonale
            add_val = abs(Lambda_min) + ϵ
            for i in 1:n
                H_dense[i, i] += add_val # Addiere Regularisierung zur Diagonale
            end
        end
        # Vorteil: Sehr kostengünstig (keine Eigenwertzerlegung), bewahrt Dünnbesetztheit
        # Nachteil: Konservative Abschätzung kann zu Über-Regularisierung führen
        
    else
        # Fehlerbehandlung für unbekannte Strategien
        error("Unbekannte Konvexifizierungsstrategie: $strategy. Verfügbare Optionen: :none, :lm, :project, :mirror, :gershgorin")
    end

    # Rückgabe der konvexifizierten (positive definiten) Matrix
    return H_dense
end

"""
    convexify_hessian(H::Union{Matrix{Float64}, Symmetric{Float64, SparseMatrixCSC{Float64, Int64}}}, settings::Settings)

Konvexifiziert eine Kopie der Hesse-Matrix (nicht in-place Version).

Diese Funktion ist eine Wrapper-Funktion für convexify_hessian!, die eine
Kopie der ursprünglichen Matrix erstellt und dann konvexifiziert. Verwenden Sie
diese Funktion, wenn Sie die ursprüngliche Matrix unverändert lassen möchten.

Parameter:
- H: Ursprüngliche Hesse-Matrix (wird nicht modifiziert)
- settings: Konfigurationsobjekt mit Konvexifizierungsparametern

Rückgabe:
- Matrix{Float64}: Neue konvexifizierte Matrix (ursprüngliche H bleibt unverändert)

Beispiel:
```julia
H_original = [2.0 1.0; 1.0 -1.0]  # Indefinite Matrix
settings = Settings(hessian_convexification=:lm, epsilon=1e-6)
H_convex = convexify_hessian(H_original, settings)
# H_original bleibt unverändert, H_convex ist positive definit
```
"""
function convexify_hessian(H::Union{Matrix{Float64}, LinearAlgebra.Symmetric{Float64, SparseArrays.SparseMatrixCSC{Float64, Int64}}}, settings::Settings)
    # Erstelle eine dichte Kopie der ursprünglichen Matrix
    H_copy = Matrix(H)
    
    # Rufe die in-place Funktion auf der Kopie auf
    return convexify_hessian!(H_copy, settings)
end

end # Ende des ConvexifyModule

"""
Zusammenfassung der Konvexifizierungsstrategien:

1. :none - Keine Modifikation
   - Kosten: O(1)
   - Genauigkeit: Exakt
   - Robustheit: Niedrig (kann fehlschlagen)

2. :lm (Levenberg-Marquardt)
   - Kosten: O(n³) für Eigenwertberechnung
   - Genauigkeit: Mäßig (gleichmäßige Diagonaladdition)
   - Robustheit: Hoch

3. :project (Eigenwerk-Projektion)
   - Kosten: O(n³) für vollständige Eigenwertzerlegung
   - Genauigkeit: Optimal (minimale Frobenius-Norm-Änderung)
   - Robustheit: Sehr hoch

4. :mirror (Eigenwerk-Spiegelung)
   - Kosten: O(n³) für vollständige Eigenwertzerlegung
   - Genauigkeit: Gut (bewahrt Eigenwert-Größenordnungen)
   - Robustheit: Sehr hoch

5. :gershgorin (Gershgorin-Abschätzung)
   - Kosten: O(n²) für Radius-Berechnung
   - Genauigkeit: Mäßig (kann über-regularisieren)
   - Robustheit: Hoch

Empfehlungen:
- Für kleine/mittlere Probleme: :project (optimal, aber teuer)
- Für große Probleme: :lm oder :gershgorin (schneller)
- Für sehr schlecht konditionierte Probleme: :mirror
- Für theoretische Studien: :none (um exakte Hesse-Information zu bewahren)
"""