module CHMMera

export get_chimera_probabilities, get_recombination_events, get_log_site_probabilities, get_chimerapathevaluation

include("utils.jl")
include("hmm.jl")
include("algorithms.jl")


"""
    get_chimera_probabilities(queries::Vector{String}, references::Vector{String}, bw::Bool = true, mutation_probabilities::Vector{Float64} = [0.0047, 0.01, 0.05, 0.1, 0.15, 0.2], base_mutation_probability::Float64 = 0.05, prior_probability::Float64 = 0.02

Compute the probability of a sequence being chimeric for each query sequence given a list of reference sequences.

...
# Arguments
- `queries::Vector{String}`: A vector of query sequences.
- `references::Vector{String}`: A vector of reference sequences.
- `bw::Bool = true`: A boolean indicating whether to use the approximate HMM (Baum-Welch) or the full HMM (Discrete Bayesian).
- `mutation_probabilities::Vector{Float64} = [0.0047, 0.01, 0.05, 0.1, 0.15, 0.2]`: A vector of mutation probabilities.
- `base_mutation_probability::Float64 = 0.05`: The base mutation probability. Used as starting point for Baum-Welch.
- `prior_probability::Float64 = 0.02`: The prior probability of a sequence being chimeric.
...
"""
get_chimera_probabilities(queries::Vector{String}, references::Vector{String}, bw::Bool = true, mutation_probabilities::Vector{Float64} = [0.0047, 0.01, 0.05, 0.1, 0.15, 0.2], base_mutation_probability::Float64 = 0.05, prior_probability::Float64 = 0.02) =
    get_chimera_probabilities(as_ints.(queries), as_ints.(references), bw, mutation_probabilities, base_mutation_probability, prior_probability)

"""
    get_recombination_events(queries::Vector{String}, references::Vector{String}, bw::Bool = true, mutation_probabilities::Vector{Float64} = [0.0047, 0.01, 0.05, 0.1, 0.15, 0.2], base_mutation_probability::Float64 = 0.05, prior_probability::Float64 = 0.02, detailed::Bool = false)

Compute the recombination events for a query sequence given a set of reference sequences. 
    
The return type is a vector of `RecombinationEvents` (plural because one query can have multiple recombination events).
In RecombinationEvents, `recombinations` is a vector of `RecombinationEvent`s, each of which contains `position`, `left`, `right`, `left_state`, and `right_state` (Since FullHMMs have multiple states per reference).
`startingpoint` is the starting point of viterbi path, `pathevaluation` is the probability of the second most probable reference, and `logsiteprobabilities` is the log probability of being at each site in the query sequence (forward * backward).
If the argument `detailed` is false, only `recombinations` is computed.

...
# Arguments
- `queries::Vector{String}`: A vector of query sequences.
- `references::Vector{String}`: A vector of reference sequences.
- `bw::Bool = true`: A boolean indicating whether to use the approximate HMM (Baum-Welch) or the full HMM (Discrete Bayesian).
- `mutation_probabilities::Vector{Float64} = [0.0047, 0.01, 0.05, 0.1, 0.15, 0.2]`: A vector of mutation probabilities.
- `base_mutation_probability::Float64 = 0.05`: The base mutation probability. Used as starting point for Baum-Welch.
- `prior_probability::Float64 = 0.02`: The prior probability of a sequence being chimeric.
- `detailed::Bool = false`: A boolean indicating whether to calculate `startingpoint`, `pathevaluation`, and `logsiteprobabilities`.
...
"""
get_recombination_events(queries::Vector{String}, references::Vector{String}, bw::Bool = true, mutation_probabilities::Vector{Float64} = [0.0047, 0.01, 0.05, 0.1, 0.15, 0.2], base_mutation_probability::Float64 = 0.05, prior_probability::Float64 = 0.02, detailed::Bool = false) =
    get_recombination_events(as_ints.(queries), as_ints.(references), bw, mutation_probabilities, base_mutation_probability, prior_probability, detailed)

function get_chimera_probabilities(queries::Vector{Vector{UInt8}}, references::Vector{Vector{UInt8}}, bw::Bool = true, mutation_probabilities::Vector{Float64} = [0.0047, 0.01, 0.05, 0.1, 0.15, 0.2], base_mutation_probability::Float64 = 0.05, prior_probability::Float64 = 0.02)
    hmm = bw ? ApproximateHMM(vovtomatrix(references), prior_probability) : FullHMM(vovtomatrix(references), mutation_probabilities, prior_probability)
    mutation_probabilities = bw ? [base_mutation_probability for i in 1:length(references)] : mutation_probabilities

    # split query iteration among threads
    chimera_probabiltiies = zeros(length(queries))
    Threads.@threads for i in eachindex(queries)
        chimera_probabiltiies[i] = chimeraprobability(queries[i], hmm, copy(mutation_probabilities))
    end
    return chimera_probabiltiies
end

function get_recombination_events(queries::Vector{Vector{UInt8}}, references::Vector{Vector{UInt8}}, bw::Bool = true, mutation_probabilities::Vector{Float64} = [0.0047, 0.01, 0.05, 0.1, 0.15, 0.2], base_mutation_probability::Float64 = 0.05, prior_probability::Float64 = 0.02, details::Bool = false)

    hmm = bw ? ApproximateHMM(vovtomatrix(references), prior_probability) : FullHMM(vovtomatrix(references), mutation_probabilities, prior_probability)
    mutation_probabilities = bw ? [base_mutation_probability for i in eachindex(references)] : mutation_probabilities

    # split query iteration among threads
    recombination_events = Vector{RecombinationEvents}(undef, length(queries))
    Threads.@threads for i in eachindex(queries)
        recombination_events[i] = get_recombination_events(queries[i], hmm, copy(mutation_probabilities), Val(details))
    end
    return recombination_events
end

# multiple dispatch to figure out if we want starting point or pathevaluation
# no starting point or path evaluation
function get_recombination_events(query::Vector{UInt8}, hmm::HMM, mutation_probabilities::Vector{Float64}, ::Val{false})
    findrecombinations(query, hmm, mutation_probabilities)
end

# starting point and path evaluation
function get_recombination_events(query::Vector{UInt8}, hmm::HMM, mutation_probabilities::Vector{Float64}, ::Val{true})
    findrecombinations_detailed(query, hmm, mutation_probabilities)
end

end