using Test
using Jolien
using Jolien: check_circular_deps

@testset "Advanced Component Features" begin
    reset_container!()
    
    # Test circular dependency detection
    @testset "Circular Dependency Detection" begin
        @component mutable struct ComponentA
            b::Union{Nothing, Any}
            ComponentA() = new(nothing)
        end
        
        @component mutable struct ComponentB
            a::ComponentA
        end
        
        a = ComponentA()
        b = ComponentB(a)
        
        # This should work (no circular dependency yet)
        register!(a)
        register!(b)
        
        # Now create a circular dependency
        a.b = b
        
        # Test circular dependency detection
        @test_throws CircularDependencyError check_circular_deps(a)
    end
    
    # Test component inheritance
    @testset "Component Inheritance" begin
        abstract type BaseService end
        
        @component struct ConcreteService <: BaseService
            name::String
        end
        
        service = ConcreteService("test")
        register!(service)
        
        # Test type relationships
        @test service isa BaseService
        @test convert(AbstractComponent, service) === service
        
        # Test component retrieval
        retrieved = get_instance(ConcreteService)
        @test retrieved.name == "test"
        @test retrieved === service  # Should be the same instance
    end
    
    # Test component with complex constructor
    @testset "Complex Constructor" begin
        @component struct ConfiguredComponent
            config::Dict{String, Any}
            initialized::Bool
            
            function ConfiguredComponent(;config=Dict{String, Any}())
                merged = merge(Dict{String, Any}(
                    "default_key" => "default_value"
                ), config)
                new(merged, true)
            end
        end
        
        component = ConfiguredComponent(config=Dict("custom_key" => "custom_value"))
        register!(component)
        
        retrieved = get_instance(ConfiguredComponent)
        @test retrieved.config["default_key"] == "default_value"
        @test retrieved.config["custom_key"] == "custom_value"
        @test retrieved.initialized == true
    end
end

@testset "Advanced Aspect Features" begin
    reset_container!()
    
    # Test aspect with state management
    @testset "Stateful Aspects" begin
        @aspect struct StateAspect
            states::Dict{Symbol, Any}
            
            StateAspect() = new(Dict{Symbol, Any}())
        end
        
        # 在类型定义之外定义方法
        function record_call(aspect::StateAspect, fn_name::Symbol, args::Vector, result)
            # 更新调用次数
            aspect.states[fn_name] = get(aspect.states, fn_name, 0) + 1
            
            # 更新参数历史
            args_key = Symbol(:args_, fn_name)
            if !haskey(aspect.states, args_key)
                aspect.states[args_key] = []
            end
            push!(aspect.states[args_key], args...)
            
            # 更新结果历史
            results_key = Symbol(:results_, fn_name)
            if !haskey(aspect.states, results_key)
                aspect.states[results_key] = []
            end
            push!(aspect.states[results_key], result)
            
            return result
        end
        
        let
            aspect = StateAspect()
            
            function test_fn(x::Int)
                return x * 2
            end
            
            # Complex around advice that maintains state
            enhanced_fn = @around test_fn begin
                result = proceed()
                record_call(aspect, fn_name, args, result)
                return result
            end
            
            @test enhanced_fn(5) == 10
            @test enhanced_fn(3) == 6
            
            @test aspect.states[Symbol("test_fn")] == 2  # Call count
            @test aspect.states[Symbol(:args_, "test_fn")] == [5, 3]  # Argument history
            @test aspect.states[Symbol(:results_, "test_fn")] == [10, 6]  # Result history
        end
    end
    
    # Test nested aspect chain
    @testset "Nested Aspects" begin
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
            outer = OuterAspect()
            middle = MiddleAspect()
            inner = InnerAspect()
            
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
    end
end 