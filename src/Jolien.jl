module Jolien

using MacroTools
using DataStructures: OrderedDict
using Reexport

# 导出公共接口
export @component, @autowired, @aspect
export @before, @after, @around
export Container, get_instance, register!, get_container
export AbstractComponent, AbstractAspect
export before_advice, after_advice, around_advice
export Scope, SingletonScope, PrototypeScope
export reset_container!
export ComponentNotFoundError, DuplicateComponentError, InvalidComponentError, CircularDependencyError

# 错误类型定义
"""
    ComponentNotFoundError

当尝试获取未注册的组件时抛出。
"""
struct ComponentNotFoundError <: Exception
    type::Type
end

Base.showerror(io::IO, e::ComponentNotFoundError) = print(io, "Component not found: $(e.type)")

struct DuplicateComponentError <: Exception
    type::Type
end

struct InvalidComponentError <: Exception
    type::Type
end

"""
    CircularDependencyError

当检测到组件之间存在循环依赖时抛出。
"""
struct CircularDependencyError <: Exception
    message::String
end

Base.showerror(io::IO, e::CircularDependencyError) = print(io, e.message)

# 类型定义
abstract type AbstractComponent end
abstract type AbstractAspect end

# 作用域类型
abstract type Scope end
struct SingletonScope <: Scope end
struct PrototypeScope <: Scope end

"""
    ComponentInfo

组件信息，包含组件类型、作用域和实例。
"""
struct ComponentInfo
    component::AbstractComponent
    scope::Scope
end

# 容器类型
mutable struct Container
    components::OrderedDict{Symbol, ComponentInfo}
    aspects::Vector{AbstractAspect}
    
    Container() = new(OrderedDict{Symbol, ComponentInfo}(), Vector{AbstractAspect}())
end

# 全局容器实例
const GLOBAL_CONTAINER = Container()

# 全局变量用于存储当前的 proceed 函数
const CURRENT_PROCEED = Ref{Union{Function, Nothing}}(nothing)

"""
    get_instance(T::Type)

从容器中获取指定类型的实例。
"""
function get_instance(T::Type)
    if !haskey(GLOBAL_CONTAINER.components, Symbol(T))
        throw(ComponentNotFoundError(T))
    end
    
    info = GLOBAL_CONTAINER.components[Symbol(T)]
    if info.scope isa SingletonScope
        return info.component
    else
        # 对于原型作用域，创建新实例
        return T()
    end
end

"""
    check_circular_deps(component, visited=Set{Any}())

检查组件是否存在循环依赖。
"""
function check_circular_deps(component, visited=Set{Any}())
    T = typeof(component)
    
    # Add current component to visited set
    push!(visited, component)
    
    # Check each field's value
    for field in fieldnames(T)
        field_value = getfield(component, field)
        
        # If field value is a component, check for circular dependency
        if field_value !== nothing && field_value isa AbstractComponent
            # If the field value is in visited set, we have a circular dependency
            if field_value in visited
                throw(CircularDependencyError("Circular dependency detected: $(T) -> $(typeof(field_value))"))
            end
            
            # If the field value is registered, check its dependencies
            if haskey(GLOBAL_CONTAINER.components, Symbol(typeof(field_value)))
                check_circular_deps(field_value, copy(visited))
            end
        end
    end
end

"""
    register!(component; scope::Scope=SingletonScope())

注册一个组件到容器中。
"""
function register!(component; scope::Scope=SingletonScope())
    T = typeof(component)
    
    # Check if component is already registered
    if haskey(GLOBAL_CONTAINER.components, Symbol(T))
        throw(ErrorException("Component already registered: $T"))
    end
    
    # Check if component inherits from AbstractComponent
    if !(T <: AbstractComponent)
        throw(ErrorException("Invalid component type: $T"))
    end
    
    # Check for circular dependencies in the component being registered
    check_circular_deps(component)
    
    # Register the component
    GLOBAL_CONTAINER.components[Symbol(T)] = ComponentInfo(component, scope)
    
    return component
end

"""
    @component

将类型标记为组件。
"""
macro component(expr)
    # 首先检查是否是结构体定义
    if !@capture(expr, (mutable struct T_ fields__ end) | (struct T_ fields__ end))
        error("@component only works with struct definitions")
    end
    
    # 检查是否有泛型参数
    if @capture(T, T2_{params__})
        error("Generic components are not supported")
    end
    
    # 提取实际的类型名和父类型（如果有的话）
    local name, parent
    if @capture(T, N_ <: P_)
        name = N
        parent = P
    else
        name = T
        parent = :AbstractComponent
    end
    
    # 分离字段和方法定义
    struct_fields = []
    inner_constructors = []
    outer_constructors = []
    
    for field in fields
        if @capture(field, (function fname_(args__) body__ end) | (fname_(args__) = body_))
            if fname === name
                # 内部构造函数
                push!(inner_constructors, field)
            else
                # 其他方法
                push!(outer_constructors, field)
            end
        else
            # 普通字段
            push!(struct_fields, field)
        end
    end
    
    # 构造结果
    if parent === :AbstractComponent
        # 直接继承 AbstractComponent
        quote
            $(Expr(:struct, expr.args[1], 
                   :($(esc(name)) <: AbstractComponent), 
                   Expr(:block, map(esc, struct_fields)..., map(esc, inner_constructors)...)))
            
            $(map(esc, outer_constructors)...)
        end
    else
        # 创建中间类型来实现多重继承
        quote
            abstract type $(esc(Symbol("$(name)Component"))) <: AbstractComponent end
            
            $(Expr(:struct, expr.args[1], 
                   :($(esc(name)) <: $(esc(parent))), 
                   Expr(:block, map(esc, struct_fields)..., map(esc, inner_constructors)...)))
            
            $(map(esc, outer_constructors)...)
            
            Base.@eval Main begin
                $(esc(name)) <: $(esc(Symbol("$(name)Component")))
            end
        end
    end
