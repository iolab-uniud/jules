module TS 
    using Distributions
    using DataStructures
    export TabuSearch, accept_move, select_move, terminate, update_iteration!, update_best!, initialize_run!
    using ..LocalSearch
    using ..Types:  AbstractInput, AbstractSolution, AbstractMove, AbstractRunner
    using ...Jules

    #  min_k_tabu, max_k_tabu, PriorityQueue(), 0, max_idle_iteration)

    include("../parameters_helper.jl")
    @expose_parameters mutable struct TabuSearch{I,S,M,C}<:AbstractRunner{I,S,M,C}
        input::I
        best_solution::S = S(input)
        best_cost::C = typemax(C)
        iteration::Int64 = 0
        max_iteration::Int64 = typemax(Int64)
        current_move::M = M()
        current_move_delta_cost::C = typemax(C)
        "parameter"
        min_k_tabu::Int64
        "parameter"
        max_k_tabu::Int64
        tabu::PriorityQueue{M,Int64} = PriorityQueue{M,Int64}()
        idle_iteration::Int64 = 0 
        "parameter"
        max_idle_iteration::Int64
    end 

    function LocalSearch.initialize_run!(r::HillClimbing{I,S,M,C}, start_solution::S, start_cost::C) where {I,S,M,C}
        r.best_solution = deepcopy(start_solution)
        r.best_cost = start_cost
        r.iteration = 0
        r.idle_iteration = 0
       # r.tabu = PriorityQueue{M,Int64}()
    end

    # mutable struct TabuSearch{I,S,M,C}<:AbstractRunner{I,S,M,C}
    #     input::I
    #     best_solution::S
    #     best_cost::C
    #     iteration::Int64 
    #     max_iteration::Int64
    #     current_move::M
    #     current_move_delta_cost::C
    #     min_k_tabu::Int64
    #     max_k_tabu::Int64
    #     tabu::PriorityQueue{M,Int64}
    #     idle_iteration::Int64
    #     max_idle_iteration::Int64
    # end 

    # function TabuSearch{I,S,M,C}(input::I, min_k_tabu::Int64, max_k_tabu::Int64, max_idle_iteration::Int64) where {I,S,M,C}
    #     TabuSearch{I,S,M,C}(input, S(input), typemax(C), 0, typemax(Int64), M(), typemax(C), min_k_tabu, max_k_tabu, PriorityQueue(), 0, max_idle_iteration)
    # end

    function LocalSearch.accept_move(r::TabuSearch{I,S,M,C}, current_cost::C, delta_cost::C)::Bool where {I,S,M,C}
        @debug "Function: TS accept_move"
        return true 
    end

    function LocalSearch.select_move(r::TabuSearch{I,S,M,C}, current_solution::S, current_cost::C)::M where {I,S,M,C}
        @debug "Function: TS select_move"
        best_move_tabu::M = M()
        best_move_not_tabu::M = M()

        best_move_tabu_cost::C = typemax(C)
        best_move_not_tabu_cost::C = typemax(C)
        
        for move in Jules.neighborhood(M, r.input, current_solution)
            move_cost::C = Jules.compute_delta_cost(r.input, current_solution, current_cost, move)
            if (haskey(r.tabu,move)) && (move_cost <= best_move_tabu_cost)
                best_move_tabu = deepcopy(move)
                best_move_tabu_cost = move_cost
            elseif (!haskey(r.tabu,move)) && (move_cost <= best_move_not_tabu_cost)
                best_move_not_tabu = deepcopy(move)
                best_move_not_tabu_cost = move_cost
            end
        end 

        @debug "$best_move_not_tabu $best_move_tabu"

        if best_move_not_tabu_cost <= best_move_tabu_cost
            return best_move_not_tabu
        elseif (best_move_tabu_cost <= best_move_not_tabu_cost) && (current_cost + best_move_tabu_cost <= r.best_cost)
            delete!(r.tabu, best_move_tabu) # FIXME!!!!
            return best_move_tabu
        end
        return best_move_not_tabu
    end # select_move
    
    function LocalSearch.terminate(r::TabuSearch{I,S,M,C})::Bool where {I,S,M,C}
        @debug "Function: TS terminate"
        # TODO here 0 could actually be something parametrized?
        if (r.iteration <= r.max_iteration) && (r.idle_iteration <= r.max_idle_iteration)
            return false
        else 
            return true
        end
    end # terminate

    function LocalSearch.update_iteration!(r::TabuSearch{I,S,M,C}) where {I,S,M,C}
        @debug "Function: TS update_iteration!"
        r.iteration = r.iteration + 1
        @debug "Range $(r.min_k_tabu):$(r.max_k_tabu)"
        enqueue!(r.tabu, r.current_move, ((rand(r.min_k_tabu:r.max_k_tabu))+r.iteration))
        while(!isempty(r.tabu) && (first(r.tabu))[2] <= r.iteration)
            dequeue!(r.tabu)
        end 
        r.idle_iteration = r.idle_iteration + 1
    end

    function LocalSearch.update_best!(r::TabuSearch{I,S,M,C}, new_solution::S, new_cost::C) where {I,S,M,C}
        @debug "Function: TS update_best!"
        if new_cost < r.best_cost
            @debug "before best_solution_cost is $(r.best_cost)"
            r.best_solution = deepcopy(new_solution)
            r.best_cost = new_cost
            r.idle_iteration = -1
            @debug "after best_solution_cost is $(r.best_cost)"
        end
    end # update_best
end 