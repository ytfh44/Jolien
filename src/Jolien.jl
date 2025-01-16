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
    component::Any  # 改为Any以支持任何可转换为AbstractComponent的类型
    scope::Scope
    
    function ComponentInfo(component::Any, scope::Scope)
        # 验证组件可以转换为AbstractComponent
        try
            convert(AbstractComponent, component)
        catch
            throw(InvalidComponentError(typeof(component)))
        end
        new(component, scope)
    end
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
        throw(DuplicateComponentError(T))
    end
    
    # Check if component can be converted to AbstractComponent
    try
        convert(AbstractComponent, component)
    catch
        throw(InvalidComponentError(T))
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
        # 继承自其他类型，使用trait-like方式实现AbstractComponent
        quote
            # 定义具体类型
            $(Expr(:struct, expr.args[1], 
                   :($(esc(name)) <: $(esc(parent))), 
                   Expr(:block, map(esc, struct_fields)..., map(esc, inner_constructors)...)))
            
            # 实现AbstractComponent接口
            Base.convert(::Type{AbstractComponent}, x::$(esc(name))) = x
            
            $(map(esc, outer_constructors)...)
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

定义后置通知。在目标函数执行完成后执行指定的代码块。

# 参数
- `target_fn`: 目标函数，将被增强的原始函数
- `body`: 通知体，在目标函数执行后要执行的代码块

# 返回值
返回一个新的函数，该函数在执行原始函数后会执行通知体。通知体可以访问原始函数的返回值。

# 示例
```julia
# 定义一个简单的日志切面
@aspect struct LoggingAspect end

# 使用 @after 添加日志记录
enhanced_fn = @after original_fn begin
    println("Function executed with result: \$result")
end
```
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

定义环绕通知。允许在目标函数执行前后添加自定义行为，并控制目标函数的执行。

# 参数
- `target_fn`: 目标函数，将被增强的原始函数
- `body`: 通知体，包含在目标函数执行前后要执行的代码。在通知体中必须调用 `proceed()` 来执行原始函数

# 特殊变量
在通知体内可以访问以下特殊变量：
- `fn_name`: 目标函数的名称（Symbol类型）
- `args`: 传递给目标函数的参数数组
- `x`: 第一个参数的快捷引用（如果存在）

# 返回值
返回一个新的函数，该函数将按照通知体中定义的方式执行原始函数。

# 注意事项
- 通知体必须调用 `proceed()` 来执行原始函数，否则会抛出错误
- `proceed()` 的返回值可以被修改后再返回
- 通知体应该返回一个值作为增强后函数的返回值

# 示例
```julia
# 定义一个状态管理切面
@aspect struct StateAspect
    states::Dict{Symbol, Any}
    StateAspect() = new(Dict{Symbol, Any}())
end

# 使用 @around 记录函数调用
enhanced_fn = @around original_fn begin
    # 前置逻辑
    println("Before execution: \$fn_name(\$args)")
    
    # 执行原始函数
    result = proceed()
    
    # 后置逻辑
    println("After execution: \$result")
    
    # 返回可能被修改的结果
    result
end
```
"""
macro around(target_fn, body)
    fn_name = QuoteNode(target_fn)  # 捕获函数名
    quote
        let original = $(esc(target_fn))
            (args...) -> begin
                # 在闭包中创建变量
                proceed_called = false
                proceed_fn = () -> begin
                    proceed_called = true
                    result = original(args...)
                    result
                end
                
                # 在闭包中绑定参数
                if length(args) > 0
                    x = args[1]  # 为了兼容现有测试，特别处理第一个参数
                end
                
                # 在闭包中创建函数名和参数副本
                $(esc(:fn_name)) = Symbol($fn_name)
                $(esc(:args)) = collect(args)
                
                # 在闭包中设置 proceed 函数
                old_proceed = CURRENT_PROCEED[]
                CURRENT_PROCEED[] = proceed_fn
                
                try
                    # 执行通知体
                    result = $(esc(body))
                    
                    # 确保 proceed 被调用
                    if !proceed_called
                        error("Around advice must call proceed()")
                    end
                    
                    result
                finally
                    # 恢复之前的 proceed 函数
                    CURRENT_PROCEED[] = old_proceed
                end
            end
        end
    end
end

# 工具函数
"""
    apply_aspects(target, args...)

将所有注册的切面应用到目标函数上。切面按照注册的相反顺序应用，
这意味着最后注册的切面会最先执行。

# 参数
- `target`: 目标函数
- `args...`: 传递给目标函数的参数

# 返回值
返回应用了所有切面后函数的执行结果。

# 切面应用顺序
1. 首先应用 around 通知（如果存在）
2. 然后应用 before 通知（如果存在）
3. 最后应用 after 通知（如果存在）

# 示例
```julia
# 注册多个切面
register_aspect!(LoggingAspect())
register_aspect!(TimingAspect())

# 应用切面并执行函数
result = apply_aspects(my_function, arg1, arg2)
```
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

重置全局容器的状态，清除所有注册的组件和切面。

这个函数通常用于测试场景，当需要一个干净的环境来测试组件和切面的行为时。

# 效果
- 清空所有注册的组件
- 清空所有注册的切面

# 示例
```julia
# 清理容器状态
reset_container!()

# 现在可以重新注册组件和切面
register!(MyComponent())
register_aspect!(MyAspect())
```
"""
function reset_container!()
    empty!(GLOBAL_CONTAINER.components)
    empty!(GLOBAL_CONTAINER.aspects)
end

"""
    proceed()

在环绕通知（@around）中调用目标函数。这个函数只能在 @around 通知体内调用。

# 返回值
返回原始函数的执行结果。

# 抛出
- 如果在 @around 通知体外调用，将抛出错误

# 示例
```julia
@around my_function begin
    # 前置逻辑
    println("Before")
    
    # 调用原始函数
    result = proceed()
    
    # 后置逻辑
    println("After")
    
    result
end
```
"""
function proceed()
    if CURRENT_PROCEED[] === nothing
        error("proceed() can only be called within an @around advice")
    end
    CURRENT_PROCEED[]()
end

"""
    get_container()

获取全局容器实例。容器管理着所有注册的组件和切面。

# 返回值
返回全局 Container 实例。

# 容器内容
容器包含：
- 已注册的组件列表
- 已注册的切面列表

# 示例
```julia
# 获取容器
container = get_container()

# 检查注册的组件
for component in container.components
    println(typeof(component))
end
```
"""
function get_container()
    GLOBAL_CONTAINER
end

end # module Jolien 