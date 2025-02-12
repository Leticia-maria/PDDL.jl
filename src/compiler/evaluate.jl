function generate_evaluate(domain::Domain, state::State,
                           domain_type::Symbol, state_type::Symbol)
    evaluate_def = quote
        function evaluate(domain::$domain_type, state::$state_type, term::Const)
            return term.name in fieldnames($state_type) ?
                getfield(state, term.name) : term.name
        end
        function evaluate(domain::$domain_type, state::$state_type, term::Compound)
            func = get(GLOBAL_FUNCTIONS, term.name, nothing)
            val = if func !== nothing
                argvals = (evaluate(domain, state, arg) for arg in term.args)
                func(argvals...)
            else
                get_fluent(state, term)
            end
        end
    end
    return evaluate_def
end
