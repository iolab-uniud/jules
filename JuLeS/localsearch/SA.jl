module SA
    using Distributions
    export SimulatedAnnealing, accept_move, select_move, terminate, update_iteration!, initialize_run!
    using ..LocalSearch
    using ..Types:  AbstractInput, AbstractSolution, AbstractMove, AbstractRunner
    using ..ProblemDefinition:random_move

    include("../parameters_helper.jl")
    @expose_parameters mutable struct SimulatedAnnealing{I,S,M,C}<:AbstractRunner{I,S,M,C}
        input::I
        best_solution::S = S(input)
        best_cost::C = typemax(C)
        "parameter"
        temperature::Float64
        iteration::Int64 = 0# number of iteration in total
        current_iteration::Int64 = 0# current itaration for the given temperature
        "parameter"
        iteration_per_temperature::Int64 # max number of iteration per temperature
        "parameter"
        cooling_rate::Float64 # alpha
        "parameter"
        final_temperature::Float64 
        current_move::M = M()
        current_move_delta_cost::C = typemax(C)
    end # SimulatedAnnealing

    function LocalSearch.initialize_run!(r::HillClimbing{I,S,M,C}, start_solution::S, start_cost::C) where {I,S,M,C}
        r.best_solution = deepcopy(start_solution)
        r.best_cost = start_cost
        r.iteration = 0
        r.current_iteration = 0
       # r.tabu = PriorityQueue{M,Int64}()
    end

    
    # mutable struct SimulatedAnnealing{I,S,M,C}<:AbstractRunner{I,S,M,C}
    #     input::I
    #     best_solution::S
    #     best_cost::C
    #     temperature::Float64
    #     iteration::Int64 # number of iteration in total
    #     current_iteration::Int64 # current itaration for the given temperature
    #     iteration_per_temperature::Int64 # max number of iteration per temperature
    #     cooling_rate::Float64 # alpha
    #     final_temperature::Float64 
    #     current_move::M
    #     current_move_delta_cost::C
    # end # SimulatedAnnealing

    # function SimulatedAnnealing{I,S,M,C}(input::I, temperature::Float64, iteration_per_temperature::Int64, cooling_rate::Float64, final_temperature::Float64) where {I,S,M,C}
    #     SimulatedAnnealing{I,S,M,C}(input, S(input), typemax(C), temperature, 0, 0, iteration_per_temperature, cooling_rate, final_temperature, M(), typemax(C))
    # end

    @inline function LocalSearch.accept_move(r::SimulatedAnnealing{I,S,M,C}, current_cost::C, delta_cost::C)::Bool where {I,S,M,C}
        @debug "Function: SA accept_move"
        # TODO: minore/maggiore/improves?
        if delta_cost <= 0
            @debug "In SA accept_move, improving move"
            return true
        end 
        # try for conditional acceptance
        # random::Float64 = rand(Uniform(0,1),1)
        if  (rand(Uniform(0.0, 1.0)) < exp(-delta_cost / r.temperature))
            @debug "In SA accept_move, accepting non improving move based on conditional"
            return true
        end 
        return false
    end # accept_move

    @inline function LocalSearch.select_move(r::SimulatedAnnealing{I,S,M,C}, current_solution::S, current_cost::C)::M where {I,S,M,C}
        @debug "Function: SA select_move"
        return random_move(M, r.input, current_solution)
    end # select_move
    
    @inline function LocalSearch.terminate(r::SimulatedAnnealing{I,S,M,C})::Bool where {I,S,M,C}
        @debug "Function: SA terminate"
        if (r.temperature <= r.final_temperature)
            return true
        else
            return false
        end
    end # terminate

    @inline function LocalSearch.update_iteration!(r::SimulatedAnnealing{I,S,M,C}) where {I,S,M,C}
        @debug "Function: SA update_iteration!"
        @debug "r.iteration is $(r.current_iteration)"
        if r.current_iteration < r.iteration_per_temperature # frequent case
            r.current_iteration = r.current_iteration + 1
        else # at this point it is r.iteration == r.iteration_per_temperature
            @info "Changing temperature"
            @debug "r.iteration ($(r.current_iteration)) == r.iteration_per_temperature ($(r.iteration_per_temperature))"
            r.current_iteration = 0
            @debug "r.temperature is $(r.temperature)"
            r.temperature = r.temperature * r.cooling_rate
            @debug "r.temperature is $(r.temperature)"
        end
        @debug "r.iteration is $(r.current_iteration)"
        r.iteration = r.iteration + 1
    end # update_iteration

end