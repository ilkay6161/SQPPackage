"""
SQPTestProblems - Modul für alle SQP-Testprobleme P1 bis P16

Dieses Modul stellt eine Sammlung von Testproblemen für die SQP-Implementierung bereit.
Die Probleme umfassen verschiedene Arten von Optimierungsproblemen:
- Unrestringierte Probleme (P1, P9, P16)
- Probleme mit Gleichheitsnebenbedingungen (P2, P10, P11, P15)
- Probleme mit Ungleichheitsnebenbedingungen (P3, P6, P7, P12, P13)
- Probleme mit gemischten Nebenbedingungen (P4, P5, P8, P14)
- Probleme verschiedener Dimensionen (2D bis 6D)

Jedes Problem wird durch eine create_PX() Funktion erstellt, die ein ADNLPModel zurückgibt.
"""
module SQPTestProblems

using ADNLPModels
using LinearAlgebra

export create_P1, create_P2, create_P3, create_P4, create_P5, create_P6,
       create_P7, create_P8, create_P9, create_P10, create_P11, create_P12,
       create_P13, create_P14, create_P15, create_P16

# Problem P1: Unrestringiertes quadratisches Problem
# min f(x) = x₁² + 2x₂²
# Optimum: x* = [0, 0], f* = 0
f_P1(x) = x[1]^2 + 2x[2]^2
c_P1(x) = Float64[]
function create_P1()
    x0 = [1.0, 1.0]
    return ADNLPModel(f_P1, x0; c = c_P1)
end

# Problem P2: Quadratisches Problem mit linearen Gleichheitsnebenbedingungen
# min f(x) = x₁² + 2x₂²
# s.t. x₁ + 2x₂² - 10 = 0
#      2x₁ + x₂ - 9 = 0
f_P2(x) = x[1]^2 + 2x[2]^2
c_P2(x) = [x[1] + 2x[2]^2 - 10.0,
          2x[1] + x[2] - 9.0]
function create_P2()
    x0 = [1.2, 5.4]
    return ADNLPModel(f_P2, x0; 
        c = c_P2, 
        lcon = [0.0, 0.0],  # Beide Gleichheitsnebenbedingungen
        ucon = [0.0, 0.0]
    )
end

# Problem P3: Quartisches Problem mit linearer Nebenbedingung
# min f(x) = 2x₁⁴ + 4x₁² - x₁x₂ + 6x₂²
# s.t. 2x₁ - x₂ + 4 = 0
f_P3(x) = 2x[1]^4 + 4x[1]^2 - x[1]*x[2] + 6x[2]^2
c_P3(x) = [2x[1] - x[2] + 4.0]
function create_P3()
    x0 = [4.0, 4.0]
    return ADNLPModel(f_P3, x0; c = c_P3, lcon = [0.0], ucon = [0.0])
end

# Problem P4: Nichtlineares Problem mit Variablengrenzen
# min f(x) = x₁x₄(x₁ + x₂ + x₃) + x₃
# s.t. x₁² + x₂² + x₃² + x₄² = 40
#      x₁x₂x₃x₄ ≥ 25
#      1 ≤ xᵢ ≤ 5, i = 1,2,3,4
f_P4(x) = x[1]*x[4]*(x[1] + x[2] + x[3]) + x[3]
c_P4(x) = [x[1]^2 + x[2]^2 + x[3]^2 + x[4]^2 - 40.0,
          x[1] + x[2] + x[3] + x[4] - 25.0]
function create_P4()
    x0 = [3.0, 3.0, 3.0, 3.0]
    
    # Zielfunktion
    h(x) = x[1] * x[4] * (x[1] + x[2] + x[3])
    f(x) = h(x) + x[3]

    # Nebenbedingungen in Standardform
    c(x) = [
        sum(x.^2) - 40,          # x₁² + x₂² + x₃² + x₄² = 40
        25 - prod(x)             # x₁x₂x₃x₄ ≥ 25 → 25 - x₁x₂x₃x₄ ≤ 0   
    ]

    # Variable Grenzen
    lvar = [1.0, 1.0, 1.0, 1.0]     #  xᵢ ≥ 1
    uvar = [5.0, 5.0, 5.0, 5.0]     # xᵢ ≤ 5
    
    # Nebenbedingungen Grenzen 
    lcon = [0.0, -Inf]              
    ucon = [0.0, 0.0]               

    return ADNLPModel(f, x0, lvar, uvar, c, lcon, ucon)
end

