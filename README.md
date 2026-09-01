# TR4W

TR4W — Cross-platform contest logging
The TRLOG-descended contest logger for Windows, macOS (pending), and Linux (pending).

Website available at https://tr4w.net

New to contesting? The big loggers are powerful — and intimidating enough that most newcomers give up and just use their everyday logger, missing dupe checking, spotting, and live scoring. TR4W takes the other path: type the exchange in plain order into one field, let the software handle CW and FT8 for you, and plug a modern radio straight into the network. Real contest features, none of the learning cliff. 

## Free and open-source.

We welcome you to check out the code. 

- Want to see how to send multi-cast UDP from a FreePascal/Lazarus app to WSJT-X? It's in the code. 

- Want to see how to talk to a Kenwood, Elecraft, Flex or Icom radio over the network? 

- What about statically linking to the hamlib C library? 

- Implementing a waterfall display from a K4, Flex, Icom? 

- What about code to automatically download the latest CTY.DAT or POTA parks file. 

  All there for the viewing. All here too...

The benefit of this project being open source is you get to not only see how the program works, but you can use it for your own projects. You are welcome to take pieces of our code for your own projects. Follow the terms of the GPLv3 (e.g., *put your changes back to the TR4W code in a pull request*) and it is customary to attribute the source material. We want to share what we have done here. Unlike too many open source projects, we do not feel like we can get the benefit of open source but still get to dictate the terms of how you use the software (beyond the GPLv3 license). We relied upon the community to help us develop this project. We're darn well going to let the community use it on their own terms. Isn't that what open source should be?  

And there will never be a priced component/subscription service/extra "pro tier" or myriad of other ways out there people try to make money on ham radio software. No one is using TR4W as a source of income--we're all set, thanks. 

We do this because we love programming, contesting and giving back to the ham community. That's it.

## Frequently Asked Questions

- Does TR4W still mean “TRLOG for Windows”?
  Historically, yes. Today TR4W is the product name for the cross-platform logger. It retains its TRLOG heritage while supporting Windows, macOS, and Linux.

- Is this TRLinux?
  No. TRLinux is a separate project with its own lineage as a Linux port of N6TR’s DOS TRlog. TR4W is its own cross-platform application and development line.

- Are the Mac and Linux versions native?
  They are coming soon. We are about 3 weeks away from being 100% FreePascal and Lazarus. Once we get past that hurdle, then we can start on using testing the FPC classes on a Mac and Linux. Running this on Mac and Linux is why this port even exists. 

  TR4W was originally a native Win32 API [Petzold](https://en.wikipedia.org/wiki/Charles_Petzold) app. Even running in Delphi, it did not use the VCL at all. It used far too mush assembler code in the program. There may have been a time and place for that but it is long gone. Every single day we take steps to remove native Win32, hwnd references and other non-FreePascal/Lazarus tools as that is how we get true cross-platform. Not a WINE compatibility layer for Linux and not running on Parallels for the Mac. NY4I uses a Mac as his daily driver and Howie N4AF uses Linux. We will call it done when we can run this on a pi400 Raspberry Pi and a simple MacBook Air. 

  Stay tuned!
