#==========================================================
    SteepestDescent

    Initial Solution: not specified
    Select Move: random
    Acceptable Move: non worsening
    Stop Search: no improving moves anymore

==========================================================#

module SD
    export SteepestDescent, accept_move, select_move, terminate
    using ..LocalSearch
    using ..Types: AbstractInput, AbstractSolution, AbstractMove, AbstractRunner
    using ..ProblemDefinition:random_move, neighborhood
    using ...Jules

    include("../parameters_helper.jl")
    @expose_parameters mutable struct SteepestDescent{I,S,M,C}<:AbstractRunner{I,S,M,C}
        input::I
        best_solution::S = S(input)
        best_cost::C = typemax(C)
        iteration::Int64 = 0
        current_move::M = M()
        current_move_delta_cost::C = typemax(C)
    end # SteepestDescent

    # function SteepestDescent{I,S,M,C}(input::I) where {I,S,M,C}
    #     SteepestDescent{I,S,M,C}(input, S(input), typemax(C), 0, M(), typemax(C))
    # end

    function LocalSearch.accept_move(r::SteepestDescent{I,S,M,C}, current_cost::C, delta_cost::C)::Bool where {I,S,M,C}
        @debug "Function: SD accept_move"
        # TODO: minore/maggiore/improves?
        if delta_cost < zero(C)
            return true
        end # if
        return false
    end # accept_move

    function LocalSearch.select_move(r::SteepestDescent{I,S,M,C}, current_solution::S, current_cost::C)::M where {I,S,M,C}
        @debug "Function: SD select_move"
        best_move_cost::C = typemax(C)
        best_move::M = random_move(M, r.input, current_solution)
        for current_move in Jules.neighborhood(M, r.input, current_solution)
            current_move_cost::C = Jules.compute_delta_cost(r.input, current_solution, r.best_cost, current_move)            
            if current_move_cost < best_move_cost
                best_move = deepcopy(current_move)
                best_move_cost = current_move_cost
            end
        end
        return best_move
    end # select_move

    function LocalSearch.terminate(r::SteepestDescent{I,S,M,C})::Bool where {I,S,M,C}
        @debug "Function: SD terminate"
        @debug "$(r.best_cost)/$(r.current_move_delta_cost)"
        if (r.iteration > 0 && r.current_move_delta_cost >= zero(C))
            return true
        else 
            return false
        end
    end # terminate
end