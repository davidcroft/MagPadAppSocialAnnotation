//
//  ViewController.swift
//  MagPadV3
//
//  Created by Ding Xu on 3/4/15.
//  Copyright (c) 2015 Ding Xu. All rights reserved.
//

import UIKit
import CoreMotion

class ViewController: UIViewController, F53OSCClientDelegate, F53OSCPacketDestination {
    
    @IBOutlet var locLabel: UILabel!
    @IBOutlet var loadingIndicator: UIActivityIndicatorView!
    @IBOutlet var saveBtn: UIButton!
    @IBOutlet var loadBtn: UIButton!
    @IBOutlet var clearBtn: UIButton!
    
    // color btns
    var colorPickerImageView: UIImageView!
    @IBOutlet var redButton: UIButton!
    @IBOutlet var pinkButton: UIButton!
    @IBOutlet var orangeButton: UIButton!
    @IBOutlet var yellowButton: UIButton!
    @IBOutlet var greenButton: UIButton!
    @IBOutlet var blueButton: UIButton!
    @IBOutlet var purpleButton: UIButton!
    @IBOutlet var blackButton: UIButton!
    @IBOutlet var strokeWidthSlider: UISlider!
    @IBOutlet var strokeWidthText: UILabel!
    
    // OSC
    var oscClient:F53OSCClient = F53OSCClient()
    var oscServer:F53OSCServer = F53OSCServer()
    
    // average filter
    let NumColumns = 6
    let NumMinAvgCols = 2
    let NumRows = 2
    var smoothBuf = Array<Array<Double>>()
    //var smoothBuf = [Double](count: 10, repeatedValue: 0.0)
    var smoothIdx: Int = 0
    var smoothCnt: Int = 0
    var smoothAvgRow:Double = 0.0
    var smoothAvgCol:Double = 0.0
    var smoothAvgRowPrev:Double = 0.0
    var smoothAvgColPrev:Double = 0.0
    //let smoothCntTotal:Int = 5
    //var smoothFlag:Bool = false
    
    // Buffer
    var magBuf:DualArrayBuffer = DualArrayBuffer(bufSize: BUFFERSIZE)
    
    // megnetometer
    var motionManager: CMMotionManager = CMMotionManager()
    var magnetoTimer: NSTimer!
    
    // accerometer
    var acceCnt:UInt = 0
    var accePrev: Double = 0.0
    var acceCurr: Double = 0.0
    
    // scroll view
    var imageView: UIImageView!
    var scrollView: UIScrollView!
    var beginUpdate:Bool = true
    var reminderViewLabel: UILabel!
    // drawing view
    var tempImageView: UIImageView!
    var mainImageView: UIImageView!
    
    // draw
    var lastPoint = CGPoint.zeroPoint
    var red: CGFloat = CGColorGetComponents(yellowColor.CGColor)[0]
    var green: CGFloat = CGColorGetComponents(yellowColor.CGColor)[1]
    var blue: CGFloat = CGColorGetComponents(yellowColor.CGColor)[2]
    var brushWidth: CGFloat = 4.0
    var opacity: CGFloat = 0.8
    var swiped = false
    
    // Parse
    var infoTimer: NSTimer!
    var publicImageView: UIImageView!
    
    
    var debugCnt:UInt = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // init scrollView
        initScrollView()
        
        saveBtn.backgroundColor = greenColor
        saveBtn.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
        view.bringSubviewToFront(self.saveBtn)
        
        loadBtn.backgroundColor = blueColor
        loadBtn.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
        view.bringSubviewToFront(self.loadBtn)
        
        clearBtn.backgroundColor = pinkColor
        clearBtn.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
        view.bringSubviewToFront(self.clearBtn)
        moveUpCloudBtns()
        
