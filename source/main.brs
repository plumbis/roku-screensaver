Function getXML(url as string) as Object

    print "attempting to download " + url

    xfer = CreateObject("roUrlTransfer") 'URL object
    port = CreateObject("roMessagePort") 'Port to listen to messages from URL object
    xfer.SetMessagePort(port)

    'The following covers SSL/TLS cert handling for HTTPS
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.AddHeader("X-Roku-Reserved-Dev-Id", "")
    xfer.InitClientCertificates()


    xfer.AddHeader("Content-Type", "application/json")
    xfer.AddHeader("Accept", "*/*")
    xfer.SetUrl("https://api.dropboxapi.com/2/files/list_folder")

    xfer.RetainBodyOnError(True)

    ' Chr(34) creates "
    ' This is required because you can't escape strings in brightscript
    post_str = "{" + Chr(34) + "path" + Chr(34) + ":" + Chr(34) + "/Photos/roku-screensaver" + Chr(34) + "}"

    if(xfer.AsyncPostFromString(post_str)) ' Successful transfer
      while(true) ' Sit and wait for the transfer to come back
        msg = wait(0, port) ' See https://sdkdocs.roku.com/display/sdkdoc/Event+Loops for details on this
          if (type(msg) = "roUrlEvent")
            code = msg.GetResponseCode()
            print "Response: " + code.ToStr()

            if (code <> 200 )
              print "Error: " + msg.GetFailureReason()
              return msg
            endif

            json = ParseJSON(msg.GetString())


              'if (code = 200)
              '  playlist = CreateObject("roArray", 10, true)
              '  json = ParseJSON(msg.GetString())
              '
              '  for each kind in json
              '    topic = {
              '      ID: kind.id
              '      Title: kind.standalone_title
              '    }
              '    playlist.push(topic)
              '  end for
              '
              '  return playlist
              'endif

          else if (event = invalid)
            print "Invalid event"
            xfer.AsyncCancel()
          endif
      end while
    endif

    'xml_output = CreateObject("roXMLElement")
    'print xml_output.Parse(data)

End Function

'Function GetPhotoList()
'  xml_album_list_url = "https://picasaweb.google.com/data/feed/api/user/alumbis/albumid/6386006304484380017"
'
'  xml_output = CreateObject("roXMLElement")
'
'
'end Function

sub main()



  canvasItems = [

    {
        url:"https://lh3.googleusercontent.com/-hdn59lx279o/WJ-m5lIRBoI/AAAAAAAAC0k/_9LfIXdCh8MVzdliytGDypdKTmjuEA3WACHM/s0/IMG_4727.jpg"
    }
  ]

  getXML("https://api.dropboxapi.com/2/files/list_folder/photos/roku-screensaver")

  canvas = CreateObject("roImageCanvas")
  port = CreateObject("roMessagePort")

  canvas.SetMessagePort(port)
  canvas.setLayer(0, {
    color: "#FF000000",
    CompositionMode:"Source"
  })

  canvas.SetRequireAllImagesToDraw(true)
  canvas.SetLayer(1, canvasItems)
  canvas.Show()

  print "canvas shown"

  print m

  while(true) 'Uses message port to listen if channel is closed
    msg = wait(0, port)
    if (msg <> invalid)
      msgType = type(msg)
      if msgType = "roSGScreenEvent"
        if msg.isScreenClosed() then return
        end if
      end if
  end while

end sub
