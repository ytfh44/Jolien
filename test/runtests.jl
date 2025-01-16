using Test
using Jolien
using Jolien: GLOBAL_CONTAINER

@testset "Jolien.jl" begin
    # 重置容器
    function reset_container!()
        empty!(GLOBAL_CONTAINER.components)
        empty!(GLOBAL_CONTAINER.aspects)
    end

    @testset "Component Definition" begin
        reset_container!()
        
        # 测试基本组件定义
        @component struct SimpleComponent
            value::String
        end
        
        @test supertype(SimpleComponent) == AbstractComponent
        
        # 测试嵌套组件定义
        @component struct NestedComponent
            simple::SimpleComponent
            count::Int
        end
        
        @test supertype(NestedComponent) == AbstractComponent
    end

    @testset "Component Registration and Retrieval" begin
        reset_container!()
        
        @component struct DatabaseService
            url::String
            port::Int
        end
        
        # 测试注册
        db = DatabaseService("localhost", 5432)
        register!(db)
        
        # 测试检索
        @test get_instance(DatabaseService) === db
        @test get_instance(DatabaseService).url == "localhost"
        @test get_instance(DatabaseService).port == 5432
        
        # 测试重复注册
        db2 = DatabaseService("127.0.0.1", 3306)
        register!(db2)
        @test get_instance(DatabaseService) === db2
        
        # 测试未注册组件的错误处理
        @test_throws ErrorException get_instance(String)
    end

    @testset "Dependency Injection" begin
        reset_container!()
        
        # 定义服务层次结构
        @component struct Repository
            connection_string::String
        end
        
        @component struct Service
            repo::Repository
            cache_enabled::Bool
        end
        
        @component struct Controller
            service::Service
            auth_token::String
        end
        
        # 测试层次化依赖注入
        repo = Repository("postgresql://localhost:5432")
        service = Service(repo, true)
        controller = Controller(service, "token123")
        
        register!(repo)
        register!(service)
        register!(controller)
        
        # 测试自动装配
        @autowired repo_instance::Repository
        @test repo_instance().connection_string == "postgresql://localhost:5432"
        
        @autowired service_instance::Service
        @test service_instance().cache_enabled == true
        @test service_instance().repo === repo
        
        @autowired controller_instance::Controller
        @test controller_instance().auth_token == "token123"
        @test controller_instance().service === service
    end

    @testset "Aspect Oriented Programming" begin
        reset_container!()
        
        # 定义用于测试的组件
        @component struct UserService
            users::Vector{String}
            
            function UserService()
                new(String[])
            end
        end
        
        # 定义多个切面
        @aspect struct LoggingAspect
            log_count::Ref{Int}
            
            function LoggingAspect()
                new(Ref(0))
            end
        end
        
        @aspect struct TimingAspect
            execution_times::Vector{Float64}
            
            function TimingAspect()
                new(Float64[])
            end
        end
        
        # 测试前置通知
        let
            call_count = 0
            test_fn = () -> "result"
            advice = @before "test" begin
                call_count += 1
            end
            logged_fn = advice(test_fn)
            
            @test logged_fn() == "result"
            @test call_count == 1
        end
        
        # 测试后置通知
        let
            result_captured = nothing
            test_fn = () -> "after_test"
            advice = @after "test" begin
                result_captured = "captured"
            end
            logged_fn = advice(test_fn)
            
            @test logged_fn() == "after_test"
            @test result_captured == "captured"
        end
        
        # 测试环绕通知
        let
            steps = String[]
            test_fn = () -> (push!(steps, "execution"); "around_result")
            advice = @around "test" begin
                push!(steps, "around")
            end
            logged_fn = advice(test_fn)
            
            @test logged_fn() == "around_result"
            @test steps == ["around", "execution", "around"]
        end
        
        # 测试多重切面
        let
            order = String[]
            test_fn = () -> (push!(order, "main"); "multi_result")
            
            before_advice = @before "test" begin
                push!(order, "before1")
            end
            
            after_advice = @after "test" begin
                push!(order, "after1")
            end
            
            around_advice = @around "test" begin
                push!(order, "around_start")
            end
            
            fn = test_fn |> before_advice |> after_advice |> around_advice
            
            @test fn() == "multi_result"
            @test order == ["around_start", "before1", "main", "after1", "around_start"]
        end
    end

    @testset "Container Management" begin
        reset_container!()
        
        # 测试容器初始化状态
        @test isempty(GLOBAL_CONTAINER.components)
        @test isempty(GLOBAL_CONTAINER.aspects)
        
        # 测试组件注册和检索
        @component struct ConfigService
            settings::Dict{String, Any}
            
            function ConfigService(settings::Dict{String, Any})
                new(settings)
            end
        end
        
        config = ConfigService(Dict{String, Any}("key" => "value"))
        register!(config)
        
        @test haskey(GLOBAL_CONTAINER.components, Symbol(ConfigService))
        @test get_instance(ConfigService) === config
        
        # 测试切面注册
        @aspect struct MetricsAspect
            metrics::Dict{String, Int}
            
            function MetricsAspect()
                new(Dict{String, Int}())
            end
        end
        
        @test length(GLOBAL_CONTAINER.aspects) == 1
        @test first(GLOBAL_CONTAINER.aspects) isa MetricsAspect
    end

    @testset "Error Handling" begin
        reset_container!()
        
        # 测试获取未注册组件
        @test_throws ErrorException get_instance(String)
        
        # 测试错误的组件定义
        @test_throws LoadError @eval begin
            @component struct InvalidComponent{T}
                field::T
            end
        end
        
        # 测试错误的切面定义
        @test_throws LoadError @eval begin
            @aspect struct InvalidAspect{T}
                field::T
            end
        end
        
        # 测试错误的自动装配
        @test_throws LoadError @eval @autowired invalid_field
    end

    @testset "Lifecycle Management" begin
        reset_container!()
        
        # 测试初始化顺序
        init_order = String[]
        
        @component struct TestDatabase
            name::String
            
            function TestDatabase(name::String)
                push!(init_order, "TestDatabase")
                new(name)
            end
        end
        
        @component struct TestCache
            capacity::Int
            
            function TestCache(capacity::Int)
                push!(init_order, "TestCache")
                new(capacity)
            end
        end
        
        @component struct TestService
            db::TestDatabase
            cache::TestCache
            
            function TestService(db::TestDatabase, cache::TestCache)
                push!(init_order, "TestService")
                new(db, cache)
            end
        end
        
        # 按依赖顺序注册组件
        db = TestDatabase("test_db")
        cache = TestCache(1000)
        service = TestService(db, cache)
        
        register!(db)
        register!(cache)
        register!(service)
        
        @test init_order == ["TestDatabase", "TestCache", "TestService"]
        
        # 测试循环依赖检测
        @test_throws ErrorException begin
            # 预先声明类型
            abstract type AbstractTestA end
            abstract type AbstractTestB end
            
            @component mutable struct TestA <: AbstractTestA
                b::Union{Nothing, AbstractTestB}
                TestA() = new(nothing)
            end
            
            @component mutable struct TestB <: AbstractTestB
                a::AbstractTestA
                TestB(a::AbstractTestA) = new(a)
            end
            
            # 创建循环依赖的实例
            a = TestA()
            register!(a)
            b = TestB(a)
            register!(b)
            a.b = b
            
            # 尝试获取实例时应该检测到循环依赖
            get_instance(TestA)
        end
    end

    @testset "Scoping Rules" begin
        reset_container!()
        
        # 测试单例作用域
        @component mutable struct SingletonService
            value::Int
            SingletonService() = new(0)
        end
        
        singleton = SingletonService()
        register!(singleton)  # 默认为单例作用域
        
        singleton1 = get_instance(SingletonService)
        singleton1.value = 1
        singleton2 = get_instance(SingletonService)
        
        @test singleton1.value == 1
        @test singleton2.value == 1
        @test singleton1 === singleton2
        
        # 测试原型作用域
        @component mutable struct PrototypeService
            value::Int
            PrototypeService() = new(0)
        end
        
        proto = PrototypeService()
        register!(proto, scope=PrototypeScope())
        
        proto1 = get_instance(PrototypeService)
        proto1.value = 1
        proto2 = get_instance(PrototypeService)
        
        @test proto2.value == 0  # 新实例应该有初始值
        @test proto2 !== proto1  # 应该是不同的实例
    end

    @testset "Conditional Configuration" begin
        reset_container!()
        
        # 测试基于环境的条件装配
        ENV["APP_ENV"] = "test"
        
        @component struct ConfigProvider
            env::String
            settings::Dict{String, Any}
            
            function ConfigProvider()
                env = get(ENV, "APP_ENV", "development")
                settings = if env == "test"
                    Dict{String, Any}("db" => "test_db", "port" => 5000)
                else
                    Dict{String, Any}("db" => "prod_db", "port" => 80)
                end
                new(env, settings)
            end
        end
        
        config = ConfigProvider()
        register!(config)
        
        @test get_instance(ConfigProvider).env == "test"
        @test get_instance(ConfigProvider).settings["db"] == "test_db"
        
        # 测试组件优先级
        @component struct MessageService
            priority::Int
            message::String
            
            function MessageService(priority::Int, message::String)
                new(priority, message)
            end
        end
        
        low_priority = MessageService(1, "low")
        high_priority = MessageService(2, "high")
        
        register!(low_priority)
        register!(high_priority)  # 后注册的应该覆盖先注册的
        
        @test get_instance(MessageService).message == "high"
    end
end 