end

"""
    @autowired

注入依赖。
"""
macro autowired(field)
    @capture(field, name_::type_) || error("@autowired requires type annotation")
    
    quote
        function $(esc(name))()
            get_instance($(esc(type)))
        end
    end
end

"""
    @aspect

定义切面。
"""
macro aspect(expr)
    if @capture(expr, struct T_{params__} fields__ end)
        error("Generic aspects are not supported")
    elseif !@capture(expr, struct T_ fields__ end)
        error("@aspect only works with struct definitions")
    end
    
    # 提取字段和构造函数
    struct_fields = []
    constructors = []
    
    for field in fields
        if @capture(field, function fname_(args__) body__ end)
            push!(constructors, field)
        else
            push!(struct_fields, field)
        end
    end
    
    quote
        struct $(esc(T)) <: AbstractAspect
            $(map(esc, struct_fields)...)
            $(map(esc, constructors)...)
        end
        push!(GLOBAL_CONTAINER.aspects, $(esc(T))())
    end
end

# 通知函数定义
"""
    before_advice(f, advice)

创建前置通知。
"""
function before_advice(target, advice)
    return function(args...)
        advice()
        target(args...)
    end
end

"""
    after_advice(f, advice)

创建后置通知。
"""
function after_advice(target, advice)
    return function(args...)
        result = target(args...)
        advice()
        result
    end
end

"""
    around_advice(f, advice)

创建环绕通知。
"""
function around_advice(target, advice)
    return function(args...)
        local result
        local proceed_called = false
        
        # 创建 proceed 函数
        proceed_fn = () -> begin
            proceed_called = true
            result = target(args...)
            return result
        end
        
        # 设置当前的 proceed 函数
        old_proceed = CURRENT_PROCEED[]
        CURRENT_PROCEED[] = proceed_fn
        
        try
            # 执行通知
            advice()
            
            # 如果通知没有调用 proceed,自动调用
            if !proceed_called
                proceed_fn()
            end
        finally
            # 恢复之前的 proceed 函数
            CURRENT_PROCEED[] = old_proceed
        end
        
        return result
    end
end

"""
    @before(target_fn, body)

定义前置通知。
"""
macro before(target_fn, body)
    quote
        let original = $(esc(target_fn))
            (args...) -> begin
                $(esc(body))
                original(args...)
            end
        end
    end
end

"""
    @after(target_fn, body)

定义后置通知。
"""
macro after(target_fn, body)
    quote
        let original = $(esc(target_fn))
            (args...) -> begin
                result = original(args...)
                $(esc(body))
                result
            end
        end
    end
end

"""
    @around(target_fn, body)

定义环绕通知。
"""
macro around(target_fn, body)
    quote
        let original = $(esc(target_fn))
            (args...) -> begin
                local proceed_called = false
                local result
                
                # 定义 proceed 函数
                proceed_fn = () -> begin
                    proceed_called = true
                    result = original(args...)
                    return result
                end
                
                # 设置当前的 proceed 函数
                old_proceed = CURRENT_PROCEED[]
                CURRENT_PROCEED[] = proceed_fn
                
                try
                    # 执行通知
                    result = $(esc(body))
                    
                    # 如果通知没有调用 proceed，自动调用
                    if !proceed_called
                        result = proceed_fn()
                    end
                finally
                    # 恢复之前的 proceed 函数
                    CURRENT_PROCEED[] = old_proceed
                end
                
                return result
            end
        end
    end
end

# 工具函数
"""
    apply_aspects(target, args...)

应用切面到目标函数。
"""
function apply_aspects(target, args...)
    # 按照注册顺序反向应用切面
    for aspect in reverse(GLOBAL_CONTAINER.aspects)
        # 先应用 around 通知
        if hasmethod(around_advice, (typeof(target), typeof(aspect)))
            target = around_advice(target, aspect)
        end
        # 然后应用 before 和 after 通知
        if hasmethod(before_advice, (typeof(target), typeof(aspect)))
            target = before_advice(target, aspect)
        end
        if hasmethod(after_advice, (typeof(target), typeof(aspect)))
            target = after_advice(target, aspect)
        end
    end
    target(args...)
end

"""
    reset_container!()

重置全局容器状态。
"""
function reset_container!()
    empty!(GLOBAL_CONTAINER.components)
    empty!(GLOBAL_CONTAINER.aspects)
end

"""
    proceed()

在环绕通知中调用目标函数。
"""
function proceed()
    if CURRENT_PROCEED[] === nothing
        error("proceed() can only be called within an @around advice")
    end
    CURRENT_PROCEED[]()
end

"""
    get_container()

获取全局容器实例。
"""
function get_container()
    GLOBAL_CONTAINER
end

end # module Jolien 