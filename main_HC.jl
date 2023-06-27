using ResumableFunctions
using DataStructures
using IterTools

import Random
using StatsBase

using ArgParse

include("JuLeS/Jules.jl")
import .Jules: AbstractInput, AbstractSolution, AbstractMove, AbstractRunner,
    Problem, 
    HillClimbing, SimulatedAnnealing, SteepestDescent, TabuSearch,
    run!, EmptyNeighborhood, empty_move, @composite_neighborhood, delta_cost, HasDeltaCost

parsed_args = Jules.LocalSearch.HC.command_line_tool(HillClimbing)

seed::Int64 = parsed_args["seed"]

using Logging
Logging.disable_logging(Info)

struct JobSpecification<:AbstractInput
    jobs::Int64
    machines::Int64
    duration_matrix::Matrix{Int64}
end

struct JobSchedule<:AbstractSolution
    sequence::Array{Int64,1}
    function JobSchedule(in::JobSpecification) 
        return new(sample((1:in.jobs),in.jobs,replace=false))
    end
    function JobSchedule(sequence::Array{Int64,1})
        return new(sequence) 
    end 
end

function Jules.initial_state(in::JobSpecification)::JobSchedule
    return JobSchedule(in)
end 

function Jules.cost_function(in::JobSpecification,out::JobSchedule)::Int64
    m::Matrix{Int64} = zeros(Int64,in.machines,in.jobs)
    m[1,1] = in.duration_matrix[1,out.sequence[1]]
    for j = 2:in.machines
        m[j,1] = in.duration_matrix[j,out.sequence[1]] + m[j-1,1]
    end 
    for i = 2:in.jobs
        m[1,i] = in.duration_matrix[1,out.sequence[i]] + m[1,i-1]
    end 
    for i = 2:in.jobs
        for j = 2:in.machines 
            m[j,i] = in.duration_matrix[j,out.sequence[i]] + max(m[j,i-1],m[j-1,i])
        end
    end
    return m[in.machines,in.jobs]
end 

struct SwapJob<:AbstractMove
    e1::Int64
    e2::Int64
    SwapJob() = new(-1,-1)
    SwapJob(e1::Int64,e2::Int64) = new(e1,e2)
end

function Jules.empty_move(move::SwapJob)  
    return (move.e1 == -1 || move.e2 == -1)
end 

function Jules.random_move(::Type{SwapJob},in::JobSpecification,out::JobSchedule)::SwapJob
    (e1,e2) = sample(1:in.jobs,2,replace=false)
    return SwapJob(e1,e2)
end

function Jules.make_move!(in::JobSpecification,out::JobSchedule,move::SwapJob)
    if move.e1 == move.e2 
        return
    end
    tmp::Int64 = out.sequence[move.e1]
    out.sequence[move.e1] = out.sequence[move.e2]
    out.sequence[move.e2] = tmp
end

@resumable function Jules.neighborhood(::Type{SwapJob},in::JobSpecification,out::JobSchedule)::SwapJob
    for e1 = 1:in.jobs-1
        for e2 = e1+1:in.jobs 
            @yield SwapJob(e1,e2)
        end
    end
end

struct InsertJob<:AbstractMove
    to_take::Int64 
    insert_at::Int64
    InsertJob() = new(-1,-1)
    InsertJob(to_take::Int64,insert_at::Int64) = new(to_take,insert_at)
end

function Jules.empty_move(move::InsertJob)
    return (move.to_take == -1 || move.insert_at == -1)
end 

function Jules.random_move(::Type{InsertJob},in::JobSpecification,out::JobSchedule)::InsertJob
    (to_take,insert_at) = sample(1:in.jobs,2,replace=false)
    return InsertJob(to_take,insert_at)
end

function Jules.make_move!(in::JobSpecification,out::JobSchedule,move::InsertJob)
    item::Int64 = out.sequence[move.to_take]
    deleteat!(out.sequence, move.to_take)
    insert!(out.sequence, move.insert_at, item)
end

@resumable function Jules.neighborhood(::Type{InsertJob},in::JobSpecification,out::JobSchedule)::InsertJob
    for to_take = 1:in.jobs-1
        for insert_at = to_take+1:in.jobs 
            @yield InsertJob(to_take,insert_at)
        end
    end
end

#########MAIN#################################################
include("instance_reader.jl")
using .InstanceReader

jobs,machines,duration_matrix = InstanceReader.parse_file(parsed_args["instance"])
input_instance::JobSpecification = JobSpecification(jobs,machines,duration_matrix)

for i in range(1, parsed_args["repetitions"])
    Random.seed!(seed + i - 1)
    runner_instance = HillClimbing{JobSpecification, JobSchedule, InsertJob, Int64}(input=input_instance, max_idle_iteration=parsed_args["max_idle_iteration"])
    s = @time run!(runner_instance,)
    println("$(runner_instance.best_cost) // $(runner_instance.iteration) iterations")
end


