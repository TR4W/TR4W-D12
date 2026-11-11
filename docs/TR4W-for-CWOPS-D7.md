# **The CW Open and TR4W**

By: Marvin Bloomquist, N5AW

## **Background**

 TR4W stands for TR for Windows. Originally developed by Dmitry Gulyaev, UA4WLI, TR4W is an  adaptation of the DOS program TR Log. The program is now supported by a team led by Howie,  N4AF. The download is only 500 K and installs in less than a minute. I have run it under Windows 7  and Windows 10 in stand-alone and networked environments with few problems. A context based help  function is built into the program. Most commands are the same as in the TR Log manual at  http://www.trlog.com/manual.shtml.

## **Getting Started**

 NOTE: Windows frequently gives a false warning that the TR4W download contains a virus and may  not allow installation. If you get a warning, first try clicking on “More info” and then “Run anyway”. If  it still won’t run you will need to temporarily disable the virus protection (Windows Defender in my  case).  The dwonload is on the TR4W homepage at: https://tr4w.net/. Click on “Download Release   #.###.#” (4.103.0 at the time this was written) and save when prompted. Clicking on  “tr4w_setup_#.###.#.exe” will initiate installation of the program. You should see a window like this:

<img src="file:///C:/Users/toms/AppData/Roaming/marktext/images/4bc95840af1b0c465f9278fa146df39a81b3b189.png" title="" alt="" data-align="center" />

I recommend installing the program in the C folder, not the Program folder which creates problems  accessing your logs. Click on Next and the program will install. When the installation is completed a  TR4W icon will appear on your desktop. Clicking on the icon starts the program, bringing up this  screen:

<img src="file:///C:/Users/toms/AppData/Roaming/marktext/images/dd08db4c620687a4869c1538a1a7b8eef4acfeff.png" title="" alt="" data-align="center" />

Fill in your call and select CWOPEN in the pull down CONTEST menu. You are then asked to fill in your name. Next select your CATEGORYs and click OK. The program opens with two windows:

<img src="file:///C:/Users/toms/AppData/Roaming/marktext/images/9765a41658b72ef313d325fbe66c731e75de04b2.png" title="" alt="" data-align="center" />



The lower window is a function key template. More about programming these later.

## **Interfacing:**

Next you will need to configure your CW keying and radio interfaces. A Winkeyer is recommended but some radios, such as the K3, can be keyed through the serial port.  If you are using a Winkeyer you need to know the port it is assigned to. Go to the “Tools” pull down menu and select “Device Manager”. In Device Manager select “Ports” and make note of the serial ports to which your Winkeyer and radios are connected. Close Device Manager and return to TR4W.  On the pull down menu “Settings” select “Winkeyer” to bring up this menu:

<img src="file:///C:/Users/toms/AppData/Roaming/marktext/images/654b786144d8624041a237a46c3b0017c1a1ff25.png" title="" alt="" data-align="center" />

Note the context-sensitive “help” on the right side explaining in this case what “WK AUTOSPACE” does. Set WK ENABLE to TRUE and WK PORT to the proper port for your Winkeyer.  Select “Save All” before exiting the setup menu.

Returning to the main logging window, from the Settings pull down menu select “CAT and CW Keying”, then “Radio 1” or “Radio 2” to open this window:

<img src="file:///C:/Users/toms/AppData/Roaming/marktext/images/77106b182dc442ce4a9ee189854a22fe713004c0.png" title="" alt="" data-align="center" />

The CAT portion of the menu is straightforward. The values shown are for my K3. The CW/PTT options should be NONE and OFF if you are using a Winkeyer. RADIO ONE NAME will appear on the logging screen to identify the radio. If you are SO2R you will need to do this for both radios.

Now go to the Windows pull down menu on the main logging screen and select Radio1 to open a window for the radio. If your radio has been properly interfaced it should look something like this:

<img src="file:///C:/Users/toms/AppData/Roaming/marktext/images/dd30949981281e9ed679b6f4072195769229e99a.png" title="" alt="" data-align="center" />

You can drag the window to a convenient place on your computer screen.

## **Other Windows:**

TR4W has a number of additional windows that can be opened from the Windows pull down menu. Others you may find useful in the CW Open are the Band Map, Dupe Sheet and SCP (Super Check Partial). Normally one would want a multiplier window as well but it isn’t really needed for CWO. In addition to being “dragable” these windows can be resized.

## **Programmed Messages:**

The program now is ready to go with a set of default messages but you will likely want to program your own. Like most contest logging programs, TR4W has different messages for “Run” and “Search

and Pounce”. To program them press “Alt P” on the keyboard to bring up this menu:

