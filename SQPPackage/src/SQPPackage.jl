"""
SQPPackage.jl - Sequential Quadratic Programming (SQP) Solver

Ein vollständiges SQP-Paket zur Lösung nichtlinearer Optimierungsprobleme mit Nebenbedingungen.
Das Paket implementiert moderne SQP-Techniken einschließlich Filter-basierter Liniensuche,
verschiedener Hessian-Konvexifizierungsstrategien und mehrerer QP-Solver-Interfaces.

Hauptmerkmale:
- Vollständiger SQP-Algorithmus mit Filter-basierter Globalisierung
- Unterstützung für mehrere QP-Solver (OSQP, Clarabel, Ipopt, MadNLP)
- Verschiedene Hessian-Konvexifizierungsstrategien
- Second-Order Corrections für verbesserte Konvergenz
- Umfangreiches Benchmarking-System
- Sammlung von Testproblemen

Autoren: [Ihr Name]
Version: 1.0
Lizenz: MIT
"""
module SQPPackage

#= ================================================================================
   IMPORT VON EXTERNEN PAKETEN
   ================================================================================ =#

# Grundlegende mathematische und wissenschaftliche Bibliotheken
using LinearAlgebra         # Lineare Algebra-Operationen (Matrizen, Vektoren, Eigenwerte)
using SparseArrays         # Effiziente dünnbesetzte Matrizen für große Probleme
using Printf              # Formatierte Ausgabe für Debugging und Berichte

# NLP-Modellierung und automatische Differentiation
using NLPModels           # Standardschnittstelle für nichtlineare Optimierungsprobleme
using ADNLPModels         # Automatische Differentiation für NLP-Modelle
using QuadraticModels     # Quadratische Programmierung Unterstützung

# Parameter-Handling für saubere Konfigurationsstrukturen
using Parameters: @with_kw  # Macro für elegante Strukturdefinitionen mit Standardwerten

#= ================================================================================
   IMPORT VON QP- UND NLP-SOLVERN
   ================================================================================ =#

# QP-Solver für die Lösung der quadratischen Subprobleme
import Clarabel           # Moderner Interior-Point QP-Solver
import OSQP              # Operator Splitting QP-Solver (sehr robust)

# NLP-Solver für Vergleichszwecke
import Ipopt             # Etablierter Interior-Point NLP-Solver
import MadNLP            # Moderner AD-basierter NLP-Solver

#= ================================================================================
   EINBINDUNG DER INTERNEN MODULE
   ================================================================================ =#

# Grundlegende Datenstrukturen und Konfiguration
include("problem_types.jl")          # Definition von Problemtypen und Datenstrukturen
include("settings.jl")               # Konfigurationsparameter und Solver-Einstellungen
include("stats.jl")                  # Statistiken, Status und Konvergenzinformationen

# Mathematische Kernfunktionen
include("residuals.jl")              # Berechnung von KKT-Residuen und Konvergenztests
include("convexify.jl")              # Hessian-Konvexifizierungsalgorithmen

# Solver-Komponenten
include("qp_interface.jl")           # Einheitliche Schnittstelle zu verschiedenen QP-Solvern
include("filter_linesearch.jl")      # Filter-basierte Liniensuche und Globalisierung
include("sqp_method.jl")             # Haupt-SQP-Algorithmus und Koordination

# Testumgebung und Benchmarking
include("testproblems.jl")           # Sammlung von Testproblemen für Validation
include("ipopt_jump.jl")             # Integration von Ipopt für Vergleichstests
include("benchmarking.jl")           # Performance-Analyse und Benchmarking-Tools

#= ================================================================================
   VERWENDUNG DER SUBMODULE
   ================================================================================ =#

# Importiere alle Funktionalitäten der definierten Submodule
using .SettingsModule          # Konfigurationsmanagement
using .StatsModule            # Statistik- und Statusverwaltung
using .ResidualsModule        # Residuen-Berechnungen
using .ConvexifyModule        # Hessian-Konvexifizierung
using .QPInterface            # QP-Solver-Schnittstellen
using .FilterLineSearchSQP   # Filter-basierte Globalisierung
using .SQPMethod              # Haupt-SQP-Algorithmus
using .SQPTestProblems        # Testprobleme
using .IpoptADNLP             # Ipopt-Integration
using .Benchmarking           # Benchmarking-Funktionen

#= ================================================================================
   EXPORT-DEKLARATIONEN
   ================================================================================ =#

# Haupt-Solver-Funktionen - das sind die wichtigsten Funktionen für Endnutzer
export sqp_method                    # Haupt-SQP-Algorithmus
export solve_with_ipopt_adnlp        # Ipopt-basierte Referenzlösung

# Konfiguration und Einstellungen
export Settings                      # Hauptkonfigurationsstruktur

# Statistiken und Statusinformationen
export Stats                         # Solver-Statistiken
export SQPStatus                     # Status-Enumerationen
export kkt_point, max_iter, qp_failed, infeasible  # Spezifische Statuswerte

# KKT-Bedingungen und Konvergenztests
export get_primal_residual           # Berechnung primaler Residuen
export get_dual_residual             # Berechnung dualer Residuen
export compute_kkt_residuals         # Vollständige KKT-Residuen-Berechnung

# Hessian-Konvexifizierungsalgorithmen
export convexify_hessian!            # In-place Hessian-Konvexifizierung
export convexify_hessian             # Kopie-basierte Hessian-Konvexifizierung

# QP-Solver-Schnittstelle
export QPSolver                      # QP-Solver-Datenstruktur
export QPResult                      # QP-Solver-Ergebnisstruktur
export create_qp_solver              # Factory-Funktion für QP-Solver
export solve_qp                      # Einheitliche QP-Solver-Schnittstelle

# Testprobleme - vollständige Sammlung für Validation und Benchmarking
export create_P1, create_P2, create_P3, create_P4     # Grundlegende Testprobleme
export create_P5, create_P6, create_P7, create_P8     # Mittlere Komplexität
export create_P9, create_P10, create_P11, create_P12  # Erweiterte Testprobleme
export create_P13, create_P14, create_P15, create_P16 # Anspruchsvolle Testprobleme

# Benchmarking und Performance-Analyse
export performance_profile           # Dolan-Moré Performance-Profile
export run_benchmark                 # Automatisierte Benchmark-Ausführung
export benchmark_solver              # Einzelner Solver-Benchmark

# Filter-basierte Liniensuche und Globalisierung
export Filter                        # Filter-Datenstruktur
export FilterPoint                   # Punkt im Filter
export constraint_violation          # Berechnung der Constraint-Verletzung
export filter_line_search            # Filter-basierte Liniensuche

#= ================================================================================
   MODULENDE
   ================================================================================ =#

end # module SQPPackage