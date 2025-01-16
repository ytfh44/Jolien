using Test
using Jolien

@testset "Basic Aspects" begin
    # Simple logging aspect
    @aspect struct LoggingAspect
        log_count::Ref{Int}
        
        function LoggingAspect()
            new(Ref(0))
        end
    end
    
    # Test before advice
    let
        aspect = LoggingAspect()
        test_fn = () -> "result"
        
        logged_fn = @before test_fn begin
            aspect.log_count[] += 1
        end
        
        @test logged_fn() == "result"
        @test aspect.log_count[] == 1
    end
    
    # Test after advice
    let
        aspect = LoggingAspect()
        test_fn = () -> "result"
        
        logged_fn = @after test_fn begin
            aspect.log_count[] += 1
        end
        
        @test logged_fn() == "result"
        @test aspect.log_count[] == 1
    end
    
    # Test around advice
    let
        aspect = LoggingAspect()
        test_fn = () -> "result"
        
        logged_fn = @around test_fn begin
            aspect.log_count[] += 1
            proceed()
        end
        
        @test logged_fn() == "result"
        @test aspect.log_count[] == 1
    end
end

@testset "Multiple Aspects" begin
    # Define timing aspect
    @aspect struct TimingAspect
        time_taken::Ref{Float64}
        
        function TimingAspect()
            new(Ref(0.0))
        end
    end
    
    # Define validation aspect
    @aspect struct ValidationAspect
        valid_count::Ref{Int}
        
        function ValidationAspect()
            new(Ref(0))
        end
    end
    
    let
        timing = TimingAspect()
        validation = ValidationAspect()
        test_fn = () -> begin
            sleep(0.1)
            "result"
        end
        
        # Apply multiple aspects
        timed_fn = @around test_fn begin
            start_time = time()
            result = proceed()
            timing.time_taken[] = time() - start_time
            result
        end
        
        validated_fn = @around timed_fn begin
            validation.valid_count[] += 1
            proceed()
        end
        
        @test validated_fn() == "result"
        @test validation.valid_count[] == 1
        @test timing.time_taken[] > 0.0
    end
end 