<img src="file:///C:/Users/toms/AppData/Roaming/marktext/images/d23a69d33cfe4e5de834e71555785674544a864d.png" title="" alt="" data-align="center" />

Select the first option, either with your mouse or C on the keyboard to get the CQ keys. This is how I have them programmed for the CW Open:

<img src="file:///C:/Users/toms/AppData/Roaming/marktext/images/9ffc85e392f288288563c9e0cd22effa3785695c.png" title="" alt="" data-align="center" />

F10 is reserved for toggling keyboard CW off and on (keyboard CW “on” disables the other function keys) but all the other keys are individually programmable including Ctrl Fn and Alt Fn for a total of 35 possible messages (assuming your keyboard has 12 function keys). Normally F1 is the primary CQ message. To program F1 double click on “CQ CW MEMORY F1” to get this menu (default CQ message shown):

<img src="file:///C:/Users/toms/AppData/Roaming/marktext/images/7511a5634c5034946bbf6e8eaec077b0900f3b90.png" title="" alt="" data-align="center" />

You can edit the message just like any text. The back slash (\\) is shorthand for your call. Fill in the

Caption box only if you wish it to differ from the actual message. The function keys can also be programmed to execute a set of commands shown in the “List of commands” pull down.

In addition to \\ as shorthand for your call there are others which are listed in the TR Manual. In F4, I have used the @ symbol which sends whatever is entered in the call window. This is useful when a station does not respond to his report and you want to resend his call.

A similar set of messages for Search and Pounce can be programmed by selecting E on the earlier menu. The S\&P function keys I have programmed for the CW Open are shown below.

![](C:\Users\toms\AppData\Roaming\marktext\images\ce5d3368fecff2388928cf85b05c5468539c0f09.png)

Don’t change F1, F2, and F10 but all the other keys can be programmed to your liking. Most of mine are the same as those for CQ. That makes them easier to learn. F5 for example always sends my call. These keys are also used in CQ mode after sending the other stations call and report. For example if the other station asks for a repeat hit F2. Once his report is entered the keys revert back to the CQ keys.

The “O” option allows you to program messages like the exchange and QSL messages that don't need a function key or are used in multiple messages.  Here are mine:

![](C:\Users\toms\AppData\Roaming\marktext\images\06299713956f5914d97518518c56c0aa855e0a54.png)

The CALL OK NOW CW MESSAGE automatically sends the corrected portion of a call (if you make a change to the initial call copied in CQ mode) followed by the QSL CW MESSAGE. The QSL CW MESSAGE is sent when you hit the Enter key. The key used to send the QUICK QSL message is programmable. Remember backlash (\\) is your call. Both these QSL keys log the contact completing the QSO.

## **Setting Up for Three CW Open Sessions:**

When you quit the program and open it again you will see a screen like this:

<img src="file:///C:/Users/toms/AppData/Roaming/marktext/images/610101417e6010a1eb28a45da469487f25a7f4f2.png" title="" alt="" data-align="center" />

It is the same screen you saw at the start of the set up except now \[2011 CWOPEN N5AW\] is one of the program files. Clicking on it will open up the contest file you just set up. However, if you are going to operate more than one session you will either need to create separate unique folders for each one or move all the files except CWOPS.CFG before the next session. If you choose to set up separate folders ahead of time, open the program folder for TR4W and rename the 2011 CWOPEN

*CALL* folder to

something like 2011 CWOPEN 1200. Make a folder for each session and copy the CWOPEN.CFG file from your original folder into the others. I find it useful to make a shortcut on my desktop to go directly to the TR4W program folder.

**Other Commands**:

There are many options that allow TR4W to be tailored to the individual user. These commands can be accessed by entering Ctrl J to bring up a list. Most of these are described in the TR Log Manual but the description shown on the right when you highlight a command is normally all you need to know.  A list of all of these is also available on the TR4W website under Documentation. Here is what the menu looks like:

![](C:\Users\toms\AppData\Roaming\marktext\images\d3b8594cccaf2a18ffa2be6b7461b0d5fc58b460.png)

I have highlighted AUTO S&P ENABLE which I find very useful. As you see in the description this automatically puts you in S\&P mode when you tune away from your CQ frequency. You also must specify how far the VFO is moved before it switches to S\&P – in this case 300 Hz. Note that tuning the RIT will not initiate the switch to S\&P.

Another feature that I find very useful but not everyone likes is AUTO CALL TERMINATE. With this command set to TRUE, when you are in CQ mode and begin typing in the CALL WINDOW, the program will begin sending the call after you enter the number of characters specified by AUTO SEND CHARACTER COUNT. In the example it is set to 4. This takes practice since if the call is long you need to pause after you have typed in the 3