        // 
        colorPickerImageView = UIImageView(frame: self.view.frame)
        colorPickerImageView.backgroundColor = UIColor.clearColor()
        /*self.colorPickerImageView.addSubview(redButton)
        self.colorPickerImageView.addSubview(pinkButton)
        self.colorPickerImageView.addSubview(orangeButton)
        self.colorPickerImageView.addSubview(yellowButton)
        self.colorPickerImageView.addSubview(greenButton)
        self.colorPickerImageView.addSubview(blueButton)
        self.colorPickerImageView.addSubview(purpleButton)
        self.colorPickerImageView.addSubview(blackButton)*/
        //hideColorPickerBtns()
        moveDownColorPickerBtns()
        view.bringSubviewToFront(redButton)
        view.bringSubviewToFront(pinkButton)
        view.bringSubviewToFront(orangeButton)
        view.bringSubviewToFront(yellowButton)
        view.bringSubviewToFront(greenButton)
        view.bringSubviewToFront(blueButton)
        view.bringSubviewToFront(purpleButton)
        view.bringSubviewToFront(blackButton)
        
        strokeWidthSlider.minimumValue = 2
        strokeWidthSlider.maximumValue = 20
        strokeWidthSlider.setValue(4, animated: false)
        strokeWidthText.text = "Stroke Width: \(strokeWidthSlider.value)"
        strokeWidthText.textColor = UIColor.whiteColor()
        view.bringSubviewToFront(strokeWidthSlider)
        view.bringSubviewToFront(strokeWidthText)
        
        
        /*tempImageView = UIImageView(frame: self.view.frame)
        mainImageView = UIImageView(frame: self.view.frame)
        self.view.addSubview(tempImageView)
        self.view.addSubview(mainImageView)*/
        
