//
//  ViewController.swift
//  ADPassPrompt for Jamf 400 Challange
//
//  Created by Thomas Holbrook on 06/12/2017.
//  Copyright © 2017 Thomas Holbrook. All rights reserved.
//

import Cocoa
import Foundation
import AVKit
import AVFoundation
import Quartz

class ViewController: NSViewController {
    @IBOutlet weak var daysOld: NSTextField!
    @IBOutlet weak var playerView: AVPlayerView!
    @IBOutlet weak var lastChangedLabel: NSTextField!
    @IBOutlet weak var expiresDateLabel: NSTextField!
    
    @IBOutlet weak var defaultImage: IKImageView!
    @IBOutlet weak var expireLabel: NSTextField!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Empty Variables
        var filetimeInSeconds = 0.0
        
        var FILETIME = 0.0
        
        // Whats the date? We will need this at some point.
        let today = Date()
        
        func openPreferences() {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Accounts.prefPane/"))
        }
        
        //
        // https://stackoverflow.com/questions/25726436/how-to-execute-external-program-from-swift
        //
        
        func execCommand(command: String, args: [String]) -> String {
            if !command.hasPrefix("/") {
                let commandFull = execCommand(command: "/usr/bin/which", args: [command]).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                return execCommand(command: commandFull, args: args)
            } else {
                let proc = Process()
                proc.launchPath = command
                proc.arguments = args
                let pipe = Pipe()
                proc.standardOutput = pipe
                proc.launch()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                return String(data: data, encoding: String.Encoding.utf8)!
            }
        }
        
        //
        // This code is based on the informatio found here: http://www.bluethinking.com/?p=167
        //
        
        
        func convertDscldates(dsclOutput: String) -> Date {
            let dsclArray = dsclOutput.components(separatedBy: (NSCharacterSet.whitespacesAndNewlines))
            
            FILETIME = Double(dsclArray[1]) ?? 0.0
            
            filetimeInSeconds = FILETIME / 864000000000
            
            let ADSeconds = (filetimeInSeconds * 86400) - 11644473600
            
            let PassDate = Date(timeIntervalSince1970: ADSeconds)
            
            return PassDate
        }
        
        
        //
        // Who is the current user, if the user launches it themselved this is NSUserName otherwise we need to check the console!?
        // This combined with opening system preferences pushed me towards a "Login Item" we went with NSUSerName
        //
        
        
        //let consoleUser = execCommand(command: "stat", args: ["-f", "%Su", "/dev/console"])
        
        //let consoleUser = "tholbrook"
        
        let consoleUser = NSUserName()
        
        
        //Debug Line
        print(consoleUser)
        
        // DSCL Search Path
        var searchPath = "/Users/" + consoleUser
        
        // When using /dev/console we seem to get a return character, this code removes that.
        searchPath = searchPath.trimmingCharacters(in: .whitespacesAndNewlines)
        
        //Debug Line
        print("We are assessing: " + searchPath)
        
        //Go and find the last time the users password was set.
        let passLastSet = execCommand(command: "dscl", args: ["/Search", "read", searchPath, "SMBPasswordLastSet"])
        
        //Go and find the last time the users password was set.
        let passExpireDate = execCommand(command: "dscl", args: ["/Search", "read", searchPath, "msDS-UserPasswordExpiryTimeComputed"])
        
        //The last two lines should probably be done against the data from a single search!?
        
        //Check if we are dealing with a duff user, such a localuser.
        if passLastSet == "" {
            print("SMBPasswordLastSet not found - Local User?")
            exit(0)
        }
        
        if passExpireDate == "" {
            print("msDS-UserPasswordExpiryTimeComputed")
            exit(0)
        }
        
        
        // Set the image to hide the massive GAP we have when the video is not required.
        let imagePath = Bundle.main.path(forResource: "icon_backup_three", ofType:"png")
        let imageUrl = NSURL.fileURL(withPath: imagePath!)
        self.defaultImage.setImageWith(imageUrl)
        
        //Debug Line
        print("Password last set date:")
        print(convertDscldates(dsclOutput: passLastSet))
        
        //Debug Line
        print("Password Expirary Date:")
        print(convertDscldates(dsclOutput: passExpireDate))
        
        //Setup our expiration variable - we already have today at the top.
        let expire = convertDscldates(dsclOutput: passExpireDate)
        let tjhchanged = convertDscldates(dsclOutput: passLastSet)
        
        //
        let calendar = NSCalendar.current
        
        // Zero out the times on our
        let date1 = calendar.startOfDay(for: today)
        let date2 = calendar.startOfDay(for: expire)
        
        // How many days are between our dates?
        var components = calendar.dateComponents([.day], from: date1, to: date2)
        
        // Zero out the times on our
        let changedDate1 = calendar.startOfDay(for: today)
        let changedDate2 = calendar.startOfDay(for: tjhchanged)
        
        // How many days are between our dates?
        var changedcomponents = calendar.dateComponents([.day], from: tjhchanged, to: today)
        
        
        //Debug Line
        print(components)
        
        //Use our Integer as a String so we can use it in Lables and stuff.
        let days = "\(components.day!)"
        let changedDays = "\(changedcomponents.day!)"
        
        
        //If we have a HUGE day difference, our password is set to never Expire - let the user know.
        if components.day! == 10522919 {
            
            self.expireLabel.stringValue = "Does not Expire"
            
        }
        
        else if components.day! == 10522918 {
            
            self.expireLabel.stringValue = "Does not Expire"
        }
        
        //Otherwise let our user know the number of days.
            
        else {
            
            self.expireLabel.stringValue = days
        }

        //Debug Info displayed on the APP
        
        self.lastChangedLabel.stringValue = "\(convertDscldates(dsclOutput: passLastSet))"
        self.expiresDateLabel.stringValue = "\(convertDscldates(dsclOutput: passExpireDate))"
        self.daysOld.stringValue = changedDays
        
        //If we have less than 3 days we need to open up System Prefs and let our users know.
        
        if components.day! < 3 {
        
        openPreferences()
            
            //Load up the Video bundled with our App - first we define the video we want to use.
            let path = Bundle.main.path(forResource: "ChangePassword", ofType:"mov")
            let url = NSURL.fileURL(withPath: path!)
            //Hide the placeholder image, and show our Video Player.
            defaultImage.isHidden = true
            playerView.isHidden = false
            //Setup the player i.e Link it to our AVKIT Player
            let playerAV = AVPlayer(url: url as URL)
            let playerController = playerView
            playerController?.player = playerAV
            //Hit Play!
            playerAV.play()
            
        
        
        }
        
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

