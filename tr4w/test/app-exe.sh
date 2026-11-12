# app-exe.sh -- the ONE definition of which app binary the corpus, the ADIF round
# trip and the contest matrix run. Source it; every runner under test/ does.
#
# The shipping architecture is x86_64-win64 (issue 299, flipped 2026-11-12), so a
# plain build\Build-App.ps1 writes build-out/app-x86_64-win64/tr4w_fpc.exe and
# that is what is run. To run the 32-bit build instead (buildable, not shipped),
# build it with  Build-App.ps1 -Cpu i386  and set  TR4W_APP_ARCH=i386-win32.
#
# TR4W_APP_EXE_REL is relative to the repository root.
TR4W_APP_EXE_REL="build-out/app-${TR4W_APP_ARCH:-x86_64-win64}/tr4w_fpc.exe"
