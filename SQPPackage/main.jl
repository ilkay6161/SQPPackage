# run_all_test_problems.jl

# Aktuelles Verzeichnis zum Ladepfad hinzufügen
push!(LOAD_PATH, "C:\\Users\\r_61\\Desktop\\SQPPackage")

# Laden des SQPPackage-Moduls
using SQPPackage
using Ipopt
using LinearAlgebra

# Liste der Testprobleme aus SQPTestProblems
using .SQPTestProblems
problems = [create_P1(), create_P2(), create_P3(), create_P4(), create_P5(), create_P6(),
            create_P7(), create_P8(), create_P9(), create_P10(), create_P11(), create_P12(),
            create_P13(), create_P14(), create_P15(), create_P16()]

# Funktion zum Lösen mit Ipopt
function solve_with_ipopt(nlp)
    result = Ipopt.solve(nlp)
    return result
end

# Funktion zum Lösen mit SQP
function solve_with_sqp(nlp, use_soc::Bool)
    settings = Settings(use_soc = use_soc, verbose = true)
    stats = sqp_method(nlp, settings)
    return stats
end

# Ausgabe der Ergebnisse
println("="^80)
println("Ergebnisse für Testprobleme P1 bis P16")
println("="^80)

for (i, nlp) in enumerate(problems)
    println("\nProblem P$i:")

    # Lösen mit Ipopt
    ipopt_result = solve_with_ipopt(nlp)
    ipopt_status = ipopt_result.status
    ipopt_obj = ipopt_result.objective
    ipopt_x = ipopt_result.solution
    ipopt_y = ipopt_result.multipliers
    ipopt_z_L = ipopt_result.multipliers_L
    ipopt_z_U = ipopt_result.multipliers_U
    println("Ipopt: Status = $ipopt_status, Zielfunktion = $ipopt_obj")

    # Lösen mit SQP ohne SOC
    sqp_no_soc = solve_with_sqp(nlp, false)
    sqp_no_soc_status = sqp_no_soc.sqp_status
    sqp_no_soc_obj = sqp_no_soc.obj_val
    sqp_no_soc_x = sqp_no_soc.x
    sqp_no_soc_y = sqp_no_soc.y
    sqp_no_soc_z_L = sqp_no_soc.z_L
    sqp_no_soc_z_U = sqp_no_soc.z_U
    println("SQP ohne SOC: Status = $sqp_no_soc_status, Zielfunktion = $sqp_no_soc_obj")
    
    # Norm-Differenzen für x, y, z_L, z_U
    if ipopt_status == :Optimal && sqp_no_soc_status == :kkt_point
        norm_diff_x = norm(ipopt_x - sqp_no_soc_x)
        norm_diff_y = norm(ipopt_y - sqp_no_soc_y)
        norm_diff_z_L = norm(ipopt_z_L - sqp_no_soc_z_L)
        norm_diff_z_U = norm(ipopt_z_U - sqp_no_soc_z_U)
        println("Norm-Differenz (x) Ipopt vs. SQP ohne SOC: $norm_diff_x")
        println("Norm-Differenz (y) Ipopt vs. SQP ohne SOC: $norm_diff_y")
        println("Norm-Differenz (z_L) Ipopt vs. SQP ohne SOC: $norm_diff_z_L")
        println("Norm-Differenz (z_U) Ipopt vs. SQP ohne SOC: $norm_diff_z_U")
    else
        println("Vergleich nicht möglich: Ipopt oder SQP ohne SOC nicht konvergiert")
    end

    # Lösen mit SQP mit SOC
    sqp_with_soc = solve_with_sqp(nlp, true)
    sqp_with_soc_status = sqp_with_soc.sqp_status
    sqp_with_soc_obj = sqp_with_soc.obj_val
    sqp_with_soc_x = sqp_with_soc.x
    sqp_with_soc_y = sqp_with_soc.y
    sqp_with_soc_z_L = sqp_with_soc.z_L
    sqp_with_soc_z_U = sqp_with_soc.z_U
    println("SQP mit SOC: Status = $sqp_with_soc_status, Zielfunktion = $sqp_with_soc_obj")
    
    # Norm-Differenzen für x, y, z_L, z_U
    if ipopt_status == :Optimal && sqp_with_soc_status == :kkt_point
        norm_diff_x = norm(ipopt_x - sqp_with_soc_x)
        norm_diff_y = norm(ipopt_y - sqp_with_soc_y)
        norm_diff_z_L = norm(ipopt_z_L - sqp_with_soc_z_L)
        norm_diff_z_U = norm(ipopt_z_U - sqp_with_soc_z_U)
        println("Norm-Differenz (x) Ipopt vs. SQP mit SOC: $norm_diff_x")
        println("Norm-Differenz (y) Ipopt vs. SQP mit SOC: $norm_diff_y")
        println("Norm-Differenz (z_L) Ipopt vs. SQP mit SOC: $norm_diff_z_L")
        println("Norm-Differenz (z_U) Ipopt vs. SQP mit SOC: $norm_diff_z_U")
    else
        println("Vergleich nicht möglich: Ipopt oder SQP mit SOC nicht konvergiert")
    end

    println("-"^40)
end