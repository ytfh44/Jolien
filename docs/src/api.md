# API Reference

## Core Types

### AbstractComponent

```julia
abstract type AbstractComponent end
```

Base type for all components in the system. All components must inherit from this type.

### AbstractAspect

```julia
abstract type AbstractAspect end
```

Base type for all aspects in the system. All aspects must inherit from this type.

### Scope

```julia
abstract type Scope end
struct SingletonScope <: Scope end
struct PrototypeScope <: Scope end
```

Types that define component lifecycle management:
- `SingletonScope`: One instance is shared across the container
- `PrototypeScope`: New instance is created for each request

## Component Management

### @component

```julia
@component struct MyComponent <: AbstractComponent
    field::Type
    # ...
end
```

Marks a struct as a component, making it available for dependency injection. Features:
- Automatic registration with container
- Support for constructor injection
- Lifecycle management through scopes
- Circular dependency detection

### register!

```julia
register!(component::T; scope::Scope = SingletonScope()) where T <: AbstractComponent
```

Registers a component instance with the container. Parameters:
- `component`: The component instance to register
- `scope`: The scope that determines instance lifecycle (default: singleton)

Returns the registered component instance.

### get_instance

```julia
get_instance(T::Type)
```

Retrieves an instance of the specified component type from the container.
Throws `ComponentNotFoundError` if component is not registered.

## Dependency Injection

### @autowired

```julia
@autowired service::ServiceType
```

Creates a function that retrieves the specified component from the container.
The function name will be the same as the field name.

Features:
- Lazy loading of dependencies
- Automatic scope handling
- Type safety checks

## Aspect-Oriented Programming

### @aspect

```julia
@aspect struct MyAspect <: AbstractAspect
    field::Type
    # ...
end
```

Defines an aspect that can add behavior to components through advice.
Features:
- State management through fields
- Multiple advice support
- Pointcut expression matching

### Advice Types

#### @before

```julia
@before pointcut begin
    # code to execute before the target
end
```

Creates advice that executes before the target function.
Parameters:
- `pointcut`: String pattern matching target methods
- `body`: Code block to execute

#### @after

```julia
@after pointcut begin
    # code to execute after the target
end
```

Creates advice that executes after the target function.
Parameters:
- `pointcut`: String pattern matching target methods
- `body`: Code block to execute

#### @around

```julia
@around pointcut begin
    # code to execute around the target
    result = proceed()
    # more code
    return result
end
```

Creates advice that executes both before and after the target function.
Parameters:
- `pointcut`: String pattern matching target methods
- `body`: Code block with `proceed()` call

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
    cycle::Vector{Type}
end
```

Thrown when a circular dependency is detected during component initialization. 