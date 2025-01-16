# Jolien Documentation

Welcome to the documentation of Jolien, a lightweight aspect-oriented programming framework for Julia.

## Overview

Jolien provides a simple yet powerful way to implement cross-cutting concerns in your Julia applications. It focuses on aspect-oriented programming (AOP) with a flexible component system.

### Key Concepts

- **Components**: Types that can be registered and managed by the framework
- **Aspects**: Cross-cutting concerns that can be applied to functions
- **Advice**: Code that is executed before, after, or around function calls
- **Container**: Central registry that manages components and aspects

## Features

### Component System

- **Flexible Type System**:
  - Direct inheritance from `AbstractComponent`
  - Type conversion support for existing types
- **Registration Management**:
  - Component registration with type checking
  - Duplicate registration prevention
  - Circular dependency detection

### Aspect-Oriented Programming

- **Multiple Advice Types**:
  - `@before`: Execute before target function
  - `@after`: Execute after target function
  - `@around`: Wrap target function execution
- **Rich Context Access**:
  - Function name and arguments
  - Return value modification
  - Error handling
- **State Management**:
  - Aspect state tracking
  - Call history recording
  - Result accumulation

## Getting Started

### Installation

```julia
using Pkg
Pkg.add(url="https://github.com/ytfh44/Jolien")
```

### Basic Usage

#### Component Definition

```julia
using Jolien

# Direct inheritance
@component struct DirectComponent <: AbstractComponent
    name::String
end

# Type conversion
@component struct ConvertibleComponent
    value::Int
end

# Register components
direct = DirectComponent("test")
register!(direct)

convertible = ConvertibleComponent(42)
register!(convertible)

# Retrieve components
@test get_instance(DirectComponent).name == "test"
@test get_instance(ConvertibleComponent).value == 42
```

#### Using Aspects

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
    
    # Use the enhanced function
    result = logged_greet("World")
    @test result == "Hello, World!"
    @test length(aspect.log) == 2
end
```

#### State Management

```julia
# Define a stateful aspect
@aspect struct StateAspect
    states::Dict{Symbol, Any}
    
    StateAspect() = new(Dict{Symbol, Any}())
end

let
    aspect = StateAspect()
    
    function calculate(x::Int)
        return x * 2
    end
    
    # Add state tracking
    tracked_calc = @around calculate begin
        # Store function name and arguments
        aspect.states[fn_name] = get(aspect.states, fn_name, 0) + 1
        
        # Execute and store result
        result = proceed()
        
        # Update state
        results_key = Symbol(:results_, fn_name)
        if !haskey(aspect.states, results_key)
            aspect.states[results_key] = []
        end
        push!(aspect.states[results_key], result)
        
        result
    end
    
    # Use the tracked function
    @test tracked_calc(5) == 10
    @test aspect.states[Symbol("calculate")] == 1  # Call count
end
```

## Next Steps

For more detailed information about specific features, please refer to:

- [API Reference](api.md): Detailed API documentation
- [Examples](examples.md): More usage examples
- [Advanced Topics](advanced.md): Advanced features and patterns 