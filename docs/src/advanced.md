# Advanced Topics

## Component Type System

### Type Conversion

Jolien supports two ways to define components:

1. Direct inheritance from `AbstractComponent`:
```julia
@component struct DirectComponent <: AbstractComponent
    value::Int
end
```

2. Type conversion to `AbstractComponent`:
```julia
@component struct ConvertibleComponent
    name::String
end

# Implement conversion
Base.convert(::Type{AbstractComponent}, x::ConvertibleComponent) = x
```

This flexibility allows you to:
- Use existing types as components
- Avoid multiple inheritance issues
- Integrate with third-party types

### Circular Dependency Detection

Jolien automatically detects circular dependencies between components:

```julia
@component struct ComponentA
    b::Union{Nothing, Any}
    ComponentA() = new(nothing)
end

@component struct ComponentB
    a::ComponentA
end

# This works (no circular dependency yet)
a = ComponentA()
b = ComponentB(a)
register!(a)
register!(b)

# This creates a circular dependency
a.b = b
@test_throws CircularDependencyError check_circular_deps(a)
```

### Instance Management with Aspects

虽然 Jolien 不直接支持作用域管理，但我们可以使用切面来实现灵活的实例管理策略。这种方式比硬编码的作用域更加灵活，也更符合 Julia 的动态特性。

```julia
# 定义一个工厂切面
@aspect struct FactoryAspect
    factories::Dict{Symbol, Function}
    
    FactoryAspect() = new(Dict{Symbol, Function}())
end

let
    factory = FactoryAspect()
    
    # 注册一个需要每次创建新实例的组件
    @component struct PrototypeComponent
        id::Int
        PrototypeComponent() = new(rand(1:1000))
    end
    
    # 注册工厂函数
    factory.factories[Symbol("get_prototype")] = () -> PrototypeComponent()
    
    # 使用工厂切面创建实例
    get_prototype = @around get_instance begin
        if haskey(factory.factories, fn_name)
            return factory.factories[fn_name]()
        end
        proceed()
    end
    
    # 每次调用都会得到新实例
    instance1 = get_prototype(PrototypeComponent)
    instance2 = get_prototype(PrototypeComponent)
    @test instance1.id != instance2.id
end
```

这种方式提供了几个重要的优势：

1. **灵活性**：可以为不同的组件类型实现不同的实例化策略
2. **可扩展性**：容易添加新的工厂函数或修改现有的实例化逻辑
3. **可测试性**：工厂行为可以被轻松替换或模拟
4. **关注点分离**：实例管理逻辑完全由切面处理，不影响组件的核心逻辑

你还可以实现更复杂的实例管理策略，例如：

```julia
@aspect struct PoolingAspect
    pools::Dict{Symbol, Vector{Any}}
    max_pool_size::Int
    
    PoolingAspect(max_size::Int=10) = new(Dict{Symbol, Vector{Any}}(), max_size)
end

let
    pool = PoolingAspect(2)  # 最多保留2个实例
    
    @component struct PooledComponent
        id::Int
        PooledComponent() = new(rand(1:1000))
    end
    
    # 使用对象池管理实例
    get_pooled = @around get_instance begin
        component_key = Symbol(args[1])
        
        # 初始化对象池
        if !haskey(pool.pools, component_key)
            pool.pools[component_key] = []
        end
        
        # 尝试从池中获取实例
        if !isempty(pool.pools[component_key])
            return pop!(pool.pools[component_key])
        end
        
        # 创建新实例
        proceed()
    end
    
    # 定义返回实例到池中的函数
    function release(component::PooledComponent)
        component_key = Symbol(typeof(component))
        if length(pool.pools[component_key]) < pool.max_pool_size
            push!(pool.pools[component_key], component)
        end
    end
    
    # 测试对象池
    instance1 = get_pooled(PooledComponent)
    instance2 = get_pooled(PooledComponent)
    @test instance1.id != instance2.id
    
    # 返回实例到池中
    release(instance1)
    
    # 从池中获取实例
    instance3 = get_pooled(PooledComponent)
    @test instance3.id == instance1.id  # 复用了池中的实例
end
```

