InpOut32 (and 64) 

For developers:

The driver (.sys file) is included, as a resource in the DLL. All you need to do is link to the appropriate DLL in your program and it should work.

NOTE: When the DLL loads for the first time, the appropriate driver is installed and used.
NOTE: Elevated permissions are required in Vista and later to install the driver. s

I recommend using runtime linking to the C interface (manually loading the library) in C++, in much the same as the interop calls from .NET work. However you can also use the .LIB and header files provided to link at compile time if that suits your application better.

Development:

There are examples and usage instructions for the 32bit version on the original author's site Logix4u (note I have removed links as they reportidly no longer active and their site appears to have been impacted by malware) and below in the download links.

To use the 64bit (x64) port (from a 64bit application), all you need to do, is use my x64 compatible DLL called InpOutx64.DLL, either using InpOutx64.lib or runtime linking (LoadLibrary, GetProcAddress etc.). Everything else is the same as the 32bit (InpOut32) DLL.

Please bear in mind, that on 64bit operating systems, many applications are still 32bit. If your application is 32bit you MUST use my version of InpOut32.dll which contains both 32bit and 64bit drivers and determines which one to install and use at runtime.
If your application is 64bit (x64) then use InpOutx64.dll. Both DLL's can install and talk to the 64bit (x64) driver on x64 editions of Windows.

NOTE: Because I used Visual Studio 2005 to build the DLL's you may need the 2005 SP1 Microsoft C++ Runtimes.
These should be available from Microsoft. You will have them if you have Visual Studio 2005. If you can’t find them, send me an email!

Files for both 32 bit and 64 bit inpout.

https://github.com/ellysh/InpOut32/tree/master/bin

