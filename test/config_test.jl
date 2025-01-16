using Test
using Jolien

@testset "Environment Configuration" begin
    # Test environment-based configuration
    @component struct EnvConfig
        mode::String
        debug::Bool
        
        function EnvConfig()
            mode = get(ENV, "APP_ENV", "development")
            debug = mode == "development"
            new(mode, debug)
        end
    end
    
    # Test with default environment
    reset_container!()
    config = EnvConfig()
    register!(config)
    
    @test get_instance(EnvConfig).mode == "development"
    @test get_instance(EnvConfig).debug == true
    
    # Test with custom environment
    withenv("APP_ENV" => "production") do
        reset_container!()
        config = EnvConfig()
        register!(config, scope=PrototypeScope())
        @test get_instance(EnvConfig).mode == "production"
        @test get_instance(EnvConfig).debug == false
    end
end

@testset "Conditional Configuration" begin
    # Test conditional component registration
    @component struct DatabaseConfig
        url::String
        pool_size::Int
        
        function DatabaseConfig()
            if get(ENV, "APP_ENV", "development") == "production"
                new("postgresql://prod-db:5432", 50)
            else
                new("postgresql://localhost:5432", 10)
            end
        end
    end
    
    # Test development config
    reset_container!()
    config = DatabaseConfig()
    register!(config)
    
    @test get_instance(DatabaseConfig).url == "postgresql://localhost:5432"
    @test get_instance(DatabaseConfig).pool_size == 10
    
    # Test production config
    withenv("APP_ENV" => "production") do
        reset_container!()
        config = DatabaseConfig()
        register!(config, scope=PrototypeScope())
        @test get_instance(DatabaseConfig).url == "postgresql://prod-db:5432"
        @test get_instance(DatabaseConfig).pool_size == 50
    end
end

@testset "Priority Configuration" begin
    reset_container!()
    
    # Components with initialization priority
    init_order = String[]
    
    @component struct LogConfig
        function LogConfig()
            push!(init_order, "LogConfig")
            new()
        end
    end
    
    @component struct CacheConfig
        function CacheConfig()
            push!(init_order, "CacheConfig")
            new()
        end
    end
    
    @component struct AppConfig
        log::LogConfig
        cache::CacheConfig
        
        function AppConfig(log::LogConfig, cache::CacheConfig)
            push!(init_order, "AppConfig")
            new(log, cache)
        end
    end
    
    # Register in specific order
    log = LogConfig()
    cache = CacheConfig()
    app = AppConfig(log, cache)
    
    register!(log)
    register!(cache)
    register!(app)
    
    # Verify initialization order
    @test init_order == ["LogConfig", "CacheConfig", "AppConfig"]
end

@testset "Hot Reloading" begin
    reset_container!()
    
    # Test component that supports hot reloading
    @component mutable struct HotConfig
        settings::Dict{String, Any}
        
        function HotConfig()
            new(Dict{String, Any}("timeout" => 30))
        end
    end
    
    # Initial configuration
    config = HotConfig()
    register!(config)
    
    @test get_instance(HotConfig).settings["timeout"] == 30
    
    # Update configuration
    hot_config = get_instance(HotConfig)
    hot_config.settings["timeout"] = 60
    hot_config.settings["retry"] = 3
    
    # Verify updates
    @test get_instance(HotConfig).settings["timeout"] == 60
    @test get_instance(HotConfig).settings["retry"] == 3
end 