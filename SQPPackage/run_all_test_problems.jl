module SQPTestRunner

# Korrigierte Pfade
include("problem_types.jl")
include("settings.jl")
include("stats.jl")
include("residuals.jl")
include("convexify.jl")
include("qp_interface.jl")
include("filter_linesearch.jl")
include("sqp_method.jl")         
include("sqp_test_problems.jl")
include("ipopt_jump.jl")

using ADNLPModels
using .SQPTestProblems
using .SQPMethod: sqp_method, create_qp_solver
using .SettingsModule
#using .StatsModule
using .StatsModule: kkt_point
using .IpoptADNLP
using Printf
using LinearAlgebra
using .FilterLineSearchSQP

export run_comprehensive_tests

function run_comprehensive_tests(; export_csv=false, csv_path="sqp_test_results.csv")
    println("="^80)
    println("SQP Method Comprehensive Test Suite")
    println("="^80)

    problems = [
        ("P1", create_P1()), ("P2", create_P2()), ("P3", create_P3()), ("P4", create_P4()),
        ("P5", create_P5()), ("P6", create_P6()), ("P7", create_P7()), ("P8", create_P8()),
        ("P9", create_P9()), ("P10", create_P10()), ("P11", create_P11()), ("P12", create_P12()),
        ("P13", create_P13()), ("P14", create_P14()), ("P15", create_P15()), ("P16", create_P16()),
    ]

    ipopt_success = 0
    sqp_no_glob_success = 0
    sqp_glob_success = 0

    results = []

    for (name, prob) in problems
        println("\n" * "="^50)
        println("Testing Problem: $name")
        println("="^50)

        result = Dict{String, Any}("name" => name)

        ## Test Ipopt
        try

            x_ipopt, y_ipopt, zL_ipopt, zU_ipopt, status_ipopt = solve_with_ipopt_adnlp(prob)
            z_ipopt = zU_ipopt - zL_ipopt

            if status_ipopt in (:first_order, :acceptable)
                ipopt_success += 1
                result["ipopt_success"] = true
                result["ipopt_x"] = x_ipopt
                result["ipopt_y"] = y_ipopt
                result["ipopt_z"] = z_ipopt
                result["ipopt_status"] = status_ipopt

                println("✓ Ipopt: SUCCESS")
                println("  Solution: ", round.(x_ipopt, digits=6))
            else
                result["ipopt_success"] = false
                result["ipopt_status"] = status_ipopt
                println("✗ Ipopt: FAILED (Status: $status_ipopt)")
            end

        catch e
            result["ipopt_success"] = false
            result["ipopt_error"] = string(e)
            println("✗ Ipopt: ERROR - $e")
        end

        ## Test SQP ohne Globalisierung
        try

                    
            settings = Settings(
                max_iter=100, 
                tol=1e-6, 
                use_globalization=false, 
                verbose=false,
                qp_solver=:osqp,
                # Füge Standardwert hinzu:
                soc_improvement_threshold=0.5
            )
            stats = SQPMethod.sqp_method(prob, settings)
            #stats = sqp_method(prob, settings)
            #settings = Settings(max_iter=100, tol=1e-6, use_globalization=false, verbose=false)
            #stats = SQPMethod.sqp_method(prob, settings)

            if stats.sqp_status == kkt_point
                sqp_no_glob_success += 1
                result["sqp_no_glob_success"] = true
                result["sqp_no_glob_x"] = stats.x
                result["sqp_no_glob_y"] = stats.y
                result["sqp_no_glob_z"] = stats.z
                result["sqp_no_glob_iter"] = stats.iter

                println("✓ SQP (no globalization): SUCCESS")
                println("  Solution: ", round.(stats.x, digits=6))
            else
                result["sqp_no_glob_success"] = false
                result["sqp_no_glob_status"] = stats.sqp_status
                println("✗ SQP (no globalization): FAILED (Status: $(stats.sqp_status))")
            end
        catch e
            result["sqp_no_glob_success"] = false
            result["sqp_no_glob_error"] = string(e)
            println("✗ SQP (no globalization): ERROR - $e")
        end

        ## Test SQP mit Globalisierung
        try
            settings = Settings(max_iter=100, tol=1e-6, use_globalization=true, verbose=false)
            stats = SQPMethod.sqp_method(prob, settings)

            if stats.sqp_status == kkt_point
                sqp_glob_success += 1
                result["sqp_glob_success"] = true
                result["sqp_glob_x"] = stats.x
                result["sqp_glob_y"] = stats.y
                result["sqp_glob_z"] = stats.z
                result["sqp_glob_iter"] = stats.iter

                println("✓ SQP (with globalization): SUCCESS")
                println("  Solution: ", round.(stats.x, digits=6))
            else
                result["sqp_glob_success"] = false
                result["sqp_glob_status"] = stats.sqp_status
                println("✗ SQP (with globalization): FAILED (Status: $(stats.sqp_status))")
            end
        catch e
            result["sqp_glob_success"] = false
            result["sqp_glob_error"] = string(e)
            println("✗ SQP (with globalization): ERROR - $e")
        end

        ## Vergleich
        if get(result, "ipopt_success", false) && get(result, "sqp_glob_success", false)
            x_diff = norm(result["ipopt_x"] - result["sqp_glob_x"])
            @printf("\n  ||x_ipopt - x_sqp|| = %.3e\n", x_diff)
        end

        push!(results, result)
    end

    ## Zusammenfassung
    println("\n" * "="^80)
    println("FINAL SUMMARY")
    println("="^80)
    println("Total problems tested: ", length(problems))
    @printf("  Ipopt: %d/%d (%.1f%%)\n", ipopt_success, length(problems), 100*ipopt_success/length(problems))
    @printf("  SQP (no globalization): %d/%d (%.1f%%)\n", sqp_no_glob_success, length(problems), 100*sqp_no_glob_success/length(problems))
    @printf("  SQP (with globalization): %d/%d (%.1f%%)\n", sqp_glob_success, length(problems), 100*sqp_glob_success/length(problems))
    println("="^80)

    return results
end

if abspath(PROGRAM_FILE) == @__FILE__
    using .SQPTestRunner
    println("\nStarting comprehensive tests...")
    results = run_comprehensive_tests(export_csv=true, csv_path="sqp_results.csv")
    println("\nTests completed! Results saved to 'sqp_results.csv'")
end

end # module