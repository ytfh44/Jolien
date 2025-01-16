# Jolien Documentation

Welcome to the documentation of Jolien, a lightweight dependency injection and aspect-oriented programming framework for Julia.

## Overview

Jolien provides a simple yet powerful way to manage dependencies and implement cross-cutting concerns in your Julia applications. It combines dependency injection (DI) and aspect-oriented programming (AOP) into a cohesive framework.

### Key Concepts

- **Components**: Basic building blocks that can be automatically managed and injected
- **Aspects**: Cross-cutting concerns that can be applied to multiple components
- **Container**: Central registry that manages component lifecycles and dependencies
- **Scopes**: Rules that determine how component instances are managed and shared

## Features

### Dependency Injection

- **Component Registration**: Automatic registration with `@component` macro
- **Dependency Resolution**: Automatic injection with `@autowired` macro
- **Scoped Instances**: Support for singleton and prototype scopes
- **Circular Detection**: Built-in circular dependency detection

### Aspect-Oriented Programming

- **Aspect Definition**: Define aspects with `@aspect` macro
- **Multiple Advices**: Support for:
  - `@before`: Execute before target method
  - `@after`: Execute after target method
  - `@around`: Wrap target method execution
- **Pointcut Expressions**: Flexible method matching
- **Aspect Lifecycle**: Proper initialization and cleanup

### Configuration Management

- **Environment-based**: Configure components based on environment
- **Conditional Loading**: Load components based on conditions
- **Priority Control**: Control component initialization order
- **Hot Reloading**: Support for runtime reconfiguration

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

# Define a simple component
@component struct DatabaseConfig
    host::String
    port::Int
    
    function DatabaseConfig(host::String="localhost", port::Int=5432)
        new(host, port)
    end
end

# Define a dependent component
@component struct UserService
    db::DatabaseConfig
    
    function UserService(db::DatabaseConfig)
        new(db)
    end
end
```

#### Component Registration

```julia
# Register components
db_config = DatabaseConfig()
register!(db_config)

# Automatic dependency injection
user_service = UserService(db_config)
register!(user_service)
```

#### Using Aspects

```julia
# Define a logging aspect
@aspect struct LoggingAspect
    log_count::Ref{Int}
    
    function LoggingAspect()
        new(Ref(0))
    end
end

# Apply advice
let
    aspect = LoggingAspect()
    advice = @before "query" begin
        aspect.log_count[] += 1
        println("Executing query...")
    end
    
    # Apply to a function
    query_fn = () -> "SELECT * FROM users"
    logged_query = advice(query_fn)
    
    # Execute with logging
    result = logged_query()
end
```

## Next Steps

For more detailed information about specific features, please refer to:

- [API Reference](api.md): Detailed API documentation
- [Examples](examples.md): More usage examples
- [Advanced Topics](advanced.md): Advanced features and patterns 