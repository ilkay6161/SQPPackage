"""
ProblemTypesModule.jl - Grundlegende Datentypen für Optimierungsprobleme

Dieses Modul definiert die grundlegenden Datenstrukturen und Typen,
die für die Darstellung und Bearbeitung von Optimierungsproblemen
im SQP-Solver verwendet werden.

Zweck:
- Vereinheitlichung der Problemrepräsentation
- Type-Safety für numerische Berechnungen
- Schnittstelle zu externen NLP-Modellen
"""

# Grundlegende numerische Typen für den SQP-Solver
const FloatType = Float64          # Standard-Gleitkommatyp für alle Berechnungen
const IntType = Int               # Standard-Ganzzahltyp für Indizes und Zähler

# Vektor- und Matrixtypen für effiziente lineare Algebra
const VectorType = Vector{FloatType}      # Standardvektortyp
const MatrixType = Matrix{FloatType}      # Standardmatrixtyp

# Sparse-Typen für große, dünnbesetzte Probleme
const SparseMatrixType = SparseMatrixCSC{FloatType, IntType}
const SparseVectorType = SparseVector{FloatType, IntType}


# Exportiere die abstrakten Typen und Strukturen, damit sie außerhalb dieses Moduls sichtbar sind.
export AbstractNLPModel, OptimizationProblem


abstract type AbstractNLPModel end

mutable struct OptimizationProblem <: AbstractNLPModel
    meta::NamedTuple # Metadaten des Optimierungsproblems
    obj_func::Function # Zielfunktion f(x)
    grad_func::Function # Gradient der Zielfunktion ∇f(x)
    hess_func::Function # Hesse-Matrix der Lagrange-Funktion ∇²ₓₓL(x, λ)
    cons_func::Function # Nebenbedingungen c(x)
    jac_func::Function # Jacobi-Matrix der Nebenbedingungen ∇c(x)
end

end # Ende des Moduls ProblemTypes