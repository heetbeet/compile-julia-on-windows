using LibGit2

function input(prompt::String="")::String
    print(prompt)
    return chomp(readline())
end


function ask_yn(message)
    answer = nothing
    while true
        answer = lowercase(input(message))
        if answer == "y" || answer == "n"
            return answer
        end
    end
end


println("This script will:")
println(" - download and install Cygwin portable")
println(" - download and install Cygwin dependancies")
println(" - clone Julia to ", @__DIR__, "\\julia")
println(" - create a proxy make script ", @__DIR__, "\\make-julia.bat")
println("")

if ask_yn("Do you want to continue [y/n]? ") == "n" exit() end

mkpath(joinpath(@__DIR__, "temp"))

julia_repo = input("Please type in the link to the julia git repo to clone...\n"*
                   "Leave empty for https://github.com/JuliaLang/julia.git, or [n] for skipping this step: ")

if lowercase(strip(julia_repo)) != "n"
    if strip(julia_repo) == ""
        julia_repo = "https://github.com/JuliaLang/julia.git"
    end
    println("Cloning into $(joinpath(@__DIR__, "julia"))")
    LibGit2.clone(strip(julia_repo), joinpath(@__DIR__, "julia"))
end


make_txt = raw"""
@echo 'XC_HOST = x86_64-w64-mingw32' > "%~dp0\julia\Make.user"
@call "%~dp0\cygwin-portable.cmd" -c "make -C '%~dp0\julia'" %*
"""

open(joinpath(@__DIR__, "make-julia.cmd"), "w") do f
    write(f, make_txt)
end

download("https://raw.githubusercontent.com/vegardit/cygwin-portable-installer/master/cygwin-portable-installer.cmd",
        joinpath(@__DIR__, "temp", "cygwin-portable-installer.cmd"))

download("https://raw.githubusercontent.com/JuliaLang/julia/master/doc/build/windows.md",
         joinpath(@__DIR__, "temp", "windows.md"))


line = open(joinpath(@__DIR__, "temp", "windows.md")) do f
    txt = read(f, String)
    for line in split(txt, "\n")
        if all(contains(line, i) for i in ["-q -P", "gcc", "make", "g++", "fortran"])
            return line
        end
    end
end

dependancies = strip(split(line, "-q -P")[2])


lines = open(joinpath(@__DIR__, "temp", "cygwin-portable-installer.cmd")) do f
    lines = collect(split(read(f, String), "\n"))
    for i in 1:length(lines)
        if startswith(strip(lines[i]), "set CYGWIN_PACKAGES=") && !contains(strip(lines[i]), dependancies)
            lines[i] = replace(lines[i], "set CYGWIN_PACKAGES="=>"set CYGWIN_PACKAGES=$dependancies,")
            break
        end
    end
    return lines
end

open(joinpath(@__DIR__, "cygwin-portable-installer.cmd"), "w") do f
    write(f, join(lines, "\n"))
end

run(setenv(`$(@__DIR__)\\cygwin-portable-installer.cmd`, dir=@__DIR__))
run(setenv(`$(@__DIR__)\\make-julia.cmd -j4`, dir=@__DIR__))
