"Ground action definition."
struct GroundAction <: Action
    name::Symbol
    term::Compound
    preconds::Vector{Term}
    effect::Union{GenericDiff,ConditionalDiff}
end

get_name(action::GroundAction) = action.name

get_argvals(action::GroundAction) = term.args

get_precond(action::GroundAction) = Compound(:and, action.preconds)

get_effect(action::GroundAction) = as_term(action.effect)

"Group of ground actions with a shared schema."
struct GroundActionGroup <: Action
    name::Symbol
    actions::Dict{Compound,GroundAction}
end

function GroundActionGroup(name::Symbol, actions::AbstractVector{GroundAction})
    actions = Dict(act.term => act for act in actions)
    return GroundActionGroup(name, actions)
end

get_name(action::GroundActionGroup) = action.name

"Returns an iterator over all ground arguments of an `action`."
function groundargs(domain::Domain, state::State, action::Action)
    iters = (get_objects(domain, state, ty) for ty in get_argtypes(action))
    return Iterators.product(iters...)
end

"""
    groundactions(domain::Domain, state::State, action::Action)

Returns ground actions for a lifted `action` in a `domain` and initial `state`.
"""
function groundactions(domain::Domain, state::State, action::Action,
                       statics=infer_static_fluents(domain))
    ground_acts = GroundAction[]
    act_name = get_name(action)
    act_vars = get_argvars(action)
    # Dequantify and flatten preconditions and effects
    _precond = dequantify(get_precond(action), domain, state)
    _effect = dequantify(get_effect(action), domain, state)
    _conds, _effects = flatten_conditions(_effect)
    for args in groundargs(domain, state, action)
        subst = Subst(var => val for (var, val) in zip(act_vars, args))
        term = Compound(act_name, collect(args))
        # Substitute and simplify precondition
        precond = substitute(_precond, subst)
        precond = simplify_statics(precond, domain, state, statics)
        precond.name == false && continue # Skip unsatisfiable actions
        preconds = to_cnf_clauses(precond)
        # Simplify conditions of conditional effects
        conds = map(_conds) do cs
            isempty(cs) && return cs
            cond = substitute(Compound(:and, cs), subst)
            cond = simplify_statics(cond, domain, state, statics)
            return to_cnf_clauses(cond)
        end
        # Construct diffs from conditional effect terms
        diffs = map(_effects) do es
            eff = substitute(Compound(:and, es), subst)
            return effect_diff(domain, state, eff)
        end
        # Delete unsatisfiable branches
        unsat_idxs = findall(cs -> Const(false) in cs, conds)
        deleteat!(conds, unsat_idxs)
        deleteat!(diffs, unsat_idxs)
        # Construct conditional diff if necessary
        if length(diffs) > 1
            effect = ConditionalDiff(conds, diffs)
        elseif length(diffs) == 1
            effect = diffs[1]
            preconds = append!(preconds, conds[1])
            filter!(c -> c != Const(true), preconds)
        else # Skip actions with no active branches
            continue
        end
        # Construct ground action
        act = GroundAction(act_name, term, preconds, effect)
        push!(ground_acts, act)
    end
    return ground_acts
end

function groundactions(domain::Domain, state::State, action::GroundActionGroup,
                       statics=nothing)
    return values(action.actions)
end

"""
    groundactions(domain::Domain, state::State)

Returns all ground actions for a `domain` and initial `state`.
"""
function groundactions(domain::Domain, state::State)
    statics = infer_static_fluents(domain)
    iters = (groundactions(domain, state, act, statics)
             for act in values(get_actions(domain)))
    return collect(Iterators.flatten(iters))
end

"""
    ground(domain::Domain, state::State, action::Action)

Grounds a lifted `action` in a `domain` and initial `state`, returning a
group of grounded actions.
"""
function ground(domain::Domain, state::State, action::GenericAction,
                statics=infer_static_fluents(domain))
    ground_acts = groundactions(domain, state, action, statics)
    return GroundActionGroup(action.name, ground_acts)
end
