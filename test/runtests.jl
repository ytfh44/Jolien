using Test
using Jolien
using Jolien: reset_container!, proceed, GLOBAL_CONTAINER

@testset "Jolien.jl" begin
    # Include all test files
    include("component_test.jl")
    include("container_test.jl")
    include("aspect_test.jl")
    include("config_test.jl")
end 