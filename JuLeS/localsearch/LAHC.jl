module LAHC
    export LateAcceptanceHC, accept_move, select_move, terminate, update_iteration!, initialize_run!, update_best!
    using ..LocalSearch
    using ..Types: AbstractInput, AbstractSolution, AbstractMove, AbstractRunner
    using ..ProblemDefinition:random_move

    using Parameters
    using DocStringExtensions
    using DataStructures

    include("../parameters_helper.jl")

    @expose_parameters mutable struct LateAcceptanceHC{I,S,M,C}<:AbstractRunner{I,S,M,C}
        input::I 
        best_solution::S = S(input)
        best_cost::C = typemax(C)
        prev_cost::C = typemax(C)
        current_move::M = M()
        current_move_delta_cost::C = typemax(C)
        iteration::Int64 = 0
        min_iteration::Int64 = 1000000 # According to Burke & Bykov, 2017
        idle_iteration::Int64 = 0
        "parameter"
        history_length::Int64
        #history::Queue{C} = Queue{C}()
        history::Vector{C} = Vector{C}(undef, 0)
    end

    function LocalSearch.initialize_run!(r::LateAcceptanceHC{I,S,M,C}, start_solution::S, start_cost::C) where {I,S,M,C}
        r.best_solution = deepcopy(start_solution)
        r.best_cost = start_cost
        r.prev_cost = start_cost
        r.iteration = 0
        r.idle_iteration = 0
        for _ in 1:r.history_length
            push!(r.history, start_cost)
        end
    end

    function LocalSearch.select_move(r::LateAcceptanceHC{I,S,M,C}, current_solution::S, current_cost::C)::M where {I,S,M,C}
        @debug "Function: LAHC select_move"
        return random_move(M, r.input, current_solution)
    end # select_move

    function LocalSearch.accept_move(r::LateAcceptanceHC{I,S,M,C}, current_cost::C, delta_cost::C)::Bool where {I,S,M,C}
        @info "Function: LAHC accept_move"
        current_front::UInt64 = (r.iteration % r.history_length) + 1
        if (delta_cost < zero(C)) ||  (current_cost + delta_cost) <= (r.history[current_front])
            return true
        end # if
        return false
    end # accept_move

    function LocalSearch.update_best!(r::LateAcceptanceHC{I,S,M,C}, new_solution::S, new_cost::C) where {I,S,M,C}
        @info "Function: LAHC update_best!"
        current_front::UInt64 = (r.iteration % r.history_length) + 1
        if new_cost < r.prev_cost
            r.idle_iteration = -1
        end
        if new_cost < r.history[current_front]
            r.history[current_front] = new_cost
        end
        if new_cost < r.best_cost
            r.best_solution = deepcopy(new_solution)
            r.best_cost = new_cost
        end
        r.prev_cost = new_cost
    end

    function LocalSearch.update_iteration!(r::LateAcceptanceHC{I,S,M,C}) where {I,S,M,C}
        @info "Function: LAHC update_iteration!"
        @debug "r.iteration is $(r.iteration) / r.idle_iteration is $(r.idle_iteration)"
        r.iteration = r.iteration + 1 
        r.idle_iteration = r.idle_iteration + 1
    end # update_iteration

    function LocalSearch.terminate(r::LateAcceptanceHC{I,S,M,C})::Bool where {I,S,M,C}
        @info "Function: LAHC terminate"
        if (r.idle_iteration > (0.02 * r.iteration)) && (r.iteration > r.min_iteration)
            return true
        else 
            return false
        end
    end # terminate
    
end