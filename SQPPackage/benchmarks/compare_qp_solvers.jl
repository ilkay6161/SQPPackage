#!/usr/bin/env julia

"""
Benchmark script to compare different QP solvers in the SQP method.
Compares OSQP, Clarabel, and Ipopt QP solvers.
"""

# Add the parent directory to load path
push!(LOAD_PATH, joinpath(@__DIR__, ".."))

using SQPPackage
using Plots
using Printf
using OptimizationProblems

println("="^60)
println("QP-Solver Comparison Benchmark")
println("="^60)

function run_qp_solver_comparison()
    # Test both problem sets
    problem_sets = [
        ("TestProblems", true),
        ("OptimizationProblems", false)
    ]

    # QP solvers to compare
    qp_solvers = [:osqp, :clarabel]  # Add :ipopt if available

    for (set_name, use_test_problems) in problem_sets
        println("\nTesting on $set_name...")

        # Get problems based on set type
        if use_test_problems
            test_problems = [:P1, :P2, :P3, :P4, :P5, :P6, :P7, :P8]
        else
            # Filter OptimizationProblems for smaller problems (3-50 variables with constraints)
            try
                meta = OptimizationProblems.meta
                filtered = meta[(3 .<= meta.nvar .<= 50) .& (meta.ncon .> 0), [:name]]
                test_problems = Symbol.(filtered.name[1:min(20, length(filtered.name))])
            catch
                println("OptimizationProblems not available or error occurred, skipping...")
                continue
            end
        end

        # Storage for timing results
        n_problems = length(test_problems)
        n_solvers = length(qp_solvers)
        times = Matrix{Float64}(undef, n_problems, n_solvers)

        println("Testing $(n_problems) problems with $(n_solvers) QP solvers...")

        for (i, problem_name) in enumerate(test_problems)
            print("Problem $problem_name: ")

            # Create problem
            try
                if use_test_problems
                    nlp = eval(Symbol("create_", problem_name))()
                else
                    nlp = getfield(OptimizationProblems.ADNLPProblems, problem_name)()
                end

                for (j, qp_solver) in enumerate(qp_solvers)
                    try
                        # Configure settings with specific QP solver
                        settings = Settings(
                            qp_solver=qp_solver,
                            verbose=false,
                            max_iter=100,
                            tol=1e-6,
                            use_globalization=true
                        )

                        # Time the solver
                        start_time = time()
                        stats = sqp_method(nlp, settings)
                        elapsed = time() - start_time

                        # Store time if successful, otherwise infinity
                        if stats.sqp_status == kkt_point
                            times[i, j] = elapsed
                        else
                            times[i, j] = Inf
                        end

                        print("$(qp_solver): $(round(elapsed, digits=3))s ")
                    catch e
                        times[i, j] = Inf
                        print("$(qp_solver): FAIL ")
                    end
                end
                println()
            catch e
                println("ERROR creating problem")
                times[i, :] .= Inf
            end
        end

        # Create performance profile
        solver_names = string.(qp_solvers)
        plt = performance_profile(times, solver_names, 
                                title="QP Solver Comparison - $set_name",
                                logscale=true)

        # Create results directory if it doesn't exist
        results_dir = joinpath(@__DIR__, "..", "results")
        if !isdir(results_dir)
            mkpath(results_dir)
        end

        # Save plot
        filename = joinpath(results_dir, "qp_solver_comparison_$(lowercase(set_name)).pdf")
        savefig(plt, filename)
        println("Results saved to: $filename")

        # Print summary statistics
        println("\nSummary for $set_name:")
        for (j, solver) in enumerate(qp_solvers)
            solved = sum(isfinite.(times[:, j]))
            total = size(times, 1)
            avg_time = mean(times[isfinite.(times[:, j]), j])
            println("  $solver: $solved/$total problems solved, avg time: $(round(avg_time, digits=3))s")
        end
    end
end

# Run the comparison
run_qp_solver_comparison()

println("\n" * "="^60)
println("QP Solver Comparison Completed!")
println("="^60)