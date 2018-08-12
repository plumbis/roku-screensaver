' Sets the background uri to the current photo
' This is a funky way to do things, but is required because
' Roku doesn't allow this file to make HTTP calls, since
' it is responsible for drawing the images
Function changeBackground() as Void
    m.DropboxPhoto.uri = m.global.current_photo_uri
End Function


' Function to trigger the fade out animation
Function FadeAnimation() as Void
    m.FadeAnimation.control = "start"
End Function


' Main function to draw on the screen
' based on Rokudev fading screensaver https://github.com/rokudev/fading-screensaver
Function init()
    ' Sets pointer to FadeAnimation node
    m.FadeAnimation = m.top.findNode("FadeAnimation")
    ' Sets pointer to DropboxPhoto node
    m.DropboxPhoto = m.top.findNode("DropboxPhoto")
    
    ' Set the uri for the first image. Global scope is required to pass var between threads
    m.DropboxPhoto.uri = m.global.current_photo_uri

    ' This is the socket communication magic between this file and main.brs
    ' field Observer that calls changeBackground() function everytime the value of ImageSwap is changed
    m.global.observeField("ImageSwapPort", "changeBackground")

    ' field Observer that calls FadeAnimation() function everytime the value of ImageFade is changed
    m.global.observeField("ImageFadePort", "FadeAnimation")
End Function


