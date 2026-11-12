# app-exe.sh -- the ONE definition of which app binary the corpus, the ADIF round
# trip and the contest matrix run. Source it; every runner under test/ does.
#
# Windows TR4W is x86_64-win64 only, so a plain build\Build-App.ps1 writes
# build-out/app-x86_64-win64/tr4w_fpc.exe and that is what is run.
#
# TR4W_APP_EXE_REL is relative to the repository root.
TR4W_APP_EXE_REL="build-out/app-x86_64-win64/tr4w_fpc.exe"