rd letter until the station completes his call.  If you are a slow

typist like me this is less of a problem. This option can also be toggled off and on from the logging window by holding down the Alt and – minus keys simultaneously. A similar function in N1MM is called ESM (ENTER SENDS MESSAGE). Many operators find this feature a little tricky to master and end up abandoning it for the old tried and true Return or Enter key. I like anything that reduces keystrokes in contesting, so have found AUTO CALL TERMINATE a run rate booster that was worth mastering. We have used TR4W in multi-op settings with a mix of operators who do and don't like the feature. As mentioned above, toggling it off and on with Alt - is very simple.

The list of commands is long and even with the description can be confusing to a new user. I’ve listed some of the most important ones below.

## **Always remember to save your changes before exiting the**

**set up menu.** If you fail to do so your changes will remain in effect only until you close the program.

The next time you open TR4W it will revert to  prior settings.

AUTO DUPE ENABLE CQ – I normally set this to FALSE and log dupes who answer my CQ.

AUTO DUPE ENABLE S AND P – unless a contest allows dupes or you are using the General

Logging module you should set this to TRUE so you don’t accidentally call a dupe.

AUTO QSO NUMBER DECREMENT – when this is set to TRUE the serial number is not increased until the next QSO is logged. So if after you have already logged a contact he asks you to repeat the number, it will still be correct if you send it with an F key. If set to FALSE it will be one more than it was.  I recommend you set it to TRUE for the CW Open.

CW SPEED INCREMENT – CW speed can be changed with the Page Up and Page Down keys. I prefer a 2 word per minute change instead of the default 3.

ESCAPE EXITS SEARCH AND POUNCE – If TRUE, when you are in S\&P mode and hit the Escape key the program switches to CQ mode. In this case I occasionally end up in CQ mode by accident so I set this to FALSE. Then to go from S\&P to CQ you will need to enter Shift-Tab. Once in CQ mode Tab takes you back to S\&P.

MY GRID  – TR4W automatically calculates beam headings based on this entry so you need to put your proper grid here.

INITIAL EXCHANGE FILE NAME – If you have a text file with calls and names, click on this command to bring up a “browse” menu. Locate the file and double click on it. When one of these calls is entered the exchange will be filled in with the name in the text file and you will only need to enter the serial number. Note for CWO you want only the call and name in the file, not the CW Ops number.

LEADING ZEROS – The name is a little deceiving – this is actually the number of characters you want in the serial number. If you want to start with 001, set this to 3.

SINGLE RADIO MODE – If you are using two radios set this to FALSE. Toggle between radios using Ctrl-R. The active radio will be highlighted on the logging window.

TWO RADIO MODE –  For SO2R, setting this to TRUE enables some features that streamline second radio contacts. These are described in the TR Log Manual and take quite a bit of practice to use efficiently so I won’t go into them here.

## **Useful “Alt” and “Ctrl” Operations:**

We have already talked about some of the Alt functions such as Alt-P. Others are listed in the pull down menu Alt-. Here are some of ones I use the most:

Alt-R – toggle between radios in SO2R mode

Alt-B – band up

Alt-V – band down

Alt-M – toggle mode

Alt-S – enter CW speed

Alt-Y – delete last QSO

Alt-L – search your log for a call sign. When you find it you can edit the QSO information.

Cntl-L – list the entire log

Ctrl-Enter – same as Enter except does not send CW

## **An Example S&P QSO:**

Suppose you hear K6RB calling CQ CWO. Enter his call is the CALL WINDOW. If he is a dupe QSO B4 will show up in red just to the left of the window. When he finishes CQing hit either F1 or Enter to send your call. If he is a dupe and you failed to notice the QSO B4 message, no call will be sent, the CALL WINDOW will clear and you will see a message K6RB is a dupe! If he is not a dupe your call

will be sent and the cursor will move to the EXCHANGE WINDOW waiting for you to enter his information. If he does not answer you can hit F1 to call again. Still no answer- hit Esc to return to the CALL WINDOW. Hit Esc again to clear his call. If he does come back enter the information in the EXCHANGE WINDOW and hit Enter to send your information and log the contact … or hit F2 to send the information without logging the contact, then Enter after he has confirmed the exchange to log him.  If you need to delete the last contact hit Alt-Y. If you want to check to see if you have worked him without calling, hit the space bar.

## **An Example CQ QSO:**

