# API Reference

## Components

### @component

```julia
@component struct MyComponent
    field::Type
end
```

Marks a struct as a component, making it available for dependency injection. Components can inherit from other types while still being managed by the container.

### register!

```julia
register!(component::T; scope::Scope = SingletonScope()) where T <: AbstractComponent
```

Registers a component instance with the container. The scope parameter determines how the component is managed:
- `SingletonScope()`: A single instance is shared (default)
- `PrototypeScope()`: A new instance is created each time

### get_instance

```julia
get_instance(T::Type)
```

Retrieves an instance of the specified component type from the container.

## Dependency Injection

### @autowired

```julia
@autowired service::ServiceType
```

Creates a function that retrieves the specified component from the container. The function name will be the same as the field name.

## Aspects

### @aspect

```julia
@aspect struct MyAspect
    field::Type
end
```

Defines an aspect that can add behavior to components through advice.

### Advice Types

#### @before

```julia
@before pointcut begin
    # code to execute before the target
end
```

Creates advice that executes before the target function.

#### @after

```julia
@after pointcut begin
    # code to execute after the target
end
```

Creates advice that executes after the target function.

#### @around

```julia
@around pointcut begin
    # code to execute before and after the target
end
```

Creates advice that executes both before and after the target function.

## Scoping

### Scope Types

- `SingletonScope`: Ensures only one instance exists
- `PrototypeScope`: Creates a new instance each time

## Container

### Container

```julia
mutable struct Container
    components::OrderedDict{Symbol, ComponentInfo}
    aspects::Vector{AbstractAspect}
end
```

The main container that manages all components and aspects. Usually accessed through the global `GLOBAL_CONTAINER` instance.

### ComponentInfo

```julia
mutable struct ComponentInfo
    component_type::Type
    scope::Scope
    instance::Union{Nothing, Any}
    factory::Function
end
```

Internal structure used by the container to manage component instances and their lifecycle. 