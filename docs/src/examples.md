# Examples

## Basic Dependency Injection

### Simple Service

```julia
# Define a basic configuration component
@component struct Config
    host::String
    port::Int
end

# Define a service that depends on the config
@component struct DatabaseService
    config::Config
    connection::Union{Nothing, String}
    
    function DatabaseService(config::Config)
        new(config, nothing)
    end
end

# Register components
config = Config("localhost", 5432)
register!(config)

db = DatabaseService(config)
register!(db)

# Use autowired to get instances
@autowired db_service::DatabaseService
@test db_service().config.host == "localhost"
```

## Aspect-Oriented Programming

### Logging Aspect

```julia
# Define a logging aspect
@aspect struct LoggingAspect
    log_count::Ref{Int}
    
    function LoggingAspect()
        new(Ref(0))
    end
end

# Create logging functions
function log_entry(aspect::LoggingAspect, method_name::String)
    aspect.log_count[] += 1
    println("Entering method: ", method_name)
end

function log_exit(aspect::LoggingAspect, method_name::String)
    println("Exiting method: ", method_name)
end

# Apply aspects
let
    aspect = LoggingAspect()
    
    # Before advice
    before_advice = @before "query" begin
        log_entry(aspect, "query")
    end
    
    # After advice
    after_advice = @after "query" begin
        log_exit(aspect, "query")
    end
    
    # Target function
    query_fn = () -> "SELECT * FROM users"
    
    # Apply advices
    logged_query = after_advice(before_advice(query_fn))
    
    # Execute
    result = logged_query()
    @test aspect.log_count[] == 1
end
```

## Scoping Rules

### Singleton vs Prototype

```julia
# Singleton component (default)
@component struct SingletonService
    id::Int
    
    function SingletonService()
        new(rand(1:1000))
    end
end

# Prototype component
@component struct PrototypeService
    id::Int
    
    function PrototypeService()
        new(rand(1:1000))
    end
end

# Register with different scopes
singleton = SingletonService()
register!(singleton)  # Default SingletonScope

prototype = PrototypeService()
register!(prototype, scope=PrototypeScope())

# Test scoping
@autowired s1::SingletonService
@autowired s2::SingletonService
@test s1().id == s2().id  # Same instance

@autowired p1::PrototypeService
@autowired p2::PrototypeService
@test p1().id != p2().id  # Different instances
```

## Advanced Features

### Circular Dependency Detection

```julia
# This will throw CircularDependencyError
@component struct ServiceA
    b::ServiceB
end

@component struct ServiceB
    a::ServiceA
end

@test_throws CircularDependencyError begin
    a = ServiceA(ServiceB(a))
end
```

### Conditional Configuration

```julia
# Environment-based configuration
@component struct EnvConfig
    mode::String
    
    function EnvConfig()
        env = get(ENV, "APP_ENV", "development")
        new(env)
    end
end

# Register based on environment
if get(ENV, "APP_ENV", "development") == "production"
    register!(EnvConfig())
else
    register!(EnvConfig())
end
```

### Multiple Aspects

```julia
# Define multiple aspects
@aspect struct TimingAspect
    times::Dict{String, Float64}
    
    function TimingAspect()
        new(Dict{String, Float64}())
    end
end

@aspect struct ValidationAspect
    valid::Ref{Bool}
    
    function ValidationAspect()
        new(Ref(true))
    end
end

# Apply multiple aspects
let
    timing = TimingAspect()
    validation = ValidationAspect()
    
    # Create advices
    timing_advice = @around "process" begin
        start_time = time()
        result = proceed()
        timing.times["process"] = time() - start_time
        result
    end
    
    validation_advice = @before "process" begin
        validation.valid[] = true
    end
    
    # Target function
    process_fn = () -> sleep(0.1)
    
    # Apply multiple advices
    monitored_fn = timing_advice(validation_advice(process_fn))
    
    # Execute
    monitored_fn()
    @test haskey(timing.times, "process")
    @test validation.valid[]
end
``` 