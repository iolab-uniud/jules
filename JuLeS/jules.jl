module Jules
    export AbstractInput, AbstractSolution, AbstractMove, AbstractRunner,
        Problem, 
        HillClimbing, SimulatedAnnealing, SteepestDescent, TabuSearch,LateAcceptanceHC,
        run!, EmptyNeighborhood, empty_move, @composite_neighborhood, delta_cost, HasDeltaCost

    include("types.jl")
    using .Types  
    
    include("utils.jl")
    using .Utils

    import Random

    input_type(::AbstractRunner{I,S,M,C}) where {I,S,M,C} = I
    solution_type(::AbstractRunner{I,S,M,C}) where {I,S,M,C} = S
    move_type(::AbstractRunner{I,S,M,C}) where {I,S,M,C} = M
    cost_type(::AbstractRunner{I,S,M,C}) where {I,S,M,C} = C

    struct Problem{I,S,M,C} 
        input::I
    end

    function run!(r::AbstractRunner{I,S,M,C})::Tuple{S,C} where {I,S,M,C}      
        @debug "into run function"
        @debug "about to call initial_state"
        current_solution::S = initial_state(r.input)
        current_cost::C = cost_function(r.input, current_solution)
        @debug "Starting cost $(current_cost)"
        initialize_run!(r, current_solution, current_cost)
        @debug "about to start while run with runner state $r"
        while (!terminate(r) && !lower_bound_reached(r))
            move::M = select_move(r, current_solution, current_cost)
            if (empty_move(move))
                break
            end
            @debug "move is $move"
            delta_cost::C = compute_delta_cost(r.input, current_solution, current_cost, move)                        
            update_current_move!(r, move, delta_cost)
            if accept_move(r, current_cost, delta_cost)               
                make_move!(r.input, current_solution, move)
                current_cost = current_cost + delta_cost
                @debug "Found a better solution $current_solution thanks to move: $move with delta cost $delta_cost"                     
                update_best!(r, current_solution, current_cost)          
            end 
            update_iteration!(r)
        end # while
        @debug "About to return function   run result"
        @info "Ended run after $(r.iteration) iterations"
        @info "Final cost is $(r.best_cost)"
        if r.best_cost != cost_function(r.input, r.best_solution)
            @error "Cost mismatch: $(r.best_cost) / $(cost_function(r.input, r.best_solution))"
        end
        return final_solution(r)
    end # run

    include("problemdefinition.jl")
    import .ProblemDefinition: initial_state, cost_function, random_move, make_move!, neighborhood, empty_move

    include("localsearch.jl")
    using .LocalSearch: HillClimbing, SimulatedAnnealing, SteepestDescent, TabuSearch,LateAcceptanceHC,
        accept_move,select_move,terminate,update_best!,update_iteration!, compute_delta_cost, update_current_move!, lower_bound_reached, 
        EmptyNeighborhood, @composite_neighborhood, delta_cost, HasDeltaCost, initialize_run!, final_solution
end