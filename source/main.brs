' This idea comes mainly from the Roku example
' https://github.com/rokudev/fading-screensaver
' 
' This will access a folder on Dropbox and display photos as a screensaver
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
    'dropbox_folder = "/photos/roku-screensaver/"
    dropbox_folder = "/photos/roku-screensaver/"
    
    ' the screen object to draw to
    screen = createObject("roSGScreen")
    
    ' screen message port
    screen.setMessagePort(createObject("roMessagePort"))
    
    ' create the globally scoped variable object
    m.global = screen.getGlobalNode()
    ' Create two message ports, one for each element: the Dropbox photo and the black screen animation
    m.global.AddFields({"ImageFadePort": 0, "ImageSwapPort": 0})
        
    ' Get the list of photo file names from dropbox
    photo_url_list = getPhotoList(dropbox_authentication(dropbox_token), dropbox_folder)
    
    ' Start at index 0 for working through the photos
    photo_index = 0
    
    ' Initialize the last photo and current photo URIs (not just a file name, but includes "tmp:/" locator)
    m.global.AddFields({"last_photo_uri": "", "current_photo_uri": "tmp:/" + photo_url_list[photo_index]})

    ' Go download the first photo to show and move the photo_index forward
    downloadPicture(dropbox_authentication(dropbox_token), dropbox_folder, photo_url_list[photo_index])
    photo_index = photo_index + 1
    
    ' Draw the screensaver
    scene = screen.createScene("ScreensaverFade") 
    scene.backgroundColor="0x00000000"
    scene.backgroundUri = ""
    screen.show()

    ' Loop forever (or until the screensaver is stopped)
    while(true)

        ' If we have seen all of the images in the folder, start again from the beginning
        if photo_index = photo_url_list.Count()
            photo_index = 0
        end if 
        ' Go download the next photo and increment the counter
        downloadPicture(dropbox_authentication(dropbox_token), dropbox_folder, photo_url_list[photo_index])        
        photo_index = photo_index + 1

        ' We wait 7 seconds to hear anything on the screen. 
        ' We don't expect anything to happen so we move forward after 7 seconds.
        ' If something does happen we will end the show (e.g., button press)
        msg = wait(7000, screen.GetMessagePort())

        ' Something happened on the screen, so we assume we should turn the screen saver off
        if(msg <> invalid)

            if msgType = "roSGScreenEvent"
                if msg.isScreenClosed() then return
            end if

        ' Nothing interrupted us, change the image
        else
            ' Change the ImageFadePort to trigger the fade to black
            m.global.ImageFadePort += 1
            ' Again, nothing should happen, so this is just a 2.5 second pause during the fade
            msg = wait(2500, screen.GetMessagePort())
            ' Now change the ImageSwapPort to draw the new photo
            m.global.ImageSwapPort += 1
        end if
    end while

end sub

Function dropbox_authentication(token)
    ' This function will build a roUrlTransfer object with some general parameters to use the Dropbox API
    ' This is kept simple to allow other methods to make changes without issue

    ' Set up the object to do an HTTP POST to Dropbox
    xfer = CreateObject("roUrlTransfer")
    xfer.SetMessagePort(CreateObject("roMessagePort"))

    ' The following covers SSL/TLS cert handling for HTTPS
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.AddHeader("X-Roku-Reserved-Dev-Id", "")
    xfer.InitClientCertificates()

    ' Details based on Dropbox API Explorer
    ' https://www.dropbox.com/developers/documentation/http/documentation
    xfer.AddHeader("Accept", "*/*")
    xfer.AddHeader("Authorization", "Bearer " + token)
    xfer.RetainBodyOnError(True)

    return xfer
end Function


Function getPhotoList(dropbox_xfer, folder)
    ' This function will access the Dropbox API
    ' Providing authentication with the configured global token
    ' And return the JSON list of the directory provided as a global variable
    xfer = dropbox_xfer
    ' Define the output we expect back
    xfer.AddHeader("Content-Type", "application/json")
    ' Define the API URL to access
    xfer.SetUrl("https://api.dropboxapi.com/2/files/list_folder")

    ' POST to dropbox API.
    if(xfer.AsyncPostFromString(FormatJson({"path": folder}))) 
        while(true) ' Sit and wait for the transfer to come back
            ' Wait until we get something back 
            msg = wait(0, xfer.GetMessagePort()) ' See https://sdkdocs.roku.com/display/sdkdoc/Event+Loops for details on this
            ' If it worked we will have an roUrlEvent object with our API answer
            if(type(msg) = "roUrlEvent")
                code = msg.GetResponseCode()

                ' 200 is good. Other codes are bad.
                if(code <> 200)
                    print "Error: " + msg.GetFailureReason()
                    xfer.AsyncCancel()
                end if

                ' Transform the returned output from a string to JSON for processing
                dropbox_json = ParseJSON(msg.GetString())

                photo_url_list = CreateObject("roArray", dropbox_json.entries.Count(), false)

                ' The RNG on roku is shit. If we ask it to randomly pick an index we get a ton of repeats
                ' Instead, let's randomly initialize the order of the photos at the beginning
                ' To do this, randomly pick a photo from the json output, put it in the new photo_url_list
                ' Then delete it from the json_output
                ' Keep doing this until we work through the entire list of json photos 
                while dropbox_json.entries.Count() > 0
                    entry_index = rnd(dropbox_json.entries.Count() - 1)
                    photo_url_list.push(dropbox_json.entries[entry_index].name)
                    dropbox_json.entries.delete(entry_index)
                end while
                
                ' Send back the list of photo filename
                return photo_url_list
    
            ' Not sure how we got here
            else if(event = invalid)
                print "Invalid event"
                xfer.AsyncCancel()
            end if
        end while
    end if
End Function


Function downloadPicture(dropbox_xfer, folder, filename) as Void
    ' downloadPicture function will download an image from dropbox
    ' The image is stored in temporary storage.
    ' This function is also responsible for deleting the previous photo.
    ' There is a brightscript library that may do this for me
    ' but I wasn't smart enough to figure out how to use it.

    ' create a filesystem object so we can read/write to tmp:/
    filesystem = createObject("roFileSystem")

    xfer = dropbox_xfer
    xfer.SetUrl("https://content.dropboxapi.com/2/files/download")
    
    ' Unlike the photo_list this is text/plain not json
    xfer.AddHeader("Content-Type", "text/plain")


    ' Note: Download requires path as a header. The directory list is in the body
    xfer.AddHeader("Dropbox-API-Arg", FormatJson({"path": folder + filename }))

    ' We have to manually set the request type due to how AsyncGetToFile() works
    xfer.SetRequest("POST")

    ' Make an async POST request to not block the display
    ' File will be saved to the tmp:/ directory with the filename of the image
    if(xfer.AsyncGetToFile("tmp:/" + filename)) ' POST to dropbox API.
        while(true) ' Sit and wait for the transfer to come back
            msg = wait(0, xfer.GetMessagePort()) ' See https://sdkdocs.roku.com/display/sdkdoc/Event+Loops for details on this
            if(type(msg) = "roUrlEvent")
                code = msg.GetResponseCode()

                ' 200 is good, anything else is a problem
                if(code <> 200)
                    print "Error: " + msg.GetFailureReason()
                    xfer.AsyncCancel()
                end if

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
                    'print "Deleting " + m.global.last_photo_uri
                    ' Remove the photo from the temporary filesystem
                    filesystem.Delete(m.global.last_photo_uri)
                end if
            end if

            return

            ' Bad stuff happened
            else if(event = invalid)
                print "Invalid event"
                xfer.AsyncCancel()
                return
            end if
        end while
    end if
End Function
