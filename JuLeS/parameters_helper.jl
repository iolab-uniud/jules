using MacroTools
import OrderedCollections: OrderedDict
using ArgParse

macro expose_parameters(expr::Expr)
    @assert expr.head == :struct   
    if !@capture(expr, (mutable struct T_{TP__}<:ST_ given__ end) | (mutable struct T_ given__ end)) # t is name of the struct, fields is the fields
        error("Cannot capture expression")
    end
    ismutable = expr.args[1]
    fields = quote end
    fields.args = Any[]
    arguments::Array{Symbol} = []
    tuning_parameters = Dict{Symbol,Any}()
    
    list_kwargs::Array{Expr} = [] # entry must be like this Expr(:kw, :(x::Int64), 3) -> Expr(:kw,k,w)
    i::Int64 = 1
    for element in given 
        if element isa Symbol
            push!(fields.args,element)
            push!(list_kwargs,Expr(:kw,element,nothing))
            push!(arguments,element)
            if i > 1 && given[i-1] isa String 
                if occursin("parameter",lowercase(given[i-1]))
                    tuning_parameters[element] = nothing
                end 
            end 
        elseif element isa String
            push!(fields.args, element)
        elseif element.head==:(=) # default value with/without type annotation
            f = element.args[1]
            documentation_for_def = string("Default: ", element.args[2])
            if i > 1 && given[i-1] isa String # means that documentation was available
                # append to existing documentation
                fields.args[end] *= " " * documentation_for_def
            else 
                push!(fields.args, documentation_for_def)
            end 
            push!(fields.args,f)
            push!(list_kwargs,Expr(:kw,f,element.args[2]))
            if f isa Symbol
                push!(arguments,f)
            else
                push!(arguments,f.args[1])
            end 
            if i > 1 && given[i-1] isa String 
                if occursin("parameter",lowercase(given[i-1]))
                    if f isa Symbol
                        tuning_parameters[f] = nothing
                    else
                        tuning_parameters[f.args[1]] = f.args[2]
                    end 
                end 
            end 
        elseif element.head==:(::) #no default value but with type annotation
            push!(fields.args,element)
            push!(list_kwargs,Expr(:kw,element,nothing))
            push!(arguments,element.args[1])
            if i > 1 && given[i-1] isa String 
                if occursin("parameter",lowercase(given[i-1]))
                    tuning_parameters[element.args[1]] = element.args[2] 
                end 
            end 
        else
            error("Some sort of error happened here")
        end
        i = i + 1
    end
    # expression to give out starts as follows
    complete_struct = Expr(:struct,expr.args[1:2]...,copy(fields))

    fields_kws = Dict{Symbol, Any}() 
    fields_kws[:name] = T
    fields_kws[:args] = Any[]
    fields_kws[:kwargs] = list_kwargs
    fields_kws[:params] = TP
    fields_kws[:whereparams] = TP
    if (TP == nothing)
        fields_kws[:body] = :(return $T($(arguments...)))
    else
        fields_kws[:body] = :(return $T{$(TP...)}($(arguments...)))
    end
    constr_expr = MacroTools.combinedef(fields_kws)

    fields_kws_empty = Dict{Symbol, Any}() 
    fields_kws_empty[:name] = T
    fields_kws_empty[:args] = Any[]
    fields_kws_empty[:kwargs] = Any[]
    fields_kws_empty[:params] = TP
    fields_kws_empty[:whereparams] = TP

    argument_setting::Array{Expr} = []
    for element in list_kwargs
        expr::Expr = :()
        if element.args[1] isa Symbol 
            if element.args[2] == nothing
                expr = quote
                    field_name = string($(QuoteNode(element.args[1])))
                    println("Insert $(field_name): ")
                    value = readline()
                    push!(args_list, Expr(:kw, $(QuoteNode(element.args[1])), value))
                end
            else
                # you already have this stored at element.args[2]
                expr = :(
                    push!(args_list, Expr(:kw, $(QuoteNode(element.args[1])), $(element.args[2])))
                )
            end
        else # this means it has a type
            if element.args[2] == nothing 
                expr = quote
                    field_name = string($(QuoteNode(element.args[1].args[1])))
                    println("Insert $(field_name): ")
                    value = parse(eval($(element.args[1].args[2])),readline())
                    push!(args_list, Expr(:kw, $(QuoteNode(element.args[1].args[1])),value))
                end
            else # this means you already have the value at element.args[2]
                expr = :(
                    push!(args_list, Expr(:kw, $(QuoteNode(element.args[1].args[1])),$(element.args[2])))
                )
            end 
        end
        push!(argument_setting, expr)    
    end    
    return_statement = :()
    if (TP == nothing) # || (length($TP) == 1)
        return_statement = :(return $T(map(x -> x.args[2], args_list)...))
    else
        return_statement = :(return $T{$(TP...)}(map(x -> x.args[2], args_list)...))
    end
    fields_kws_empty[:body] = quote
        args_list::Array{Expr} = []
        $(argument_setting...)
        $(return_statement)
    end
    empty_constr_expr = MacroTools.combinedef(fields_kws_empty)

    irace_param = Dict{Symbol, Any}() 
    irace_param[:name] = Symbol(:get_Irace_template)
    irace_param[:args] = Any[T,]
    irace_param[:kwargs] = Any[Expr(:kw, :file, "configuration.txt")]

    irace_types = Dict{Symbol, Any}()
    for param in tuning_parameters
        if param[2] == nothing
            irace_types[param[1]] = "<type>"
        elseif (eval(param[2]) <: AbstractFloat)
            irace_types[param[1]] = "R"
        elseif (eval(param[2])  <: Integer)
            irace_types[param[1]] = "I"
        else 
            irace_types[param[1]] = "<type>"
        end
    end 
    activities::Array{Expr} = []
    for element in irace_types
        expr = quote
            name = string($(QuoteNode(element[1])))
            t = $(element[2])
            open(file, "a") do f
                write(f,"$(name) \"--$(name)\" $(t) <values> <condition>\n")
            end 
        end
        push!(activities, expr)
    end 
    irace_param[:body] = :(
        begin
            open(file, "w") do f
                write(f, "#name switch type values [conditions (using R syntax)]\n")
            end
            $(activities...)
            return
        end
    )
    irace_param_expr = MacroTools.combinedef(irace_param)

    command_line_tool = Dict{Symbol, Any}()
    command_line_tool[:name] = Symbol(:command_line_tool)
    command_line_tool[:args] = Any[T]
    command_line_tool[:kwargs] = Any[]
    insertion_of_commands::Array{Expr} = []
    for param in tuning_parameters
        if param[2] == nothing
            arg_type = :String
        elseif (eval(param[2]) <: AbstractFloat)
            arg_type = :Float64
        elseif (eval(param[2])  <: Integer)
            arg_type = :Int 
        else 
            arg_type = :String
        end       
        expr = quote
            add_arg_table!(s, "--" * string($(QuoteNode(param[1]))), Dict(
                :help => $("parameter $(param[1]) considering Runner $(T)"),
                :arg_type => $(arg_type)))
        end
        push!(insertion_of_commands,expr)
    end 
    

    command_line_tool[:body] = quote
            s = ArgParseSettings()
            @add_arg_table! s begin
                "--seed"
                    help = "random seed"
                    arg_type = Int        
                    default = 70    
                "--repetitions"
                    help = "number of trials"
                    arg_type = Int
                    default = 1
                "--result"
                    help = "flag to 1 if you want to store timings, number of iterations, and cost"
                    default = 0
                "--result-file"
                    help = "csv file where to store timings, number of iterations, and cost"
                    default = "res.csv"
                "--debug-logger"
                    arg_type = Int
                    help = "flag to 1 if you want to show logging"
                    default = 0
                "--instance"
                    help = "file instance"
            end
            $(insertion_of_commands...)
            return parse_args(s)
    end
    command_line_tool_expr = MacroTools.combinedef(command_line_tool)

    result = quote
        Base.@__doc__ $complete_struct
        $(constr_expr)
        $(empty_constr_expr)
        $(irace_param_expr)
        $(command_line_tool_expr)
    end
    nothing
    return esc(result)
 end