Find a clear frequency. Hit F8 if you used my example function key entries to send QRL? If no response hit Shift-Tab to enter CQ mode. Press F1 for a “long” CQ or F2 for a “short” CQ. When a station calls type his call in the CALL WINDOW and hit Enter. Your information will be sent and the cursor moves to the EXCHANGE WINDOW. If the station asks for a repeat hit F2. When he sends his information type it in and hit Enter to send the “long” QSL message or \\ to send the short message. If you need a repeat and used my example F keys, hit F7 to send AGN? If you need to correct his call you can use the up arrow or a mouse click to go back to the CALL WINDOW and correct it. However, a useful feature of TR4W is to set CALL SIGN UPDATE ENABLE = TRUE. Then you can type a corrected call sign in the EXCHANGE WINDOW and it will replace the original call.

As you gain familiarity with the program you will find you can handle most fills with the function keys. However, you can always send them manually. If you do, the paddle instantly interrupts TR4W's autosending. Esc also stops autosending. This can be useful to shorten a CQ or a QSL message. For example when I have several stations calling, after a QSO I may use Esc to shorten the QSL message to “TU” instead of “TU N5AW”.

## **Correcting an Entry:**

The last five QSOs are displayed above the CALL WINDOW. To edit one of them either double click on the call with your mouse or arrow up from the CALL WINDOW and hit Enter to bring up a window to edit the QSO information. Here is what the QSO edit window looks like:

<img src="file:///C:/Users/toms/AppData/Roaming/marktext/images/5640dfc57fa7394bc780763fb0cb9d67df067adb.png" title="" alt="" data-align="center" />

If the QSO is no longer in the log window use the Alt-L function described earlier to search for the call. When the QSOs with that station are displayed double click on the one you want to edit. While you can scroll around in the window, I find it easier to use a mouse

## **The Bandmap:**

One of the advantages of interfacing your radio with a logging program is the ability to generate a bandmap. The bandmap window is activated by selecting it from the pull-down Windows menu. Several commands (Ctrl-J) are available to set the display parameters (bands, modes, decay time, etc). Unless you connect to the DX cluster the bandmap is populated entirely by stations you enter in the CALL WINDOW while in S&P mode. Below is an example from the IARU contest.

<img src="file:///C:/Users/toms/AppData/Roaming/marktext/images/889c0bb2bd8e17c934b2400760569f0dd142784a.png" title="" alt="" data-align="center" />

To have the band map filled from a DX cluster select “DX Cluster” under TR4W’s  Windows pull down menu. This brings up the DX Cluster window. The upper left box is used to select the cluster you want to connect to. The rest should be familiar if you have ever used a cluster.

The bandmap is functionally similar to those in other logging programs.  The frequencies of the stations on the active band have a dark blue background. The most recent calls entered are shown in with a black background. The oldest are light gray. After a time specified by BANDMAP DECAY TIME the call drops off the map. The stations with a D have been worked. Those with an M are multipliers that have not been worked. A station that has not been worked but is not a multiplier will have a blank beside it. Double clicking on a call QSYs your radio to that stations frequency. A right click of the mouse allows you to specify to QSY the second radio.

Provided you have BAND MAP CALL WINDOW ENABLE set to TRUE (the default), as you tune across the band the calls on the map will be displayed in the CALL WINDOW. If it is a dupe it is shown in red to the left. If you hit Enter or the space bar it will be “renewed” and the call cleared from the CALL WINDOW. If the station has not been worked and you hit Enter or F1, your call will be sent just as if you had entered the call manually. If you want to go back to a station displayed in the bandmap, double click on his call and your radio will QSY to his frequency.

## **Exporting Logs and Generating Reports:**

When the contest is over, you can generate Cabrillo and ADIF files from the Export option in the Files pull down menu. The Reports option will generate a summary and various other reports. These are all stored in the sub-folder for that contest.

## **Other Features:**

TR4W has many features not covered here including networking, audio recording, and a sophisticated voice keyer.

## **Conclusion:**

Any good contest logging program takes a while to master. However, I have had guest operators at my station who were able to use TR4W with only a little practice. The CW Open is a good opportunity to give it a try but I strongly recommend you get as much practice as you can before the contest. You can use the GENERAL QSO contest set up to use it as a general purpose logging program. However, the bimonthly CWT’s are an ideal place to get some practice. Just chose “CWOPS” for the contest instead of CWOPEN when you go through the setup process and change CWO to CWT in the messages.

As a final check, do a “dummy” CW Open with your transmit off to make sure you have things set up properly before the contest. If you run into problems, one place to get help is through the TR4W Google Group. There is a link to it on the TR4W home page at to try to help. Just send an email to n5aw@arrl.net.

https://tr4w.net/.  I would also be happy to try to help. Just send an email to n5aw@arrl.net.