# Problem P5: Exponentielles Problem mit nichtlinearen Nebenbedingungen
# min f(x) = exp(x₁)(4x₁² + 2x₂ + 4x₁x₂ + 2x₁ + 1)
# s.t. x₁ + x₂ - x₁x₂ ≥ 1.5
#      x₁x₂ ≥ -10
#      -5 ≤ xᵢ ≤ 3, i = 1,2
f_P5(x) = exp(x[1]) * (4x[1]^2 + 2x[2] + 4x[1]*x[2] + 2x[1] + 1)
c_P5(x) = [x[1] + x[2] - x[1]*x[2] - 3/2,
          x[1]*x[2] + 10.0]
function create_P5()
    x0 = [2.0, -4.0]
    f(x) = exp(x[1]) * (4*x[1]^2 + 2*x[2] + 4*x[1]*x[2] + 2*x[1] + 1)

    c(x) = [
        3/2-(x[1] + x[2] - x[1]*x[2]),  # ≥ 1.5
        -10-x[1]*x[2]                 # ≥ -10
    ]

    # Variable Grenzen
    lvar = [-5.0, -5.0]    # -5 ≤ x₁ ≤ 3, -5 ≤ x₂ ≤ 3
    uvar = [3.0, 3.0]
    
    # Constraint Grenzen (beide constraints ≤ 0)
    lcon = [-Inf, -Inf]     #  c(x) ≤ 0
    ucon = [0.0, 0.0]
    
    return ADNLPModel(f, x0, lvar, uvar, c, lcon, ucon)
end

# Problem P6: Exponentielles Problem mit Kreisconstraint
# min f(x) = exp((x₁ - 2)²) + (x₂ - 2)²
# s.t. x₁² + x₂² ≤ 9
#      5 ≤ xᵢ ≤ 10, i = 1,2
f_P6(x) = exp((x[1] - 2)^2) + (x[2] - 2)^2
c_P6(x) = [x[1]^2 + x[2]^2 - 9.0]
function create_P6()
    x0 = [7.0, 7.0]
    return ADNLPModel(f_P6, x0; c = c_P6, lcon = [-Inf], ucon = [0.0],
                      lvar = [5.0, 5.0], uvar = [10.0, 10.0])
end

# Problem P7: Konkaves Problem mit nichtlinearer Ungleichung
# min f(x) = -(x₁² + x₂²)
# s.t. -x₁ + x₂² ≥ 0
#      0 ≤ xᵢ ≤ 10, i = 1,2
f_P7(x) = -(x[1]^2 + x[2]^2)
c_P7(x) = [-x[1] + x[2]^2]
function create_P7()
    x0 = [0.1, 0.1]
    return ADNLPModel(f_P7, x0; c = c_P7, lcon = [0.0], ucon = [Inf],
                      lvar = [0.0, 0.0], uvar = [10.0, 10.0])
end

# Problem P8: 3D-Problem mit vielen gemischten Nebenbedingungen
# min f(x) = (x₁-3)² + (x₂-2)² + (x₃-1)²
# s.t. x₁ + x₂ + x₃ = 6
#      x₁² = x₂
#      x₃² = x₁x₂
#      -1 ≤ x₁ - 2x₂ + x₃ ≤ 2
#      x₁² + x₂² + x₃² ≤ 10
#      x₁x₃ - x₂ + 1 ≥ 0
f_P8(x) = (x[1]-3)^2 + (x[2]-2)^2 + (x[3]-1)^2
c_P8(x) = [x[1] + x[2] + x[3] - 6.0,
          x[1]^2 - x[2],
          x[3]^2 - x[1]*x[2],
          x[1] - 2x[2] + x[3],
          x[1]^2 + x[2]^2 + x[3]^2 - 10.0,
          x[1]*x[3] - x[2] + 1.0]
function create_P8()
    x0 = [0.0, 0.0, 0.0]
    return ADNLPModel(f_P8, x0; c = c_P8,
                      lcon = [0.0, 0.0, 0.0, -1.0, -Inf, 0.0],
                      ucon = [0.0, 0.0, 0.0, 2.0, 0.0, Inf],
                      lvar = [-10.0, -10.0, -10.0], uvar = [10.0, 10.0, 10.0])
end

# Problem P9: 1D unrestringiertes Problem (numerisch interessant)
# min f(x) = 0.05x² + log(cosh(x))
f_P9(x) = 0.05*x[1]^2 + log(cosh(x[1]))
c_P9(x) = Float64[]
function create_P9()
    x0 = [10.0]
    return ADNLPModel(f_P9, x0)
end

