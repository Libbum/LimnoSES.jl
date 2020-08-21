using Pkg
Pkg.activate(@__DIR__)
cd(@__DIR__)
Pkg.update()

push!(LOAD_PATH, "../src/")
const CI = get(ENV, "CI", nothing) == "true"

using Documenter, LimnoSES

makedocs(
    modules = [LimnoSES],
    sitename = "LimnoSES.jl",
    authors = "Tim DuBois",
    format = Documenter.HTML(prettyurls = CI),
    pages = [
        "Introduction" => "index.md",
        "Public API" => "api.md",
        "Developer Docs" => "dev.md",
    ],
)

if CI
    deploydocs(
        repo = "github.com/Libbum/LimnoSES.jl.git",
        target = "build",
        push_preview = true,
    )
end

