# Dropbox Streaming Roku Screensaver

This screensaver will allow you to randomly display photos from a Dropbox directory to your Roku.

## Getting Started
1. Copy the code locally
1. Edit `main.brs` and add your dropbox API token
1. Enable Roku [developer mode](https://blog.roku.com/developer/2016/02/04/developer-setup-guide/)
1. Build a zip file of this directory. *IMPORTANT* do not zip the folder, zip the individual files. Trust me, this kind of problem can create drinking problems. Select all of the files and add them to an archive
1. Go to your Roku's IP and login (see the developer mode link for details)
1. Upload your zip file
1. Click "Install" or "Replace"
1. On your Roku Go to
⋅⋅*Settings
⋅⋅*Screensaver
⋅⋅*Dropbox Photos (dev)
⋅⋅*Preview (to see if it actually works)


## Hey, it didn't work
Troubleshooting roku scripts is not easy.
1. edit `main.brs` and change `RunScreenSaver()` to `main()`
1. Telnet to `<ROKU_IP> 8085`
1. Use print statements
1. Try to follow the [Roku docs](https://sdkdocs.roku.com/display/sdkdoc/Debugging+Your+Application)