# Problem P10: Problem auf dem Einheitskreis
# min f(x) = 2(x₁² + x₂² - 1) - x₁
# s.t. x₁² + x₂² = 1
f_P10(x) = 2*(x[1]^2 + x[2]^2 - 1) - x[1]
c_P10(x) = [x[1]^2 + x[2]^2 - 1.0]
function create_P10()
    x0 = [cos(0.1*pi), sin(0.1*pi)]
    return ADNLPModel(f_P10, x0; c = c_P10, lcon = [0.0], ucon = [0.0],
                      lvar = [-10.0, -10.0], uvar = [10.0, 10.0])
end

# Problem P11: 4D-Problem mit kubischen Termen
# min f(x) = -x₁
# s.t. x₂ - x₁³ - x₃² = 0
#      x₁² - x₂ - x₄² = 0
function create_P11()
    f(x) = -x[1]
    c(x) = [x[2] - x[1]^3 - x[3]^2,
           x[1]^2 - x[2] - x[4]^2]
    x0 = [0.5, 0.5, 0.5, 0.5]
    return ADNLPModel(f, x0; c = c, lcon = [0.0, 0.0], ucon = [0.0, 0.0])
end

# Problem P12: Problem mit gemischten linearen und nichtlinearen Constraints
# min f(x) = (x₁ - 2)² + (x₂ - 1)²
# s.t. x₁ - 2x₂ + 1 = 0
#      -0.25x₁² - x₂² + 1 ≥ 0
function create_P12()
    f(x) = (x[1] - 2)^2 + (x[2] - 1)^2
    c(x) = [x[1] - 2x[2] + 1,
           -0.25*x[1]^2 - x[2]^2 + 1]
    x0 = [2.0, 0.0]
    return ADNLPModel(f, x0; c = c, lcon = [0.0, 0.0], ucon = [0.0, Inf])
end

# Problem P13: Rosenbrock-ähnliches Problem mit Constraints
# min f(x) = 100(x₂ - x₁²)² + (1 - x₁)²
# s.t. x₁ - x₂² ≥ 0
#      x₁² + x₂ ≥ 0
#      -2 ≤ x₁ ≤ 0.5, -∞ ≤ x₂ ≤ 1
function create_P13()
    f(x) = 100*(x[2] - x[1]^2)^2 + (1 - x[1])^2
    c(x) = [x[1] - x[2]^2,
           x[1]^2 + x[2]]
    x0 = [-1.0, 1.0]
    return ADNLPModel(f, x0; c = c, lcon = [0.0, 0.0], ucon = [Inf, Inf],
                      lvar = [-2.0, -Inf], uvar = [0.5, 1.0])
end

# Problem P14: 6D-Problem mit exponentiellen Termen
# min f(x) = x₁ + 2x₂ + 4x₅ + exp(x₁x₄)
# s.t. x₁ + 2x₂ + 5x₅ = 6
#      x₁ + x₂ + x₃ = 3
#      x₄ + x₅ + x₆ = 2
#      x₁ + x₄ = 1
#      x₂ + x₅ = 2
#      x₃ + x₆ = 2
#      0 ≤ x₁ ≤ 1, xᵢ ≥ 0, i = 2,...,6
function create_P14()
    f(x) = x[1] + 2x[2] + 4x[5] + exp(x[1]*x[4])
    c(x) = [x[1] + 2x[2] + 5x[5] - 6,
           x[1] + x[2] + x[3] - 3,
           x[4] + x[5] + x[6] - 2,
           x[1] + x[4] - 1,
           x[2] + x[5] - 2,
           x[3] + x[6] - 2]
    x0 = ones(6)
    return ADNLPModel(f, x0;
        c = c,
        lcon = zeros(6),
        ucon = zeros(6),
        lvar = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        uvar = [1.0, Inf, Inf, Inf, Inf, Inf]
    )
end

# Problem P15: 2D-Problem mit nichtlinearer Gleichheit
# min f(x) = 0.5((x₁ - 1)² + x₂²)
# s.t. -x₁ + 2x₂² = 0
function create_P15()
    f(x) = 0.5*((x[1] - 1)^2 + x[2]^2)
    c(x) = [-x[1] + 2x[2]^2]
    x0 = [0.5, 0.5]
    return ADNLPModel(f, x0; c = c, lcon = [0.0], ucon = [0.0])
end

# Problem P16: 2D unrestringiertes Problem mit Box-Constraints
# min f(x) = 0.5((x₁ - 2)⁴ + (x₂ - 2)⁴)
# s.t. -1 ≤ xᵢ ≤ 1, i = 1,2
function create_P16()
    f(x) = 0.5*((x[1] - 2)^4 + (x[2] - 2)^4)
    x0 = [0.0, 0.0]
    return ADNLPModel(f, x0;
        lvar = [-1.0, -1.0],
        uvar = [1.0, 1.0])
end

end # module SQPTestProblems

