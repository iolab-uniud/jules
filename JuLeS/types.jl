module Types
    export AbstractInput, AbstractSolution, AbstractMove, AbstractRunner
    abstract type AbstractInput end
    abstract type AbstractSolution end
    abstract type AbstractMove end

    abstract type AbstractRunner{I<:AbstractInput, S<:AbstractSolution, M<:AbstractMove, C<:Number} 
    end
end