using CHMMera
using Test



@testset "CHMMera.jl" begin
    @testset "utils.jl" begin
        @test CHMMera.as_ints("ACGT-N") == [0x01, 0x02, 0x03, 0x04, 0x05, 0x06]
        @test CHMMera.vovtomatrix([[0x01, 0x02, 0x03, 0x04, 0x05, 0x06], [0x01, 0x02, 0x03, 0x04, 0x05, 0x06]]) == [0x01 0x02 0x03 0x04 0x05 0x06; 0x01 0x02 0x03 0x04 0x05 0x06]
    end

    @testset "hmm.jl" begin
        fullhmm = CHMMera.FullHMM(CHMMera.vovtomatrix(CHMMera.as_ints.(["ACGT-N", "ACGT-N"])), [0.01, 0.02], 0.01)
        @test fullhmm.N == 4
        @test fullhmm.n == 2
        @test fullhmm.L == 6
        @test fullhmm.K == 2
        @test CHMMera.get_bs(fullhmm, CHMMera.as_ints("ACGT-N"), [0.01, 0.02]) == [0.99 0.99 0.99 0.99 0.99 1.0;
                                                                                0.98 0.98 0.98 0.98 0.98 1.0;
                                                                                0.99 0.99 0.99 0.99 0.99 1.0;
                                                                                0.98 0.98 0.98 0.98 0.98 1.0]

        approximatehmm = CHMMera.ApproximateHMM(CHMMera.vovtomatrix(CHMMera.as_ints.(["ACGT-N", "ACGT-N"])), 0.01)
        @test approximatehmm.N == 2
        @test approximatehmm.L == 6
        @test approximatehmm.switch_probability == 0.01 / 6
        @test CHMMera.get_bs(approximatehmm, CHMMera.as_ints("ACGT-N"), [0.01, 0.02]) == [0.99 0.99 0.99 0.99 0.99 1.0;
                                                                                                0.98 0.98 0.98 0.98 0.98 1.0]
    end

    @testset "algorithms.jl" begin
        fullhmm = CHMMera.FullHMM(CHMMera.vovtomatrix(CHMMera.as_ints.(["AAAAAA", "CCCCCC"])), [0.01, 0.02], 0.01)
        @test CHMMera.findrecombinations(CHMMera.as_ints("AAAAAA"), fullhmm, [0.01, 0.02]).recombinations == []
        @test CHMMera.findrecombinations(CHMMera.as_ints("CCCCCC"), fullhmm, [0.01, 0.02]).recombinations == []
        v = Vector{CHMMera.RecombinationEvent}(undef, 1)
        
        recombs = CHMMera.findrecombinations(CHMMera.as_ints("AAACCC"), fullhmm, [0.01, 0.02])
        @test recombs.recombinations[1] == CHMMera.RecombinationEvent(3,1,2,1,4)
 
    end

    @testset "CHMMera.jl" begin
        # Test chimera probability calculations
        # Non-chimeric sequence (AAAAAA) should have very low probability
        # Chimeric sequence (CCCAAA) should have very high probability
     
        references = ["AAAAAA", "CCCCCC"]
        queries = ["AAAAAA", "CCCAAA"]
        # Baum-Welch
        chimera_probs = CHMMera.get_chimera_probabilities(queries, references, true, [0.0], 0.05, 0.04)
        @test chimera_probs[1] < 0.1
        @test chimera_probs[2] > 0.99
        
        # Discrete Bayesian
        chimera_probs = CHMMera.get_chimera_probabilities(queries, references, false, [0.01, 0.05, 0.1], 0.05, 0.04)
        @test chimera_probs[1] < 0.1
        @test chimera_probs[2] > 0.99

        # Test recombination event calculations
        # Non-recombinant sequence (AAAAAA) should have no recombination events
        # Recombinant sequence (CCCAAA) should have recombination events
        # We should get the same results for Baum-Welch and Discrete Bayesian
        # Baum-Welch
        recombination_events = CHMMera.get_recombination_events(queries, references, true, [0.0], 0.05, 0.04, true)
        @test recombination_events[1].recombinations == []
        @test recombination_events[1].startingpoint == 1
        @test recombination_events[2].recombinations == [CHMMera.RecombinationEvent(4, 2, 1, 2, 1)]
        @test recombination_events[2].startingpoint == 2
        @test recombination_events[2].pathevaluation > 0.99
        
        # run without path evaluation/starting point
        recombination_events = CHMMera.get_recombination_events(queries, references, true, [0.0], 0.05, 0.04, false)
        @test recombination_events[1].recombinations == []
        @test recombination_events[1].startingpoint == 1
        @test recombination_events[2].recombinations == [CHMMera.RecombinationEvent(4, 2, 1, 2, 1)]

        # Discrete Bayesian
        recombination_events = CHMMera.get_recombination_events(queries, references, false, [0.01, 0.05, 0.1], 0.05, 0.04, true)
        @test recombination_events[1].recombinations == []
        @test recombination_events[1].startingpoint == 1
        @test recombination_events[2].recombinations == [CHMMera.RecombinationEvent(4, 2, 1, 4, 1)]
        @test recombination_events[2].startingpoint == 2
        @test recombination_events[2].pathevaluation > 0.99
    end
end
