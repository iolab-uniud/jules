module ProblemDefinition
    export initial_state, cost_function, random_move, make_move!, neighborhood
    
    using ..Types: AbstractInput, AbstractSolution, AbstractMove, AbstractRunner

    initial_state(input::I) where {I<:AbstractInput} = error("Please implement method initial_state considering input type $I")
    cost_function(input::I, solution::S) where {I<:AbstractInput, S<:AbstractSolution} = error("Please implement method cost_function considering input type $I and solution of type $S")
    random_move(input::I, solution::S) where {I<:AbstractInput, S<:AbstractSolution,} = error("Please implement method random_move considering input type $I and solution of type $S")
    make_move!(input::I, solution::S, move::M) where {I<:AbstractInput, S<:AbstractSolution, M<:AbstractMove} = error("Please implement method make_move! for move of type $M")
    empty_move(move::M) where {M<:AbstractMove} = error("Please implement method empty_move for move of type $M")
    neighborhood(::M, input::I, solution::S) where {I<:AbstractInput, S<:AbstractSolution, M<:AbstractMove} = error("Please implement method neighborhood for move of type $M") 
end