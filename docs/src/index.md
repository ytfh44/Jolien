# Jolien Documentation

Welcome to the documentation of Jolien, a lightweight dependency injection and aspect-oriented programming framework for Julia.

## Overview

Jolien provides a simple yet powerful way to manage dependencies and implement cross-cutting concerns in your Julia applications. It combines the best practices of dependency injection and aspect-oriented programming into a cohesive framework.

## Features

### Dependency Injection

- Component registration and management
- Automatic dependency resolution
- Scoped instance management (Singleton/Prototype)
- Circular dependency detection

### Aspect-Oriented Programming

- Before, after, and around advices
- Pointcut expressions
- Aspect lifecycle management
- Multiple aspect application

### Configuration Management

- Environment-based configuration
- Conditional component registration
- Component replacement strategies
- Priority-based loading

## Getting Started

### Installation

```julia
using Pkg
Pkg.add(url="https://github.com/yourusername/Jolien.jl")
```

### Basic Usage

```julia
using Jolien

# Define a component
@component struct UserService
    users::Vector{String}
    
    function UserService()
        new(String[])
    end
end

# Register the component
service = UserService()
register!(service)

# Inject dependencies
@autowired user_service::UserService

# Use the service
service = user_service()
```

### Adding Aspects

```julia
# Define an aspect
@aspect struct LoggingAspect
    log_count::Ref{Int}
    
    function LoggingAspect()
        new(Ref(0))
    end
end

# Add advice
let
    call_count = 0
    test_fn = () -> "result"
    advice = @before "test" begin
        call_count += 1
    end
    logged_fn = advice(test_fn)
    
    # The advice will be executed before the function
    result = logged_fn()
end
```

## API Reference

For detailed API documentation, please refer to the [API Reference](api.md) section. 