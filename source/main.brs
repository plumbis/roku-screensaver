sub RunScreenSaver()

    'The dropbox token is how this script tells dropbox who you are
    'https://blogs.dropbox.com/developers/2014/05/generate-an-access-token-for-your-own-account/
    '
    '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    '!!!!    DO NOT SHARE THIS TOKEN   !!!
    '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    '
    ' Seriously though, if you upload your token to github you've just granted
    ' strangers full access to your dropbox account
    dropbox_token = ""

    'What is the name of the directory in dropbox where your photos are
    dropbox_folder = "/photos/roku-screensaver/"

    'The number of photos in dropbox can dynamically change without issue.
    'Resizing the array can take some time if the original estimate (500)
    'is not close to the actual number of photos.
    '
    'If you have 500 or fewer photos, don't worry about this.
    'If you have more than 500, then set it to something 10-20% larger
    'than the number of photos you have.
    number_of_photos = 500


    ' a global filesystem object so we can access "tmp:/"
    filesystem = createObject("roFileSystem")

    ' the screen object to draw to
    screen = createObject("roSGScreen")

    ' ports so threads can pass messages
    port = createObject("roMessagePort")
    port2 =  createObject("roMessagePort")
    screen.setMessagePort(port)
    m.global = screen.getGlobalNode()

    ' Write the global variables that the user specified above
    m.global.AddFields({"token": dropbox_token, "folder": dropbox_folder})
    dropbox_json = getPhotoList()

    ' Create an Array larger than the number of photos
    ' in the dropbox directory today so we can add some more in the future.
    ' We still need to count how many photos there actually are
    ' for the random index generator, otherwise we could access out of bounds
    ' (if I have an array of 500 and only 200 pictures for example)
    photo_url_list = CreateObject("roArray", number_of_photos, true)

    ' Create a global integer variable of how many photos there are
    m.global.addField("photo_count", "int", true)
    m.global.photo_count = 0

    ' Dropbox returns an dict (AssociativeArray) of
    ' {cursor:<>, has_more: False, entries: []
    ' entries is a list of dict
    ' the dict has a bunch of info, the only key we care about is
    ' name - the filename (image_1.jpg)

    ' Pull the full json output from dropbox
    ' Then only look at the "entries" key
    for each element in dropbox_json.entries

        ' Within entries (which is the list of EVERY photo)
        ' We push the filename (element.name) into the list
        photo_url_list.push(element.name)

        ' Count up the total number of photos
        m.global.photo_count += 1
    end for

    ' Define a global variable for the list of photo URLs
    m.global.AddFields({"photo_url_list": photo_url_list})

    ' Define a global variable for the current photo
    m.global.AddField("current_photo_uri", "uri", true)

    ' Define a global variable for the previous photo
    m.global.AddField("last_photo_uri", "uri", true)

    ' Go download the first photo to show
    downloadPicture()

    ' This stuff is to make changes. It's based on the rokudev
    ' fading screensaver example https://github.com/rokudev/fading-screensaver
    m.global.AddField("MyField", "int", true)
    m.global.MyField = 0
    m.global.AddField("PicSwap", "int", true) 'Creates (Global) variable PicSwap
    m.global.PicSwap = 0
    scene = screen.createScene("ScreensaverFade") 'Creates scene ScreensaverFade

    ' Set the background to all black
    ' But you can't set the color unless you explicitly set the background image to ""
    ' Let's pretend like that didn't take me an hour or more to figure out.
    scene.backgroundColor="0x00000000"
    scene.backgroundUri = ""

    ' Draw the screen
    screen.show()

    ' Based on rokudev fading screensaver example
    ' https://github.com/rokudev/fading-screensaver'
    ' Loop forever displaying the screensaver
    while(true)
        ' Wait 7 seconds before setting the message
        msg = wait(7000, port)

        ' Something interrupted us or broke
        if(msg <> invalid)

            if msgType = "roSGScreenEvent"
                if msg.isScreenClosed() then return
            end if

        ' Nothing broke
        else
            ' Go download the next photo
            downloadPicture()

            ' Signal that something changed
            m.global.MyField += 10
            msg = wait(2500, port2)
            m.global.PicSwap += 10'
        end if
    end while
end sub


