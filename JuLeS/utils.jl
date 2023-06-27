module Utils
    using ArgParse
    import REPL
    using REPL.TerminalMenus

    function setting_result_file(file::String)
        open(file, "w") do f
            write(f, "seed;algorithm;run;cost;iterations;elapsed_time\n")
        end
    end 

    function write_result_file(file::String, seed::Int64, algorithm::String, elapsed_time::Float64, iterations::Int64, cost::Number, run::Int64=1)
        open(file, "a") do f
            write(f,"$seed,$algorithm,$run,$cost,$iterations,$elapsed_time)\n")
        end 
    end 
end