        // debug
        //setScrollViewOffset(6, colVal: 0.2)
    }
    
    override func viewDidAppear(animated: Bool) {
        // set up a ip addr for OSC host
        let ipAddrAlert:UIAlertController = UIAlertController(title: nil, message: "Set up IP address for OSC", preferredStyle: .Alert)
        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: {
            action in
            exit(0)
        })
        let doneAction = UIAlertAction(title: "Done", style: .Default, handler: {
            action in
            // get user input first to update total page number
            let userText:UITextField = ipAddrAlert.textFields?.first as! UITextField
            sendHost = userText.text
            println("set IP addr for send host to \(userText.text)")
        })
        ipAddrAlert.addAction(cancelAction)
        ipAddrAlert.addAction(doneAction)
        ipAddrAlert.addTextFieldWithConfigurationHandler { (textField) -> Void in
            textField.placeholder = "type in IP address here"
        }
        self.presentViewController(ipAddrAlert, animated: true, completion: nil)
        
        // init magnetometer
        self.motionManager.startMagnetometerUpdates()
        self.motionManager.startGyroUpdates()
        self.magnetoTimer = NSTimer.scheduledTimerWithTimeInterval(0.01,
            target:self,
            selector:"updateMegneto:",
            userInfo:nil,
            repeats:true)
        println("Launched magnetometer")
        
        // osc init
        self.oscServer.delegate = self
        self.oscServer.port = recvPort
        self.oscServer.startListening()
        
        // label init
        self.locLabel.text = "Current Location: 0"
        
        // buffer init
        for column in 0...NumRows {
            smoothBuf.append(Array(count:NumColumns, repeatedValue:Double()))
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // timer
    func updateMegneto(timer: NSTimer) -> Void {
        // TODO
        //println(self.magnetoTimer.timeInterval)
        if self.motionManager.magnetometerData != nil {
            let dataX = self.motionManager.magnetometerData.magneticField.x
            let dataY = self.motionManager.magnetometerData.magneticField.y
            let dataZ = self.motionManager.magnetometerData.magneticField.z
            
            // add to buffer
            if (magBuf.addDatatoBuffer(dataX, valY: dataY, valZ: dataZ)) {
                // buffer is full, send OSC data to laptop
                self.sendOSCData()
            }
            
            // accerometer
            if (acceCnt >= 50) {
                acceCnt = 0;
                let dataAccX = self.motionManager.gyroData.rotationRate.x
                let dataAccY = self.motionManager.gyroData.rotationRate.y
                let dataAccZ = self.motionManager.gyroData.rotationRate.z
                accePrev = acceCurr
                acceCurr = sqrt(dataAccX*dataAccX + dataAccY*dataAccY + dataAccZ*dataAccZ)
                let delta:Double = abs(acceCurr-accePrev)
                if (delta > 0.2) {
                    smoothCnt = NumColumns
                } else if (delta > 0.02) {
                    let temp = (Double)(NumColumns-NumMinAvgCols)*(delta-0.02)/(0.2-0.02)
                    smoothCnt = Int(temp) + NumMinAvgCols
                } else {
                    smoothCnt = NumMinAvgCols
                }
                //println("UPDATE: delta: \(acceCurr-accePrev), smoothCnt = \(smoothCnt)")
            } else {
                acceCnt += 1
            }
        }
    }
    
    func sendOSCData() -> Void {
        // create a new thread to send buffer data
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), { () -> Void in
            // send osc message
            var str:String = self.magBuf.generateStringForOSC()
            let message:F53OSCMessage = F53OSCMessage(string: "/magneto \(str)")
            self.oscClient.sendPacket(message, toHost: sendHost, onPort: sendPort)
            //println("send OSC message")
        })
    }
    
    
    // OSC
    func takeMessage(message: F53OSCMessage) -> Void {
        // suspend updating OSC
        if (!self.beginUpdate) {
            return
        }
        
        // create a new thread to get URL from parse and set webview
        //println("receive OSC message")
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), { () -> Void in
            var locRow:Double = message.arguments.first as! Double
            var locCol:Double = message.arguments.last as! Double
            
            // offset
            //locRow = locRow + 1
            locCol = locCol + 0.75
            
            self.getSmoothResult(locRow, valCol: locCol)

            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.locLabel.text = "Current Location: \(locRow), \(locCol)"
            })
            println("new location: \(locRow), \(locCol)")
            
            
            // setScrollViewOffset
            let deltaRow = (self.smoothAvgRow - self.smoothAvgRowPrev) * (self.smoothAvgRow - self.smoothAvgRowPrev)
            let deltaCol = (self.smoothAvgCol - self.smoothAvgColPrev) * (self.smoothAvgCol - self.smoothAvgColPrev)
            if (sqrt(deltaRow + deltaCol) > 0.1) {
                self.setScrollViewOffset(self.smoothAvgRow, colVal: self.smoothAvgCol)
                //self.setScrollViewOffset(locRow, colVal: locCol)
            }
        })
    }
    
    /////////////////////////////
    func getSmoothResult(valRow:Double, valCol:Double) -> Void {
        /*smoothAvgRow = (smoothAvgRow * Double(smoothCnt) + valRow) / Double(smoothCnt+1)
        smoothAvgCol = (smoothAvgCol * Double(smoothCnt) + valCol) / Double(smoothCnt+1)
        if (smoothCnt < smoothCntTotal) {
            smoothCnt = smoothCnt+1
        }
        //println("smoothAvgRow = \(smoothAvgRow), smoothAvgCol = \(smoothAvgCol)")*/
        
        // push to buf first
        smoothBuf[0][smoothIdx] = valRow
        smoothBuf[1][smoothIdx++] = valCol
        if (smoothIdx >= NumColumns) {
            smoothIdx = 0
        }
        
        // compute smoothAveRow and smoothAveCol based on smoothCnt (decided by accerometer data)
        smoothAvgRowPrev = smoothAvgRow
        smoothAvgColPrev = smoothAvgCol
        smoothAvgRow = 0
        smoothAvgCol = 0
        var tempIdx = smoothIdx-1
        var count = smoothCnt
        for var i = 0; i < count; i++ {
            if (tempIdx < 0) {
                tempIdx += NumColumns
            }
            smoothAvgRow += smoothBuf[0][tempIdx]
            smoothAvgCol += smoothBuf[1][tempIdx--]
        }
        smoothAvgRow = smoothAvgRow/Double(count)
        smoothAvgCol = smoothAvgCol/Double(count)
        println("smoothAvgRow = \(smoothAvgRow), smoothAvgCol = \(smoothAvgCol), SmoothWindow = \(count)")
    }
    /////////////////////////////
    
    // get file URL from parse
    func getURLFromParse(fileID:Int) -> NSURL {
        // check if there is an item in server
        var pdfFileURL: NSURL! = NSURL(string: "www.google.com")
        var query = PFQuery(className: "pdfFiles")
        query.whereKey("fileID", equalTo:fileID)
        var error: NSError?
        let pdfFileObjects: [PFObject] = query.findObjects(&error) as! [PFObject]
        if error == nil && pdfFileObjects.count != 0 {
            // has record in the server
            let pdfFileObject: PFObject! = pdfFileObjects.first as PFObject!
            let pdfFile: PFFile! = pdfFileObject.objectForKey("file") as! PFFile
            pdfFileURL = NSURL(string: pdfFile.url)!
            //let recordData: NSData = NSData(contentsOfURL: recordURL)!
        }
        return pdfFileURL
    }
    
    func startLoadingIndicator() {
        // start loading indicator
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.loadingIndicator.hidden = false
            self.view.bringSubviewToFront(self.loadingIndicator)
            self.loadingIndicator.startAnimating()
        })
    }
    
    func stopLoadingIndicator() {
        // hide loading indicator
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.loadingIndicator.stopAnimating()
            self.loadingIndicator.hidden = true
        })
    }
    
    // init scrollview
    func initScrollView() {
        // add scrollView
        //imageView = UIImageView(image: UIImage(named: "ScrollBackground.jpg"))
        //imageView = UIImageView(image: scaleImage(UIImage(named: "bk.jpg")!, maxDimension: 1650))
        imageView = UIImageView(image: scaleImage(UIImage(named: "bible.jpg")!, maxDimension: 1650))
        scrollView = UIScrollView(frame: view.bounds)
        scrollView.backgroundColor = UIColor.grayColor()
        //scrollView.contentSize = imageView.bounds.size
        scrollView.contentSize = view.bounds.size
        scrollView.addSubview(imageView)
        
        // public drawing init
        publicImageView = UIImageView(frame: self.imageView.frame)
        publicImageView.backgroundColor = UIColor.clearColor()
        publicImageView.image = nil
        scrollView.addSubview(publicImageView)
        
        // local drawing init
        tempImageView = UIImageView(frame: self.imageView.frame)
        mainImageView = UIImageView(frame: self.imageView.frame)
        tempImageView.backgroundColor = UIColor.clearColor()
        mainImageView.backgroundColor = UIColor.clearColor()
        scrollView.addSubview(mainImageView)
        scrollView.addSubview(tempImageView)
        
        self.view.addSubview(scrollView)
        
        // enable tap gesture
        var tapRecognizer = UITapGestureRecognizer(target: self, action: "scrollViewTapped:")
        tapRecognizer.numberOfTapsRequired = 1
        //tapRecognizer.numberOfTouchesRequired = 1
        scrollView.addGestureRecognizer(tapRecognizer)
        
        var doubleTapRecognizer = UITapGestureRecognizer(target: self, action: "scrollViewDoubleTapped:")
        doubleTapRecognizer.numberOfTapsRequired = 2
        //doubleTapRecognizer.numberOfTouchesRequired = 2
        scrollView.addGestureRecognizer(doubleTapRecognizer)
        
        tapRecognizer.requireGestureRecognizerToFail(doubleTapRecognizer)
        
        var panRecognizer = UIPanGestureRecognizer(target: self, action: "scrollViewPanned:")
        scrollView.addGestureRecognizer(panRecognizer)
    }
    
    func setScrollViewOffset(rowVal:Double, colVal:Double) {
        let height = Double(imageView.bounds.height)
        let width = Double(imageView.bounds.width)
        let xVal:Double = (colVal / pdfWidth) * width
        let yVal:Double = (rowVal / pdfHeight) * height
        if (xVal > 0 && xVal < width && yVal > 0 && yVal < height) {
            //scrollView.setContentOffset(CGPoint(x: xVal, y: yVal), animated: true)
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                UIView.animateWithDuration(1.2, delay: 0, options: UIViewAnimationOptions.AllowUserInteraction, animations: { () -> Void in
                    self.scrollView.contentOffset = CGPointMake(CGFloat(xVal), CGFloat(yVal))
                    }, completion: nil)
                /*UIView.animateWithDuration(1.2, animations: { () -> Void in
                self.scrollView.contentOffset = CGPointMake(CGFloat(xVal), CGFloat(yVal))
                })*/
            })
        }
    }
    
    func scrollViewTapped(recognizer: UITapGestureRecognizer) {
        println("single tapped")
        // disable updating
        //self.beginUpdate = false
        
        //self.view.addSubview(self.colorPickerImageView)
        //self.view.bringSubviewToFront(self.colorPickerImageView)
        if (self.redButton.center.y == self.view.frame.height-btnDir/2) {
            UIView.animateWithDuration(0.5,
                delay: 0.0,
                options: .CurveEaseInOut | .AllowUserInteraction,
                animations: {
                    self.moveDownColorPickerBtns()
                    self.moveUpCloudBtns()
                }, completion: nil)
        } else {
            UIView.animateWithDuration(0.5,
                delay: 0.0,
                options: .CurveEaseInOut | .AllowUserInteraction,
                animations: {
                    self.moveUpColorPickerBtns()
                    self.moveDownCloudBtns()
                }, completion: nil)
        }
        
        // enable updating
        //self.beginUpdate = true
    }
    
    
    func scaleImage(image: UIImage, maxDimension: CGFloat) -> UIImage {
        
        var scaledSize = CGSize(width: maxDimension, height: maxDimension)
        var scaleFactor: CGFloat
        
        if image.size.width > image.size.height {
            scaleFactor = image.size.height / image.size.width
            scaledSize.width = maxDimension
            scaledSize.height = scaledSize.width * scaleFactor
        } else {
            scaleFactor = image.size.width / image.size.height
            scaledSize.height = maxDimension
            scaledSize.width = scaledSize.height * scaleFactor
        }
        
        UIGraphicsBeginImageContext(scaledSize)
        image.drawInRect(CGRectMake(0, 0, scaledSize.width, scaledSize.height))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return scaledImage
    }
    
    func moveUpColorPickerBtns() {
        self.redButton.center.y -= btnDir
        self.pinkButton.center.y -= btnDir
        self.orangeButton.center.y -= btnDir
        self.yellowButton.center.y -= btnDir
        self.greenButton.center.y -= btnDir
        self.blueButton.center.y -= btnDir
        self.purpleButton.center.y -= btnDir
        self.blackButton.center.y -= btnDir
        self.strokeWidthSlider.center.y -= btnDir
        self.strokeWidthText.center.y -= btnDir
    }
    
    func moveDownColorPickerBtns() {
        self.redButton.center.y += btnDir
        self.pinkButton.center.y += btnDir
        self.orangeButton.center.y += btnDir
        self.yellowButton.center.y += btnDir
        self.greenButton.center.y += btnDir
        self.blueButton.center.y += btnDir
        self.purpleButton.center.y += btnDir
        self.blackButton.center.y += btnDir
        self.strokeWidthSlider.center.y += btnDir
        self.strokeWidthText.center.y += btnDir
    }
    
    func moveUpCloudBtns() {
        self.clearBtn.center.y -= 38
        self.saveBtn.center.y -= 38
        self.loadBtn.center.y -= 74
    }
    
    func moveDownCloudBtns() {
        self.clearBtn.center.y += 38
        self.saveBtn.center.y += 38
        self.loadBtn.center.y += 74
    }
    
    func scrollViewDoubleTapped(recognizer: UITapGestureRecognizer) {
        
        println("double tapped")
        
        if (self.beginUpdate) {
            // disable updating
            self.beginUpdate = false
            
            let size = UIScreen.mainScreen().bounds.height/2
            let startX = UIScreen.mainScreen().bounds.width/2-size/2
            let startY = UIScreen.mainScreen().bounds.height/2-size/2
            let labelRect = CGRectMake(startX, startY, size, size)
            let labelCenter = CGPointMake(UIScreen.mainScreen().bounds.width/2, UIScreen.mainScreen().bounds.height/2)
            drawCustomizedLabel(labelRect, center: labelCenter, str: "Stop Updating", bkColor: transparentGrayColor, duration: NSTimeInterval(0.5))
        } else {
            // continue updating
            self.beginUpdate = true
            
            let size = UIScreen.mainScreen().bounds.height/2
            let startX = UIScreen.mainScreen().bounds.width/2-size/2
            let startY = UIScreen.mainScreen().bounds.height/2-size/2
            let labelRect = CGRectMake(startX, startY, size, size)
            let labelCenter = CGPointMake(UIScreen.mainScreen().bounds.width/2, UIScreen.mainScreen().bounds.height/2)
            drawCustomizedLabel(labelRect, center: labelCenter, str: "Start Updating", bkColor: transparentPinkColor, duration: NSTimeInterval(0.5))
        }
    }
    
    func scrollViewPanned(recognizer: UIPanGestureRecognizer) {
        let x = recognizer.locationInView(tempImageView).x
        let y = recognizer.locationInView(tempImageView).y
        if (recognizer.state == UIGestureRecognizerState.Began) {
            
            //println("STATE BEGIN: (\(x), \(y))")
            
            swiped = false
            lastPoint = recognizer.locationInView(tempImageView)
            
        } else if (recognizer.state == UIGestureRecognizerState.Changed) {
            
            //println("startX = \(x), startY = \(y)")
            
            swiped = true
            let currentPoint = recognizer.locationInView(tempImageView)
            drawLineFrom(lastPoint, toPoint: currentPoint)
            // 7
            lastPoint = currentPoint
            
        } else if (recognizer.state == UIGestureRecognizerState.Ended) {
            
            //println("STATE END: (\(x), \(y))")
            
            if !swiped {
                // draw a single point
                drawLineFrom(lastPoint, toPoint: lastPoint)
            }
            
            // Merge tempImageView into mainImageView
            UIGraphicsBeginImageContext(mainImageView.frame.size)
            mainImageView.image?.drawInRect(CGRect(x: 0, y: 0, width: mainImageView.frame.size.width, height: mainImageView.frame.size.height), blendMode: kCGBlendModeNormal, alpha: 1.0)
            tempImageView.image?.drawInRect(CGRect(x: 0, y: 0, width: mainImageView.frame.size.width, height: mainImageView.frame.size.height), blendMode: kCGBlendModeNormal, alpha: opacity)
            mainImageView.image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            tempImageView.image = nil
        }
    }
    
    func drawCustomizedLabel(rect: CGRect, center: CGPoint, str: String, bkColor: UIColor, duration: NSTimeInterval) {
        if (self.reminderViewLabel != nil && self.reminderViewLabel.isDescendantOfView(self.view)) {
            self.reminderViewLabel.removeFromSuperview()
        }
        // draw a rect
        self.reminderViewLabel = UILabel(frame: rect)
        self.reminderViewLabel.backgroundColor = bkColor
        self.reminderViewLabel.textColor = UIColor.whiteColor()
        self.reminderViewLabel.alpha = 0
        self.reminderViewLabel.font = self.reminderViewLabel.font.fontWithSize(18)
        self.reminderViewLabel.center = center
        self.reminderViewLabel.textAlignment = NSTextAlignment.Center
        self.reminderViewLabel.text = str
        // set label corner to round
        self.reminderViewLabel.layer.cornerRadius = 12
        self.reminderViewLabel.layer.borderWidth = 0
        self.reminderViewLabel.layer.masksToBounds = true
        self.view.addSubview(self.reminderViewLabel)
        // display
        UIView.animateWithDuration(duration, delay: 0, options: nil, animations: { () -> Void in
            self.reminderViewLabel.alpha = 1
            }) { (finished) -> Void in
                UIView.animateWithDuration(duration, delay: 0.6, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.0, options: nil, animations: {
                    self.reminderViewLabel.alpha = 0
                    }, completion: { (finished) -> Void in
                        if (self.reminderViewLabel != nil && self.reminderViewLabel.isDescendantOfView(self.view)) {
                            self.reminderViewLabel.removeFromSuperview()
                        }
                })
        }
    }
    
    func drawLineFrom(fromPoint: CGPoint, toPoint: CGPoint) {
        // 1
        UIGraphicsBeginImageContext(mainImageView.frame.size)
        let context = UIGraphicsGetCurrentContext()
        tempImageView.image?.drawInRect(CGRect(x: 0, y: 0, width: mainImageView.frame.size.width, height: mainImageView.frame.size.height))
        // 2
        CGContextMoveToPoint(context, fromPoint.x, fromPoint.y)
        CGContextAddLineToPoint(context, toPoint.x, toPoint.y)
        // 3
        CGContextSetLineCap(context, kCGLineCapRound)
        CGContextSetLineWidth(context, brushWidth)
        CGContextSetRGBStrokeColor(context, red, green, blue, 1)
        CGContextSetBlendMode(context, kCGBlendModeNormal)
        // 4
        CGContextStrokePath(context)
        // 5
        tempImageView.image = UIGraphicsGetImageFromCurrentImageContext()
        tempImageView.alpha = opacity
        UIGraphicsEndImageContext()
    }
    
    @IBAction func clearDrawing(sender: AnyObject) {
        mainImageView.image = nil
    }
    
    @IBAction func saveDrawing(sender: AnyObject) {
        UIGraphicsBeginImageContext(mainImageView.bounds.size)
        mainImageView.image?.drawInRect(CGRect(x: 0, y: 0,
            width: mainImageView.frame.size.width, height: mainImageView.frame.size.height))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        let pngData = UIImagePNGRepresentation(image)
        
        // upload file
        // check if there is an item in server
        let imageObj = PFObject(className:"drawingImgs")
        imageObj["imgFile"] = PFFile(name: "drawing.png", data: pngData)
        var error:NSError
        var succeeded:Bool!
        imageObj.saveInBackgroundWithBlock ({
            (succeeded: Bool, error: NSError?) -> Void in
            if succeeded == true {
                println("upload successfully")
                
                // alert controller
                let alertController = UIAlertController(title: "Upload finished!", message: nil, preferredStyle: .Alert)
                // dismiss view controller automatically in a 1s
                self.presentViewController(alertController, animated: true, completion: { () -> Void in
                    // set a timer for notification
                    self.infoTimer = NSTimer.scheduledTimerWithTimeInterval(1.5,
                        target:self,
                        selector:"dismissReminder:",
                        userInfo:nil,
                        repeats:false)
                })
            }
        })
        
        UIGraphicsEndImageContext()
    }
    
    func dismissReminder(timer:NSTimer) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }

    @IBAction func loadDrawing(sender: AnyObject) {
        // disable updating
        self.beginUpdate = false
        
        self.mainImageView.image = nil
        self.publicImageView.image = nil

        // download all drawing files
        var query = PFQuery(className:"drawingImgs")
        query.findObjectsInBackgroundWithBlock { (objects:[AnyObject]!, error: NSError!) ->Void in
            if error == nil && objects != nil {
                for object in objects {
                    println(object.objectId)
                    var imageFile: PFFile = object.objectForKey("imgFile") as! PFFile
                    var imageFileData: NSData = imageFile.getData() as NSData
                    var imageDrawing: UIImage? = UIImage(data: imageFileData)
                    
                    // Merge image into publicImage
                    // public drawing init

                    /*if (self.publicImageView != nil && self.publicImageView.isDescendantOfView(self.view)) {
                        //println("yes")
                        self.publicImageView.removeFromSuperview()
                    }*/
                    
                    //let tempView = UIImageView(image: UIImage(named: "ScrollBackground.jpg"))
                    let tempView = UIImageView(image: imageDrawing)
                    //tempView.frame = self.imageView.frame
                    var frame = self.imageView.frame
                    frame.origin.x = -self.scrollView.contentOffset.x
                    frame.origin.y = -self.scrollView.contentOffset.y
                    //let tempView = UIImageView(frame: frame)
                    tempView.frame = frame
                    tempView.backgroundColor = UIColor.clearColor()
                    
                    UIGraphicsBeginImageContext(self.publicImageView.frame.size)
                    
                    self.publicImageView.image?.drawInRect(CGRect(x: 0, y: 0, width: self.publicImageView.frame.size.width, height: self.publicImageView.frame.size.height), blendMode: kCGBlendModeNormal, alpha: 1.0)
                    tempView.image?.drawInRect(CGRect(x: 0, y: 0, width: self.publicImageView.frame.size.width, height: self.publicImageView.frame.size.height), blendMode: kCGBlendModeNormal, alpha: 1.0)
                    self.publicImageView.image = UIGraphicsGetImageFromCurrentImageContext()
                    
                    UIGraphicsEndImageContext()
                }
            }
        }

        // enable updating
        self.beginUpdate = true
    }
    
    
    // button responder
    @IBAction func redBtn(sender: AnyObject) {
        println("hit red color picker button")
        red = CGColorGetComponents(colorPickerRed.CGColor)[0]
        green = CGColorGetComponents(colorPickerRed.CGColor)[1]
        blue = CGColorGetComponents(colorPickerRed.CGColor)[2]
    }
    
    @IBAction func pinkBtn(sender: AnyObject) {
        println("hit pink color picker button")
        red = CGColorGetComponents(colorPickerPink.CGColor)[0]
        green = CGColorGetComponents(colorPickerPink.CGColor)[1]
        blue = CGColorGetComponents(colorPickerPink.CGColor)[2]
    }
    
    @IBAction func orangeBtn(sender: AnyObject) {
        println("hit orange color picker button")
        red = CGColorGetComponents(colorPickerOrange.CGColor)[0]
        green = CGColorGetComponents(colorPickerOrange.CGColor)[1]
        blue = CGColorGetComponents(colorPickerOrange.CGColor)[2]
    }
    
    @IBAction func yellowBtn(sender: AnyObject) {
        println("hit yellow color picker button")
        red = CGColorGetComponents(colorPickerYellow.CGColor)[0]
        green = CGColorGetComponents(colorPickerYellow.CGColor)[1]
        blue = CGColorGetComponents(colorPickerYellow.CGColor)[2]
    }
    
    @IBAction func greenBtn(sender: AnyObject) {
        println("hit green color picker button")
        red = CGColorGetComponents(colorPickerGreen.CGColor)[0]
        green = CGColorGetComponents(colorPickerGreen.CGColor)[1]
        blue = CGColorGetComponents(colorPickerGreen.CGColor)[2]
    }
    
    @IBAction func blueBtn(sender: AnyObject) {
        println("hit blue color picker button")
        red = CGColorGetComponents(colorPickerBlue.CGColor)[0]
        green = CGColorGetComponents(colorPickerBlue.CGColor)[1]
        blue = CGColorGetComponents(colorPickerBlue.CGColor)[2]
    }
    
    @IBAction func purpleBtn(sender: AnyObject) {
        println("hit purple color picker button")
        red = CGColorGetComponents(colorPickerPurple.CGColor)[0]
        green = CGColorGetComponents(colorPickerPurple.CGColor)[1]
        blue = CGColorGetComponents(colorPickerPurple.CGColor)[2]
    }
    
    @IBAction func blackBtn(sender: AnyObject) {
        println("hit black color picker button")
        red = CGColorGetComponents(colorPickerBlack.CGColor)[0]
        green = CGColorGetComponents(colorPickerBlack.CGColor)[1]
        blue = CGColorGetComponents(colorPickerBlack.CGColor)[2]
    }
    
    @IBAction func strokeWidthChanged(sender: UISlider) {
        let currentValue = Int(sender.value)
        //strokeWidthSlider.setValue(4, animated: false)
        strokeWidthText.text = "Stroke Width: \(currentValue)"
        brushWidth = CGFloat(currentValue)
    }
}
