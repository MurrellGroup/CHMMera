# CHMMera Documentation

```@docs
get_chimera_probabilities(queries::Vector{String}, references::Vector{String}, bw::Bool = true, prior_probability::Float64 = 1/300)
get_recombination_events(query::String, references::Vector{String}, bw = true, prior_probability = 1/300)
get_log_site_probabilities(query::String, refs::Vector{String}; prior_probability = 1/300)
```