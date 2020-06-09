//
//  ViewController.swift
//  contacttracing
//
//  Created by Syafiq Mastor on 06/06/2020.
//  Copyright © 2020 syafiq. All rights reserved.
//

import UIKit
import CoreBluetooth

let cellIdentifier = "messageCell"

class MessageViewController: UITableViewController {
    /**
     * @property
     * The left button to use in the nav bar.
     */
    var leftBarButton: UIBarButtonItem! {
        get {
            return navigationItem.leftBarButtonItem
        }
        set(leftBarButton) {
            navigationItem.leftBarButtonItem = leftBarButton
        }
    }
    /**
     * @property
     * The right button to use in the nav bar.
     */
    var rightBarButton: UIBarButtonItem! {
        get {
            return navigationItem.rightBarButtonItem
        }
        set(rightBarButton) {
            navigationItem.rightBarButtonItem = rightBarButton
        }
    }
    
    var messages = [String]()
    var centralManager: CBCentralManager!
    
    /**
     * @property
     * This class lets you check the permission state of Nearby for the app on the current device.  If
     * the user has not opted into Nearby, publications and subscriptions will not function.
     */
    var nearbyPermission: GNSPermission!
    
    /**
     * @property
     * The message manager lets you create publications and subscriptions.  They are valid only as long
     * as the manager exists.
     */
    
    var messageMgr: GNSMessageManager?
    var publication: GNSPublication?
    var subscription: GNSSubscription?
    let notificationCenter = UNUserNotificationCenter.current()
    
    lazy var dateFormatter : DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm dd MMM yy"
        return formatter
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.classForCoder(), forCellReuseIdentifier: cellIdentifier)
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        // Set up the message view navigation buttons.
        nearbyPermission = GNSPermission(changedHandler: {[unowned self] granted in
            self.navigationItem.leftBarButtonItem =
                UIBarButtonItem(title: String(format: "%@ Nearby", granted ? "Deny" : "Allow"),
                                style: .plain, target: self, action: #selector(self.toggleNearbyPermission))
        })
        setupStartStopButton()
        
        // Enable debug logging to help track down problems.
        GNSMessageManager.setDebugLoggingEnabled(true)
        
        // Create the message manager, which lets you publish messages and subscribe to messages
        // published by nearby devices.
        messageMgr = GNSMessageManager(apiKey: kMyAPIKey,
                                       paramsBlock: {(params: GNSMessageManagerParams?) -> Void in
                                        guard let params = params else { return }

                                        // This is called when Bluetooth permission is enabled or disabled by the user.
                                        
                                        params.bluetoothPermissionErrorHandler = { hasError in
                                            if (hasError) {
                                                print("Nearby works better if Bluetooth use is allowed")
                                            }
                                        }
                                        // This is called when Bluetooth is powered on or off by the user.
                                        params.bluetoothPowerErrorHandler = { hasError in
                                            if (hasError) {
                                                print("Nearby works better if Bluetooth is turned on")
                                            }
                                        }
        })
        
    }
    
    func addMessage(_ message: String!) {
        messages.append(message.copy() as! String)
        tableView.reloadData()
    }
    
    func removeMessage(_ message: String!) {
        if let index = messages.firstIndex(of: message)
        {
            messages.remove(at: index)
        }
        tableView.reloadData()
    }
    
    // MARK: - UITableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell! = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        cell.textLabel?.text = messages[indexPath.row]
        return cell
    }
    
    
    // MARK: - UItableViewDelegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    /// Sets up the right bar button to start or stop sharing, depending on current sharing mode.
    func setupStartStopButton() {
        let isSharing = (publication != nil)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: isSharing ? "Stop" : "Start",
                                                               style: .plain,
                                                               target: self, action: isSharing ? #selector(self.stopSharing) :  #selector(self.startSharingWithRandomName))
    }

    /// Starts sharing with a randomized name.
    @objc func startSharingWithRandomName() {
        let deviceName = UIDevice.current.name
//        let randomName = String(format:"Anonymous fanta %d", arc4random() % 100)
        startSharing(withName: deviceName)
        setupStartStopButton()
    }

    /// Stops publishing/subscribing.
    @objc func stopSharing() {
        publication = nil
        subscription = nil
        self.title = ""
        setupStartStopButton()
    }

    /// Toggles the permission state of Nearby.
    @objc func toggleNearbyPermission() {
        GNSPermission.setGranted(!GNSPermission.isGranted())
    }


    /// Starts publishing the specified name and scanning for nearby devices that are publishing
    /// their names.
    func startSharing(withName name: String) {
        if let messageMgr = self.messageMgr {
            // Show the name in the message view title and set up the Stop button.
            self.title = name
            
            let stringDate = dateFormatter.string(from: Date())
            let allString = name + " at " + stringDate
            // Publish the name to nearby devices.
            let pubMessage: GNSMessage = GNSMessage(content: allString.data(using: .utf8,
                                                                       allowLossyConversion: true))

            publication = messageMgr.publication(with: pubMessage, paramsBlock: { (params: GNSPublicationParams?) in
                params?.strategy = GNSStrategy(paramsBlock: { (params: GNSStrategyParams?) in
                    guard let params = params else { return }
                    params.discoveryMediums = .BLE
                    params.allowInBackground = true
                })
            })

            // Subscribe to messages from nearby devices and display them in the message view.
            subscription = messageMgr.subscription(messageFoundHandler: { [unowned self] (message: GNSMessage?) -> Void  in
                guard let message = message else { return }
                let messageString = String(data: message.content, encoding:.utf8) ?? "Nothing"
                self.addMessage(messageString)

                // Send a local notification if not in the foreground.
                if UIApplication.shared.applicationState != .active {
                    let localNotification = UNMutableNotificationContent()
                    localNotification.body = messageString
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)

                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: localNotification, trigger: trigger)
                    self.notificationCenter.add(request)
                }
                }, messageLostHandler: { [unowned self](message: GNSMessage?) -> Void in
                    guard let message = message else { return }
                    self.removeMessage(String(data: message.content, encoding: .utf8))
                }, paramsBlock: { (params: GNSSubscriptionParams?) in
                    params?.strategy = GNSStrategy(paramsBlock: { (params: GNSStrategyParams?) in
                        guard let params = params else { return }
                        params.discoveryMediums = .BLE
                        params.allowInBackground = true
                    })
            })

        }
    }

}

extension MessageViewController : CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unknown:
            print("central.state is .unknown")
        case .resetting:
            print("central.state is .resetting")
        case .unsupported:
            print("central.state is .unsupported")
        case .unauthorized:
            print("central.state is .unauthorized")
        case .poweredOff:
            print("central.state is .poweredOff")
        case .poweredOn:
            print("central.state is .poweredOn")
            centralManager.scanForPeripherals(withServices: [])
        @unknown default:
            fatalError()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let power = advertisementData[CBAdvertisementDataTxPowerLevelKey] as? Double{
//        print("Distance for \(power), \(RSSI) is \(pow(10, ((power - Double(truncating: RSSI))/20)))")
            print("distance :\(calculateDistance(txCalibratedPower: power, rssi: RSSI))")
        }
    }
    
    
    func calculateDistance(txCalibratedPower : Double, rssi RSSI : NSNumber) -> Double {
        
        let ratio = Double(truncating: RSSI) / txCalibratedPower
        
        if ratio < 1.0 {
            return pow(10, ratio)
        } else {
            let accuracy = 0.89976 * pow(ratio, 7.7095) + 0.111
            return accuracy
        }
        
        
    }
}