这个对象池的例子展示了如何使用切面实现更高级的实例管理策略。它可以：
- 限制创建的实例数量
- 重用不再使用的实例
- 提供实例生命周期的细粒度控制

这些示例说明了如何使用切面来实现各种实例管理策略，而不需要在框架核心中内置作用域支持。这种方式不仅更加灵活，而且更符合 Julia 的编程风格。

## Advanced Aspect Patterns

### Stateful Aspects

Create aspects that maintain state across function calls:

```julia
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

# Usage
let
    aspect = StateAspect()
    
    function test_fn(x::Int)
        return x * 2
    end
    
    enhanced_fn = @around test_fn begin
        result = proceed()
        record_call(aspect, fn_name, args, result)
        result
    end
    
    @test enhanced_fn(5) == 10
    @test aspect.states[Symbol("test_fn")] == 1  # Call count
end
```

### Nested Aspects

Apply multiple aspects to the same function in a specific order:

```julia
@aspect struct OuterAspect
    order::Vector{String}
    OuterAspect() = new(String[])
end

@aspect struct MiddleAspect
    order::Vector{String}
    MiddleAspect() = new(String[])
end

@aspect struct InnerAspect
    order::Vector{String}
    InnerAspect() = new(String[])
end

let
    execution_order = String[]
    
    base_fn = () -> begin
        push!(execution_order, "base")
        return "result"
    end
    
    # Create nested aspect chain
    inner_fn = @around base_fn begin
        push!(execution_order, "inner_before")
        result = proceed()
        push!(execution_order, "inner_after")
        result
    end
    
    middle_fn = @around inner_fn begin
        push!(execution_order, "middle_before")
        result = proceed()
        push!(execution_order, "middle_after")
        result
    end
    
    outer_fn = @around middle_fn begin
        push!(execution_order, "outer_before")
        result = proceed()
        push!(execution_order, "outer_after")
        result
    end
    
    # Test execution order
    @test outer_fn() == "result"
    @test execution_order == [
        "outer_before",
        "middle_before",
        "inner_before",
        "base",
        "inner_after",
        "middle_after",
        "outer_after"
    ]
end
```

### Context-Aware Aspects

Create aspects that can access and modify execution context:

```julia
@aspect struct ContextAspect
    context::Dict{Symbol, Any}
    
    ContextAspect() = new(Dict{Symbol, Any}())
end

let
    context = ContextAspect()
    
    function process_data(data::Vector{Int})
        sum(data)
    end
    
    # Add context information
    contextual_process = @around process_data begin
        # Store function context
        context.context[fn_name] = Dict(
            :start_time => time(),
            :args_size => length(args[1])
        )
        
        result = proceed()
        
        # Update context with results
        context.context[fn_name][:end_time] = time()
        context.context[fn_name][:result] = result
        
        result
    end
    
    # Test with data
    @test contextual_process([1, 2, 3]) == 6
    
    # Verify context
    @test haskey(context.context, Symbol("process_data"))
    @test context.context[Symbol("process_data")][:args_size] == 3
    @test context.context[Symbol("process_data")][:result] == 6
end
```

### Error Recovery Aspects

Create aspects that can handle and recover from errors:

```julia
@aspect struct RecoveryAspect
    fallback_values::Dict{Symbol, Any}
    errors::Vector{Exception}
    
    RecoveryAspect() = new(Dict{Symbol, Any}(), Exception[])
end

let
    recovery = RecoveryAspect()
    
    # Set fallback values
    recovery.fallback_values[Symbol("divide")] = 0
    
    function divide(a::Int, b::Int)
        a / b
    end
    
    # Add error recovery
    safe_divide = @around divide begin
        try
            proceed()
        catch e
            push!(recovery.errors, e)
            # Return fallback value
            get(recovery.fallback_values, fn_name, nothing)
        end
    end
    
    # Test normal case
    @test safe_divide(10, 2) == 5.0
    
    # Test error case with recovery
    @test safe_divide(1, 0) == 0  # Uses fallback value
    @test length(recovery.errors) == 1
    @test recovery.errors[1] isa DivideError
end 