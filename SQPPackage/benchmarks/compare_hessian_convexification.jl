#!/usr/bin/env julia

"""
Hessian Convexification Methods Comparison Benchmark
"""

# Add the parent directory to load path
push!(LOAD_PATH, joinpath(@__DIR__, ".."))

using SQPPackage
using SQPPackage.Benchmarking
using Plots
using Printf
using OptimizationProblems

println("="^60)
println("Hessian Convexification Comparison Benchmark")
println("="^60)

function run_hessian_convexification_comparison()
    # Test both problem sets
    problem_sets = [
        ("TestProblems", true),
        ("OptimizationProblems", false)
    ]

    # Hessian convexification strategies to compare
    convex_strategies = [:none, :lm, :project, :mirror, :gershgorin]

    for (set_name, use_test_problems) in problem_sets
        println("\nTesting on $set_name...")

        # Get problems based on set type
        if use_test_problems
            test_problems = [:P1, :P2, :P3, :P4, :P5, :P6, :P7, :P8]
        else
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
        n_strategies = length(convex_strategies)
        times = Matrix{Float64}(undef, n_problems, n_strategies)

        println("Testing $(n_problems) problems with $(n_strategies) convexification strategies...")

        for (i, problem_name) in enumerate(test_problems)
            print("Problem $problem_name: ")

            # Create problem
            try
                if use_test_problems
                    nlp = eval(Symbol("create_", problem_name))()
                else
                    nlp = getfield(OptimizationProblems.ADNLPProblems, problem_name)()
                end

                for (j, strategy) in enumerate(convex_strategies)
                    try
                        # Configure settings with specific convexification strategy
                        settings = Settings(
                            hessian_convexification=strategy,
                            verbose=false,
                            max_iter=100,
                            tol=1e-6,
                            qp_solver=:osqp,
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

                        print("$(strategy): $(round(elapsed, digits=3))s ")
                    catch e
                        times[i, j] = Inf
                        print("$(strategy): FAIL ")
                    end
                end
                println()
            catch e
                println("ERROR creating problem")
                times[i, :] .= Inf
            end
        end

        # Create performance profile
        strategy_names = string.(convex_strategies)
        plt = performance_profile(times, strategy_names, 
                                title="Hessian Convexification Comparison - $set_name",
                                logscale=true)

        # Create results directory if it doesn't exist
        results_dir = joinpath(@__DIR__, "..", "results")
        if !isdir(results_dir)
            mkpath(results_dir)
        end

        # Save plot
        filename = joinpath(results_dir, "hessian_convexification_comparison_$(lowercase(set_name)).pdf")
        savefig(plt, filename)
        println("Results saved to: $filename")

        # Print summary statistics
        println("\nSummary for $set_name:")
        for (j, strategy) in enumerate(convex_strategies)
            solved = sum(isfinite.(times[:, j]))
            total = size(times, 1)
            if solved > 0
                avg_time = mean(times[isfinite.(times[:, j]), j])
                println("  $strategy: $solved/$total problems solved, avg time: $(round(avg_time, digits=3))s")
            else
                println("  $strategy: $solved/$total problems solved")
            end
        end
    end
end

# Run the comparison
run_hessian_convexification_comparison()

println("\n" * "="^60)
println("Hessian Convexification Comparison Completed!")
println("="^60)