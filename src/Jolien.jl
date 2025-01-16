module Jolien

using MacroTools
using DataStructures: OrderedDict
using Reexport

# 导出公共接口
export @component, @autowired, @aspect
export @before, @after, @around
export Container, get_instance, register!
export AbstractComponent, AbstractAspect
export before_advice, after_advice, around_advice
export Scope, SingletonScope, PrototypeScope  # 导出作用域类型

# 类型定义
abstract type AbstractComponent end
abstract type AbstractAspect end

# 作用域类型
abstract type Scope end
struct SingletonScope <: Scope end
struct PrototypeScope <: Scope end

# 组件注册信息
mutable struct ComponentInfo
    component_type::Type
    scope::Scope
    instance::Union{Nothing, Any}  # 用于存储单例实例
    factory::Function
end

# 容器类型
mutable struct Container
    components::OrderedDict{Symbol, ComponentInfo}
    aspects::Vector{AbstractAspect}
    
    Container() = new(OrderedDict{Symbol, ComponentInfo}(), Vector{AbstractAspect}())
end

# 全局容器实例
const GLOBAL_CONTAINER = Container()

"""
    get_instance(T::Type)

从容器中获取指定类型的实例。
"""
function get_instance(T::Type)
    haskey(GLOBAL_CONTAINER.components, Symbol(T)) || error("Component not found: $T")
    info = GLOBAL_CONTAINER.components[Symbol(T)]
    
    if info.scope isa SingletonScope
        # 单例模式：返回存储的实例
        return info.instance
    elseif info.scope isa PrototypeScope
        # 原型模式：每次返回新实例
        return info.factory()
    end
end

"""
    register!(component::T; scope::Scope = SingletonScope()) where T

向容器注册一个组件。
"""
function register!(component::T; scope::Scope = SingletonScope()) where T <: AbstractComponent
    component_type = typeof(component)
    info = if scope isa SingletonScope
        # 单例模式：直接存储实例
        ComponentInfo(component_type, scope, component, () -> component)
    else
        # 原型模式：存储工厂函数
        ComponentInfo(component_type, scope, nothing, () -> deepcopy(component))
    end
    GLOBAL_CONTAINER.components[Symbol(component_type)] = info
    component
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
        advice()
        result = target(args...)
        advice()
        result
    end
end

"""
    @before(pointcut)

定义前置通知。
"""
macro before(pointcut, body)
    quote
        target -> before_advice(target, () -> $(esc(body)))
    end
end

"""
    @after(pointcut)

定义后置通知。
"""
macro after(pointcut, body)
    quote
        target -> after_advice(target, () -> $(esc(body)))
    end
end

"""
    @around(pointcut)

定义环绕通知。
"""
macro around(pointcut, body)
    quote
        target -> around_advice(target, () -> $(esc(body)))
    end
end

# 工具函数
"""
    apply_aspects(target, args...)

应用切面到目标函数。
"""
function apply_aspects(target, args...)
    for aspect in GLOBAL_CONTAINER.aspects
        # 应用切面逻辑
        target = aspect(target)
    end
    target(args...)
end

end # module Jolien 