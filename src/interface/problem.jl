"PDDL planning problem."
abstract type Problem end

"Returns an iterator over objects in a `problem`."
get_objects(problem::Problem) = error("Not implemented.")

"Returns a map from problem objects to their types."
get_objtypes(problem::Problem) = error("Not implemented.")

"Returns the goal specification of a problem."
get_goal(problem::Problem) = error("Not implemented.")

"Returns the metric specification of a problem."
get_metric(problem::Problem) = error("Not implemented.")
