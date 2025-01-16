# Examples

## Basic Component Management

### Component Definition and Registration

```julia
using Jolien

# Define a component using inheritance
@component struct DirectComponent <: AbstractComponent
    name::String
end

# Define a component using conversion
@component struct ConvertibleComponent
    value::Int
end

# Register components
direct = DirectComponent("direct")
register!(direct)

convertible = ConvertibleComponent(42)
register!(convertible)

# Retrieve components
@test get_instance(DirectComponent).name == "direct"
@test get_instance(ConvertibleComponent).value == 42
```

## Aspect-Oriented Programming

### Basic Logging Aspect

```julia
# Define a logging aspect
@aspect struct LoggingAspect
    log::Vector{String}
    
    LoggingAspect() = new(String[])
end

let
    aspect = LoggingAspect()
    
    function greet(name::String)
        return "Hello, $name!"
    end
    
    # Add logging with @around
    logged_greet = @around greet begin
        push!(aspect.log, "Calling greet with args: $args")
        result = proceed()
        push!(aspect.log, "greet returned: $result")
        result
    end
    
    # Test the logged function
    @test logged_greet("World") == "Hello, World!"
    @test length(aspect.log) == 2
    @test aspect.log[1] == "Calling greet with args: [\"World\"]"
    @test aspect.log[2] == "greet returned: Hello, World!"
end
```

### State Management Aspect

```julia
# Define an aspect that tracks function calls
@aspect struct StateAspect
    states::Dict{Symbol, Any}
    
    StateAspect() = new(Dict{Symbol, Any}())
end

function record_call(aspect::StateAspect, fn_name::Symbol, args::Vector, result)
    # Update call count
    aspect.states[fn_name] = get(aspect.states, fn_name, 0) + 1
    
    # Update argument history
    args_key = Symbol(:args_, fn_name)
    if !haskey(aspect.states, args_key)
        aspect.states[args_key] = []
    end
    push!(aspect.states[args_key], args...)
    
    # Update result history
    results_key = Symbol(:results_, fn_name)
    if !haskey(aspect.states, results_key)
        aspect.states[results_key] = []
    end
    push!(aspect.states[results_key], result)
    
    return result
end

let
    aspect = StateAspect()
    
    function calculate(x::Int)
        return x * 2
    end
    
    # Add state tracking
    tracked_calc = @around calculate begin
        result = proceed()
        record_call(aspect, fn_name, args, result)
        result
    end
    
    # Test the tracked function
    @test tracked_calc(5) == 10
    @test tracked_calc(3) == 6
    
    # Verify state
    @test aspect.states[Symbol("calculate")] == 2  # Call count
    @test aspect.states[Symbol(:args_, "calculate")] == [5, 3]  # Arguments
    @test aspect.states[Symbol(:results_, "calculate")] == [10, 6]  # Results
end
```

### Multiple Aspects

```julia
# Define timing aspect
@aspect struct TimingAspect
    times::Dict{Symbol, Float64}
    
    TimingAspect() = new(Dict{Symbol, Float64}())
end

# Define validation aspect
@aspect struct ValidationAspect
    valid::Dict{Symbol, Bool}
    
    ValidationAspect() = new(Dict{Symbol, Bool}())
end

let
    timing = TimingAspect()
    validation = ValidationAspect()
    
    function process(data::Vector{Int})
        sum(data)
    end
    
    # Add timing measurement
    timed_process = @around process begin
        start_time = time()
        result = proceed()
        timing.times[fn_name] = time() - start_time
        result
    end
    
    # Add validation
    validated_process = @around timed_process begin
        if isempty(args[1])
            validation.valid[fn_name] = false
            return 0
        end
        validation.valid[fn_name] = true
        proceed()
    end
    
    # Test with valid data
    @test validated_process([1, 2, 3]) == 6
    @test validation.valid[Symbol("process")] == true
    @test haskey(timing.times, Symbol("process"))
    
    # Test with invalid data
    @test validated_process(Int[]) == 0
    @test validation.valid[Symbol("process")] == false
end
```

### Error Handling

```julia
# Define error handling aspect
@aspect struct ErrorHandlingAspect
    errors::Dict{Symbol, Exception}
    
    ErrorHandlingAspect() = new(Dict{Symbol, Exception}())
end

let
    error_handler = ErrorHandlingAspect()
    
    function divide(a::Int, b::Int)
        a / b
    end
    
    # Add error handling
    safe_divide = @around divide begin
        try
            proceed()
        catch e
            error_handler.errors[fn_name] = e
            return nothing
        end
    end
    
    # Test normal case
    @test safe_divide(10, 2) == 5.0
    
    # Test error case
    @test safe_divide(1, 0) === nothing
    @test error_handler.errors[Symbol("divide")] isa DivideError
end
``` 