' This function will access the Dropbox API
' Providing authentication with the configured global token
' And return the JSON list of the directory provided as a global variable
Function getPhotoList() as Object

    ' Set up the object to do an HTTP POST to Dropbox
    xfer = CreateObject("roUrlTransfer") 'URL object
    port = CreateObject("roMessagePort") 'Port to listen to messages from URL object
    xfer.SetMessagePort(port)

    ' The following covers SSL/TLS cert handling for HTTPS
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.AddHeader("X-Roku-Reserved-Dev-Id", "")
    xfer.InitClientCertificates()


    ' Details based on Dropbox API Explorer
    ' https://www.dropbox.com/developers/documentation/http/documentation
    xfer.AddHeader("Content-Type", "application/json")
    xfer.AddHeader("Accept", "*/*")
    xfer.SetUrl("https://api.dropboxapi.com/2/files/list_folder")
    xfer.AddHeader("Authorization", "Bearer " + m.global.token)
    xfer.RetainBodyOnError(True)

    ' Chr(34) creates " (the double quote character)
    ' This is required because you can't escape strings in brightscript
    ' post_str is the dict to pass to Dropbox "{path: /photos}" for example
    post_str = "{" + Chr(34) + "path" + Chr(34) + ":" + Chr(34) + m.global.folder + Chr(34) + "}"

    ' Do an Async Post so we don't block waiting for dropbox to come back
    if(xfer.AsyncPostFromString(post_str)) ' POST to dropbox API.
        while(true) ' Sit and wait for the transfer to come back
            msg = wait(0, port) ' See https://sdkdocs.roku.com/display/sdkdoc/Event+Loops for details on this
            if(type(msg) = "roUrlEvent")

                code = msg.GetResponseCode()

                ' 200 is good. Other codes are bad.
                if(code <> 200)
                    print "Error: " + msg.GetFailureReason()
                    xfer.AsyncCancel()
                endif

                ' Return the JSON list that Dropbox gave us
                return ParseJSON(msg.GetString())

            ' Not sure how we got here
            else if(event = invalid)
                print "Invalid event"
                xfer.AsyncCancel()
            endif
        end while
    endif
End Function


' downloadPicture function will download a
' randomly selected from the list of pictures.
' The image is stored in temporary storage.
' This function is also responsible for deleting the previous photo.
' There is a brightscript library that may do this for me
' but I wasn't smart enough to figure out how to use it.
Function downloadPicture() as Void

    ' create a filesystem object so we can read/write to tmp:/
    filesystem = createObject("roFileSystem")

    ' It is important to use photo_count and not the array size
    ' Since the array my be larger than the number of photos or could
    ' have been resized by the roku
    filename = m.global.photo_url_list[rnd(m.global.photo_count - 1)]

    print "Downloading: " + filename

    ' The following code is nearly identical to getPhotoList
    ' but I was struggling with variable scoping and got lazy
    '
    ' Set up the object to do an HTTP POST to Dropbox
    xfer = CreateObject("roUrlTransfer") 'URL object
    port = CreateObject("roMessagePort") 'Port to listen to messages from URL object
    xfer.SetMessagePort(port)

    ' The following covers SSL/TLS cert handling for HTTPS
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.AddHeader("X-Roku-Reserved-Dev-Id", "")
    xfer.InitClientCertificates()


    ' Details based on Dropbox API Explorer
    ' https://www.dropbox.com/developers/documentation/http/documentation
    xfer.AddHeader("Content-Type", "text/plain")
    xfer.AddHeader("Accept", "*/*")
    xfer.SetUrl("https://content.dropboxapi.com/2/files/download")
    xfer.AddHeader("Authorization", "Bearer " + m.global.token)

    ' Chr(34) creates " (the double quote character)
    ' This is required because you can't escape strings in brightscript
    header_str = "{" + Chr(34) + "path" + Chr(34) + ":" + Chr(34) + m.global.folder + filename + Chr(34)  + "}"

    ' Note: Download requires path as a header. The directory list is in the boxy
    xfer.AddHeader("Dropbox-API-Arg", header_str)

    ' Don't throw away the HTTP body if there is an error
    xfer.RetainBodyOnError(True)

    ' We have to manually set the request type due to how AsyncGetToFile() works
    xfer.SetRequest("POST")

    ' Make an async POST request to not block the display
    ' File will be saved to the tmp:/ directory with the filename of the image
    if(xfer.AsyncGetToFile("tmp:/" + filename)) ' POST to dropbox API.
        while(true) ' Sit and wait for the transfer to come back
            msg = wait(0, port) ' See https://sdkdocs.roku.com/display/sdkdoc/Event+Loops for details on this
            if(type(msg) = "roUrlEvent")
                code = msg.GetResponseCode()

                ' 200 is good, anything else is a problem
                if(code <> 200)
                    print "Error: " + msg.GetFailureReason()
                    xfer.AsyncCancel()
                endif

            ' First, the currently displayed photo is moved to be the old photo
            ' Next, the recently downloaded photo is now the current photo
            m.global.last_photo_uri = m.global.current_photo_uri
            m.global.current_photo_uri = "tmp:/" + filename

            ' First make sure the last photo is set.
            ' If the screensaver just started there is no last photo
            ' and nothing to delete
            if m.global.last_photo_uri <> ""

                ' Double check that the file exists so there isn't any funny business
                if(filesystem.Exists(m.global.last_photo_uri))
                    print "Deleting tmp:/" + m.global.last_photo_uri
                    ' Remove the photo from the temporary filesystem
                    filesystem.Delete(m.global.last_photo_uri)
                endif
            endif

            return

            ' Bad stuff happened
            else if(event = invalid)
                print "Invalid event"
                xfer.AsyncCancel()
                return
            endif
        end while
    endif
End Function
