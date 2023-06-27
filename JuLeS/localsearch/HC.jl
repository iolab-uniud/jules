#==========================================================
    HillClimbing

    Initial Solution: not specified
    Select Move: random
    Acceptable Move: non worsening
    Stop Search: idle iteration

==========================================================#

module HC
    export HillClimbing, accept_move, select_move, terminate, update_iteration!, initialize_run!
    using ..LocalSearch
    using ..Types: AbstractInput, AbstractSolution, AbstractMove, AbstractRunner
    using ..ProblemDefinition:random_move

    using Parameters
    using DocStringExtensions

    include("../parameters_helper.jl")
    @expose_parameters mutable struct HillClimbing{I,S,M,C}<:AbstractRunner{I,S,M,C}
        input::I 
        best_solution::S = S(input)
        best_cost::C = typemax(C)
        iteration::Int64 = 0
        max_iteration::Int64 = typemax(Int64)
        current_move::M = M()
        current_move_delta_cost::C = typemax(C)
        idle_iteration::Int64 = 0
        "parameter"
        max_idle_iteration::Int64 
    end # HillClimbing

    function LocalSearch.initialize_run!(r::HillClimbing{I,S,M,C}, start_solution::S, start_cost::C) where {I,S,M,C}
        r.best_solution = deepcopy(start_solution)
        r.best_cost = start_cost
        r.iteration = 0
        r.idle_iteration = 0
    end


    # mutable struct HillClimbing{I,S,M,C}<:AbstractRunner{I,S,M,C}
    #     input::I
    #     best_solution::S
    #     best_cost::C
    #     iteration::Int64
    #     max_iteration::Int64
    #     current_move::M
    #     current_move_delta_cost::C
    #     idle_iteration::Int64
    #     max_idle_iteration::Int64
    # end # HillClimbing

    # function HillClimbing{I,S,M,C}(input::I, max_idle_iteration::Int64) where {I,S,M,C}
    #     HillClimbing{I,S,M,C}(input, S(input), typemax(C), 0, typemax(Int64), M(), typemax(C), 0, max_idle_iteration)
    # end

    function LocalSearch.accept_move(r::HillClimbing{I,S,M,C}, current_cost::C, delta_cost::C)::Bool where {I,S,M,C}
        @debug "Function: HC accept_move"
        # TODO: minore/maggiore/improves?
        if delta_cost <= zero(C)
            return true
        end # if
        return false
    end # accept_move

    function LocalSearch.select_move(r::HillClimbing{I,S,M,C}, current_solution::S, current_cost::C)::M where {I,S,M,C}
        @debug "Function: HC select_move"
        return random_move(M, r.input, current_solution)
    end # select_move

    function LocalSearch.terminate(r::HillClimbing{I,S,M,C})::Bool where {I,S,M,C}
        @debug "Function: HC terminate"
        if (r.iteration <= r.max_iteration) && (r.idle_iteration <= r.max_idle_iteration)
            return false
        else 
            return true
        end
    end # terminate

    function LocalSearch.update_iteration!(r::HillClimbing{I,S,M,C}) where {I,S,M,C}
        @debug "Function: update_iteration!"
        @debug "r.iteration is $(r.iteration) / r.idle_iteration is $(r.idle_iteration)"
        r.iteration = r.iteration + 1 
        if r.current_move_delta_cost < zero(C)
            r.idle_iteration = 0
        else
            r.idle_iteration = r.idle_iteration + 1
        end
    end # update_iteration
end