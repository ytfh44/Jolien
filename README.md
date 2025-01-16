# Jolien

Jolien is a lightweight dependency injection and aspect-oriented programming framework for Julia.

## Features

- **Dependency Injection**: Automatic component registration and injection
- **Aspect-Oriented Programming**: Support for before, after, and around advices
- **Scoping Rules**: Singleton and prototype scopes
- **Lifecycle Management**: Proper initialization order and circular dependency detection
- **Conditional Configuration**: Environment-based component configuration

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/ytfh44/Jolien")
```

## Quick Start

```julia
using Jolien

# Define a component
@component struct DatabaseService
    url::String
    port::Int
end

# Register the component
db = DatabaseService("localhost", 5432)
register!(db)

# Inject dependencies
@autowired db_instance::DatabaseService
@test db_instance().url == "localhost"

# Define aspects
@aspect struct LoggingAspect
    log_count::Ref{Int}
    
    function LoggingAspect()
        new(Ref(0))
    end
end

# Use advices
let
    call_count = 0
    test_fn = () -> "result"
    advice = @before "test" begin
        call_count += 1
    end
    logged_fn = advice(test_fn)
    
    @test logged_fn() == "result"
    @test call_count == 1
end
```

## Documentation

For more detailed information about using Jolien, please refer to the [documentation](docs/src/index.md).

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details. 