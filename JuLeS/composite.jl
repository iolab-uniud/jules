macro composite_neighborhood(name::Symbol, Input::Union{Symbol, Expr}, Solution::Union{Symbol, Expr}, types...)
    local calls = []
    local parameters = Expr(:parameters)
    local names = []
    for t in types
        var_name = Symbol(lowercase(String(t)))
        call = Expr(:call, Symbol(t))
        push!(calls, Symbol(var_name))
        push!(parameters.args, Expr(:kw, Symbol(var_name), call))
        push!(names, Symbol(var_name))
    end    
    push!(parameters.args, Expr(:kw, :active, UInt8(0)))
    local size = length(types)
    function check_method(all_methods, param_index::Int64)
        for t in types
            found::Bool = false
            for m in all_methods
                # The two conditions are needed because in some cases the type is wrapped into a Type{T} envelope
                if isa(eval(t), m.sig.parameters[param_index + 1]) || eval(t) == m.sig.parameters[param_index + 1] 
                    found = true
                    break
                end
            end
            if !found
                @error "A $(all_methods.ms[1].name) method for move type $(eval(t)) has not been found"
            end
        end
    end

    local convert_functions = []
    for (i, t) in enumerate(types)
        # from single move to the composite one
        e = :(
            @inline function convert(::Type{$(name)}, move::$(t))::$(name)
                return $(name)(move, UInt8($(i)))
            end
        )
        push!(convert_functions, e)
        # from the composite move to the single one
        e = :(
            @inline function convert(::Type{$(t)}, move::$(name))::$(t)
                move.active == $(i) || warn("Trying to convert a composite move $(name) to type $(t) whereas the content is of type $(types[i])")
                return $(t)(move.move)
            end
        )
        push!(convert_functions, e)
    end


    local union_move_types = Expr(:curly, :Union)
    for t in types
        push!(union_move_types.args, Expr(:curly, :Type, t))
    end

    function create_if_expression(cases::Array{Expr}, generate_else=false)
        resulting_expr::Expr = Expr(:if)
        prev::Expr = Expr(:nothing) # just a dummy expression
        for (i, cur) in enumerate(cases)
            if i == 1
                resulting_expr = cur
                resulting_expr.head = :if
                prev = cur
            else
                push!(prev.args, cur)
                prev = cur
            end
        end
        if generate_else
            push!(prev.args, Expr(:block, Expr(:call, :error, "Out of bounds, composition has $(size) elements")))
        end
        return resulting_expr
    end

    random_move_cases::Array{Expr} = []
    for i in 1:size
        var = gensym("move_$(i)")
        expr = quote
            $(var) = Jules.random_move($(types[i]), in, sol)
            if !Jules.empty_move($(var))
                return $(name)($(var), UInt8($(i)))
            end
        end
        push!(random_move_cases, Expr(:elseif, Expr(:call, Symbol("=="), :selected, i), expr))
    end  
    random_move_function = :(
        function Jules.random_move(::Type{$(name)}, in::I, sol::S) where {I<:AbstractInput, S<:AbstractSolution}
            available_neighborhoods::Set{Int64} = Set(1:$(size))                
            while !isempty(available_neighborhoods)
                selected::Int64 = rand(available_neighborhoods)
                $(create_if_expression(random_move_cases))
                pop!(available_neighborhoods, selected)
            end
            return $(name)()
        end     
    )

    make_move_cases::Array{Expr} = []
    for i in 1:size
        expr = quote            
            if !Jules.empty_move(move.move::$(types[i]))
                Jules.make_move!(in, sol, move.move::$(types[i]))
            end
        end
        push!(make_move_cases, Expr(:elseif, Expr(:call, Symbol("=="), :(move.active), i), expr))
    end
    make_move_function = :(
        function Jules.make_move!(in::I, sol::S, move::$(name)) where {I<:AbstractInput, S<:AbstractSolution}
            $(create_if_expression(make_move_cases))
        end  
    )

    empty_move_function = :(
        function Jules.empty_move(move::$(name))::Bool
            # all the remaining checks are superfluous
            return move.active == 0
        end 
    )
    
    compute_delta_cost_cases::Array{Expr} = []
    for i in 1:size
        if istrait(HasDeltaCost{Type{Input}, Type{Solution}, Type{types[i]}})
            push!(compute_delta_cost_cases, Expr(:elseif, Expr(:call, Symbol("=="), :(move.active), i), :(return Jules.delta_cost(in, sol, move.move::$(types[i])))))
        else
            push!(compute_delta_cost_cases, Expr(:elseif, Expr(:call, Symbol("=="), :(move.active), i), :(return Jules.compute_delta_cost(in, sol, current_cost, move.move::$(types[i])))))
        end
    end
    compute_delta_cost_function = :(
        function Jules.compute_delta_cost(in::I, sol::S, current_cost::C, move::$(name))::C where {I<:AbstractInput, S<:AbstractSolution, C}
            $(create_if_expression(compute_delta_cost_cases))
        end  
    )

    neighborhood_cases::Array{Expr} = []
    for i in 1:size
        var = gensym("m_$(i)")
        expr = :(      
            for $(var)::$(types[i]) in Jules.neighborhood($(types[i]), in, sol)
                if Jules.empty_move($(var))
                    break
                end
                @yield $(name)($(var), UInt8($(i)))
                found = true
            end
        )
        push!(neighborhood_cases, expr)
    end

    neighborhood = string(:(
        @resumable function Jules.neighborhood(::Type{$(name)}, in::I, sol::S) where {I<:AbstractInput, S<:AbstractSolution} 
            found = false
            $(neighborhood_cases...) 
            if !found
                @yield $(name)()
            end
        end
    ))

    constructors::Array{Expr} = []
    for i in 1:size
        expr = :(
            function $(name)(move::$(types[i]))
                return $(name)(move, UInt8($(i)))
            end
        )
        push!(constructors, expr)
    end
    expr = :(
        function $(name)()
            return $(name)($(types[1])(), UInt8(0))
        end
    )
    push!(constructors, expr)

    result = quote
        # Type Checking
        for t in [$(types...)]
            @assert (t <: AbstractMove) "$(t) is not a move type (i.e., not a subclass of AbstractMove)"
        end

        struct $(name) <: AbstractMove
            move::Union{$(types...)}  
            active::UInt8   
        end

        # Constructors     
        $(constructors...)

        # Convert functions from single move to the compound one and viceversa
        $(convert_functions...)            

        # empty move
        $(empty_move_function)
        
        # random move
        $(random_move_function)          

        # make move
        $(make_move_function)

        # compute delta cost
        $(compute_delta_cost_function)

        # neighborhood (it is comprised in a string so not to prematurely evaluate @resumable)
        eval(Meta.parse($(neighborhood)))

        nothing        
    end
    return esc(result)
end