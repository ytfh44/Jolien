using Documenter
using Jolien

makedocs(
    sitename = "Jolien",
    format = Documenter.HTML(),
    modules = [Jolien],
    pages = [
        "Home" => "index.md",
        "API Reference" => "api.md"
    ]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
deploydocs(
    repo = "github.com/ytfh44/Jolien.git",
    devbranch = "master"
) 