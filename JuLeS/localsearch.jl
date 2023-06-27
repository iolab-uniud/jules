module LocalSearch
    export HillClimbing, SimulatedAnnealing, SteepestDescent, TabuSearch,LateAcceptanceHC,
        accept_move, select_move, terminate, update_best!, update_iteration!, update_current_move!, delta_cost,
        EmptyNeighborhood, @composite_neighborhood, HasDeltaCost, initialize_run!, final_solution
    
    using SimpleTraits

    using ..Types
    using ..ProblemDefinition

    function accept_move() end
    function select_move() end
    function terminate() end

    @inline function initialize_run!(r::AbstractRunner{I,S,M,C}, start_solution::S, start_cost::C) where {I,S,M,C}
        r.best_solution = deepcopy(start_solution)
        r.best_cost = start_cost
        r.iteration = 0
    end

    @inline function final_solution(r::AbstractRunner{I,S,M,C}) where {I,S,M,C}
        return r.best_solution, r.best_cost
    end 

    @inline function update_current_move!(r::AbstractRunner{I,S,M,C}, move::M, delta::C) where {I,S,M,C}
        @debug "Function: update_current_move!"
        r.current_move = deepcopy(move)
        r.current_move_delta_cost = delta
    end 

    function update_best!(r::AbstractRunner{I,S,M,C}, new_solution::S, new_cost::C) where {I,S,M,C}
        @debug "Function: update_best!"
        if new_cost <= r.best_cost
            @debug "before best_solution is $(r.best_solution) $(r.best_cost)"
            r.best_solution = deepcopy(new_solution)
            r.best_cost = new_cost
            @debug "after best_solution is $(r.best_solution) $(r.best_cost)"
        end
    end # update_best

    @inline function update_iteration!(r::AbstractRunner{I,S,M,C}) where {I,S,M,C}
        @debug "Function: update_iteration!"        
        @debug "r.iteration is $(r.iteration)"
        r.iteration = r.iteration + 1 
    end # update_iteration

    @inline function lower_bound_reached(r::AbstractRunner{I,S,M,C}) where {I,S,M,C}
        @debug "Function: lower_bound_reached"
        return r.best_cost == zero(C)
    end

    function delta_cost() end

    include("traits.jl")

    @traitfn compute_delta_cost(input::I, current_solution::S, current_cost::C, move::M) where {I,S,M,C; HasDeltaCost{I,S,M}} = delta_cost(input, current_solution, move)

    @traitfn function compute_delta_cost(input::I, current_solution::S, current_cost::C, move::M) where {I,S,M,C; !HasDeltaCost{I,S,M}} 
        @debug "Using simulated delta cost"
        new_sol::S = deepcopy(current_solution)
        make_move!(input, new_sol, move)
        new_cost::C = cost_function(input, new_sol)
        return new_cost - current_cost
    end # compute_delta_cost

    struct EmptyNeighborhood <: Exception
    end

    include("composite.jl") # composite moves

    include("localsearch/HC.jl") # Hill Climbing
    import .HC: HillClimbing 

    include("localsearch/SA.jl") # Simulated Annealing
    import .SA: SimulatedAnnealing 
    
    include("localsearch/SD.jl") # Steepes tDescent
    import .SD: SteepestDescent 

    include("localsearch/TS.jl") # TabuSearch
    import .TS: TabuSearch

    include("localsearch/LAHC.jl") # Late Acceptance Hill Clinbing 
    import .LAHC: LateAcceptanceHC
end 