using Test
using Jolien

@testset "Component Registration and Retrieval" begin
    reset_container!()
    
    # Basic component
    @component struct SimpleComponent
        value::Int
    end
    
    # Test registration
    component = SimpleComponent(42)
    register!(component)
    
    # Test retrieval
    @test get_instance(SimpleComponent).value == 42
    
    # Test autowiring
    @autowired simple::SimpleComponent
    @test simple().value == 42
end

@testset "Component Dependencies" begin
    reset_container!()
    
    # Components with dependencies
    @component struct ConfigService
        host::String
    end
    
    @component struct DatabaseService
        config::ConfigService
        connected::Bool
        
        function DatabaseService(config::ConfigService)
            new(config, true)
        end
    end
    
    # Register components
    config = ConfigService("localhost")
    register!(config)
    
    db = DatabaseService(config)
    register!(db)
    
    # Test dependency injection
    @autowired db_service::DatabaseService
    @test db_service().config.host == "localhost"
    @test db_service().connected == true
end

@testset "Scoping Rules" begin
    reset_container!()
    
    # Test singleton scope
    @component struct SingletonComponent
        id::Int
        
        function SingletonComponent()
            new(rand(1:1000))
        end
    end
    
    singleton = SingletonComponent()
    register!(singleton)
    
    @autowired s1::SingletonComponent
    @autowired s2::SingletonComponent
    @test s1().id == s2().id
    
    # Test prototype scope
    @component struct PrototypeComponent
        id::Int
        
        function PrototypeComponent()
            new(rand(1:1000))
        end
    end
    
    prototype = PrototypeComponent()
    register!(prototype, scope=PrototypeScope())
    
    @autowired p1::PrototypeComponent
    @autowired p2::PrototypeComponent
    @test p1().id != p2().id
end

@testset "Circular Dependencies" begin
    reset_container!()
    
    # Define circular dependent components
    @component mutable struct ServiceA
        b::Union{Nothing, Any}
        
        ServiceA() = new(nothing)
    end

    @component mutable struct ServiceB
        a::Union{Nothing, Any}
        
        ServiceB() = new(nothing)
    end
    
    # Test circular dependency detection
    a = ServiceA()
    b = ServiceB()
    
    # Set up circular dependency
    a.b = b
    b.a = a
    
    register!(a)
    @test_throws CircularDependencyError register!(b)
end 