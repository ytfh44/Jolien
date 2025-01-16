# Advanced Topics

## Component Lifecycle Management

### Initialization Order

Components are initialized in dependency order. Jolien automatically determines the correct initialization sequence based on the dependency graph.

```julia
@component struct ConfigService
    settings::Dict{String, Any}
    
    function ConfigService()
        new(Dict{String, Any}())
    end
end

@component struct DatabaseService
    config::ConfigService
    connection::Union{Nothing, String}
    
    function DatabaseService(config::ConfigService)
        new(config, nothing)
    end
end

@component struct UserService
    db::DatabaseService
    
    function UserService(db::DatabaseService)
        new(db)
    end
end

# Components will be initialized in order:
# 1. ConfigService (no dependencies)
# 2. DatabaseService (depends on ConfigService)
# 3. UserService (depends on DatabaseService)
```

### Cleanup and Disposal

Implement the `Base.close` method for proper resource cleanup:

```julia
@component struct ResourceService
    resource::IOStream
    
    function ResourceService()
        new(open("data.txt", "w"))
    end
end

function Base.close(service::ResourceService)
    close(service.resource)
end

# Register with cleanup
service = ResourceService()
register!(service)

# Later, when cleaning up
close(service)
```

## Advanced Aspect Patterns

### Composable Aspects

Create aspects that can be combined in different ways:

```julia
@aspect struct LoggingAspect
    logger::IOStream
    
    function LoggingAspect(path::String)
        new(open(path, "w"))
    end
end

@aspect struct MetricsAspect
    counts::Dict{String, Int}
    
    function MetricsAspect()
        new(Dict{String, Int}())
    end
end

# Combine aspects
function create_monitored_function(f::Function, name::String)
    logger = LoggingAspect("log.txt")
    metrics = MetricsAspect()
    
    logging_advice = @around name begin
        write(logger.logger, "Starting $name\\n")
        result = proceed()
        write(logger.logger, "Finished $name\\n")
        result
    end
    
    metrics_advice = @around name begin
        metrics.counts[name] = get(metrics.counts, name, 0) + 1
        proceed()
    end
    
    # Apply both aspects
    monitored_fn = logging_advice(metrics_advice(f))
    return monitored_fn, metrics
end
```

### Context-Aware Aspects

Create aspects that can access and modify execution context:

```julia
@aspect struct TransactionAspect
    active_transactions::Dict{String, Bool}
    
    function TransactionAspect()
        new(Dict{String, Bool}())
    end
end

function with_transaction(aspect::TransactionAspect, name::String, f::Function)
    advice = @around name begin
        # Start transaction
        aspect.active_transactions[name] = true
        
        try
            result = proceed()
            # Commit
            delete!(aspect.active_transactions, name)
            return result
        catch e
            # Rollback
            delete!(aspect.active_transactions, name)
            rethrow(e)
        end
    end
    
    return advice(f)
end
```

## Testing Strategies

### Component Testing

Test components in isolation using mocks:

```julia
# Define interface
abstract type AbstractDatabase end

@component struct MockDatabase <: AbstractDatabase
    queries::Vector{String}
    
    MockDatabase() = new(String[])
end

@component struct UserRepository
    db::AbstractDatabase
    
    UserRepository(db::AbstractDatabase) = new(db)
end

# Test with mock
function test_user_repository()
    mock_db = MockDatabase()
    repo = UserRepository(mock_db)
    
    # Test operations
    add_user(repo, "test")
    @test length(mock_db.queries) == 1
    @test mock_db.queries[1] == "INSERT INTO users (name) VALUES ('test')"
end
```

### Aspect Testing

Test aspects independently:

```julia
@aspect struct TestAspect
    calls::Vector{Symbol}
    
    TestAspect() = new(Symbol[])
end

function test_aspect_order()
    aspect = TestAspect()
    
    before_advice = @before "test" begin
        push!(aspect.calls, :before)
    end
    
    after_advice = @after "test" begin
        push!(aspect.calls, :after)
    end
    
    # Test function
    f = () -> push!(aspect.calls, :execute)
    
    # Apply advices
    monitored = after_advice(before_advice(f))
    monitored()
    
    # Verify order
    @test aspect.calls == [:before, :execute, :after]
end
```

## Performance Optimization

### Lazy Loading

Implement lazy loading for expensive resources:

```julia
@component struct LazyResource
    loader::Function
    resource::Ref{Any}
    
    function LazyResource(loader::Function)
        new(loader, Ref{Any}(nothing))
    end
end

function get_resource(lazy::LazyResource)
    if lazy.resource[] === nothing
        lazy.resource[] = lazy.loader()
    end
    lazy.resource[]
end

# Usage
resource = LazyResource(() -> begin
    println("Loading expensive resource...")
    # Simulate expensive loading
    sleep(1)
    return "Expensive Data"
end)

# Resource is loaded only when needed
@test get_resource(resource) == "Expensive Data"
```

### Caching Aspects

Implement caching using aspects:

```julia
@aspect struct CachingAspect
    cache::Dict{String, Any}
    
    CachingAspect() = new(Dict{String, Any}())
end

function with_cache(aspect::CachingAspect, key::String, f::Function)
    advice = @around key begin
        if haskey(aspect.cache, key)
            return aspect.cache[key]
        end
        
        result = proceed()
        aspect.cache[key] = result
        return result
    end
    
    return advice(f)
end
```

## Best Practices

### Component Design

1. Keep components focused and single-purpose
2. Use interfaces (abstract types) for flexibility
3. Implement proper cleanup methods
4. Use appropriate scoping

### Aspect Design

1. Make aspects composable
2. Handle resources properly
3. Consider order of aspect application
4. Use meaningful pointcuts

### Error Handling

1. Use specific error types
2. Implement proper cleanup in error cases
3. Consider transaction boundaries
4. Log errors appropriately 