# API Reference

## Core Types

### AbstractComponent

```julia
abstract type AbstractComponent end
```

Base type for all components in the system. Components can either directly inherit from this type or implement its interface through conversion methods.

### Container

```julia
mutable struct Container
    components::Vector{Any}
    aspects::Vector{Any}
end
```

Central registry that manages components and aspects. Maintains the lifecycle of registered objects.

## Component Management

### @component

```julia
@component struct MyComponent
    field::Type
    # ...
end
```

Marks a struct as a component, making it available for dependency injection. The struct can either:
- Directly inherit from `AbstractComponent`
- Implement conversion to `AbstractComponent`

Features:
- Automatic type conversion
- Circular dependency detection
- Component registration support

### register!

```julia
register!(component)
```

Registers a component instance with the container. The component must either:
- Inherit from `AbstractComponent`
- Be convertible to `AbstractComponent`

Throws:
- `InvalidComponentError`: If component cannot be converted to `AbstractComponent`
- `DuplicateComponentError`: If component is already registered

### get_instance

```julia
get_instance(T::Type)
```

Retrieves an instance of the specified component type from the container.
Throws `ComponentNotFoundError` if no matching component is found.

## Aspect-Oriented Programming

### @aspect

```julia
@aspect struct MyAspect
    field::Type
    # ...
end
```

Defines an aspect that can add behavior to functions through advice.
Features:
- State management through fields
- Support for before/after/around advice
- Access to function context in advice

### Advice Types

#### @before

```julia
@before target_fn begin
    # code to execute before the target
end
```

Creates advice that executes before the target function.
The advice body has access to:
- `args`: Array of all arguments passed to the function

#### @after

```julia
@after target_fn begin
    # code to execute after the target
end
```

Creates advice that executes after the target function.
The advice body has access to:
- `args`: Array of all arguments passed to the function
- `result`: The value returned by the target function

#### @around

```julia
@around target_fn begin
    # code to execute around the target
    result = proceed()
    # more code
    return result
end
```

Creates advice that executes both before and after the target function.
The advice body has access to:
- `fn_name`: Symbol of the target function name
- `args`: Array of all arguments passed to the function
- `x`: First argument (if any) for convenience
- `proceed()`: Function to execute the target method

Special features:
- Must call `proceed()` exactly once
- Can modify the return value
- Can handle exceptions

## Container Management

### reset_container!

```julia
reset_container!()
```

Resets the global container, clearing all registered components and aspects.

### get_container

```julia
get_container()
```

Returns the current global container instance.

## Error Types

### ComponentNotFoundError

```julia
struct ComponentNotFoundError <: Exception
    type::Type
end
```

Thrown when attempting to retrieve a component that is not registered.

### CircularDependencyError

```julia
struct CircularDependencyError <: Exception
    cycle::Vector{Any}
end
```

Thrown when a circular dependency is detected during component initialization.

### InvalidComponentError

```julia
struct InvalidComponentError <: Exception
    type::Type
end
```

Thrown when attempting to register a component that cannot be converted to `AbstractComponent`.

### DuplicateComponentError

```julia
struct DuplicateComponentError <: Exception
    type::Type
end
```

Thrown when attempting to register a component of a type that is already registered. 