
module InstanceReader
    function parse_file(file_name::String)
        jobs::Int64 = 0
        machines::Int64 = 0
        jobs,machines = get_jobs_and_machines(file_name)
        matr = get_matrix(file_name,jobs,machines)
        return jobs,machines,matr
    end

    function get_jobs_and_machines(file_name::String)
        open(file_name) do f
            iter::Int64=0
            jobs::String = "0"
            machines::String = "0"
            for line = eachline(f)
                if iter == 0
                    machines,jobs = split(line, " ")
                    break
                end
            end 
            return parse(Int64, jobs),parse(Int64, machines)
        end
    end

    function get_matrix(file_name::String,jobs::Int64,machines::Int64)
        m::Matrix{Int64} = zeros(Int64,machines,jobs)
        open(file_name) do f
            iter::Int64=0
            current_job::Int64 = 1
            for line = eachline(f)
                iter = iter + 1
                if iter > 2 # && iter <=jobs + 2
                    task_per_job = [parse(Int64, ss) for ss in split(line)]
                    for i = 1:machines
                        m[i,current_job] = task_per_job[i]
                    end
                    current_job = current_job + 1
                end
            end 
            return m
        end
    end
end

# jobs,machines=get_jobs_and_machines("taillard_instances/taillard_b0/ta001b0.dat")
# matr = get_matrix("taillard_instances/taillard_b0/ta001b0.dat",jobs,machines)
# @show jobs,machines 
# display(matr)