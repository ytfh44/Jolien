using Test
using Jolien

@testset "Container Management" begin
    # Test container reset
    reset_container!()
    @test length(get_container().components) == 0
    @test length(get_container().aspects) == 0
    
    # Test component registration
    @component struct TestComponent
        value::Int
    end
    
    component = TestComponent(42)
    register!(component)
    
    @test length(get_container().components) == 1
    @test haskey(get_container().components, Symbol(TestComponent))
    
    # Test component retrieval
    retrieved = get_instance(TestComponent)
    @test retrieved.value == 42
    
    # Test component not found
    @component struct UnregisteredComponent
        value::Int
    end
    
    @test_throws ComponentNotFoundError get_instance(UnregisteredComponent)
end

@testset "Container Lifecycle" begin
    reset_container!()
    
    # Test initialization order
    init_order = String[]
    
    @component struct FirstComponent
        function FirstComponent()
            push!(init_order, "First")
            new()
        end
    end
    
    @component struct SecondComponent
        first::FirstComponent
        
        function SecondComponent(first::FirstComponent)
            push!(init_order, "Second")
            new(first)
        end
    end
    
    @component struct ThirdComponent
        second::SecondComponent
        
        function ThirdComponent(second::SecondComponent)
            push!(init_order, "Third")
            new(second)
        end
    end
    
    # Register in reverse order
    first = FirstComponent()
    second = SecondComponent(first)
    third = ThirdComponent(second)
    
    register!(third)
    register!(second)
    register!(first)
    
    # Verify initialization order
    @test init_order == ["First", "Second", "Third"]
end

@testset "Container Error Handling" begin
    reset_container!()
    
    # Test duplicate registration
    @component struct DuplicateComponent
        value::Int
    end
    
    component1 = DuplicateComponent(1)
    component2 = DuplicateComponent(2)
    
    register!(component1)
    @test_throws DuplicateComponentError register!(component2)
    
    # Test invalid component type
    struct NotAComponent
        value::Int
    end
    
    invalid = NotAComponent(1)
    @test_throws InvalidComponentError register!(invalid)
end

@testset "Container Scoping" begin
    reset_container!()
    
    # Test singleton scope
    @component struct SingletonTest
        id::Int
        
        function SingletonTest()
            new(rand(1:1000))
        end
    end
    
    singleton = SingletonTest()
    register!(singleton, scope=SingletonScope())
    
    id1 = get_instance(SingletonTest).id
    id2 = get_instance(SingletonTest).id
    @test id1 == id2
    
    # Test prototype scope
    @component struct PrototypeTest
        id::Int
        
        function PrototypeTest()
            new(rand(1:1000))
        end
    end
    
    prototype = PrototypeTest()
    register!(prototype, scope=PrototypeScope())
    
    id1 = get_instance(PrototypeTest).id
    id2 = get_instance(PrototypeTest).id
    @test id1 != id2
end 