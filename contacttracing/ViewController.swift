//
//  ViewController.swift
//  contacttracing
//
//  Created by Syafiq Mastor on 06/06/2020.
//  Copyright © 2020 syafiq. All rights reserved.
//

import UIKit
import CoreBluetooth

let cellIdentifier = "NearbyCell"

class MessageViewController: UITableViewController {
    
    var messages = [Nearby]()
    var centralManager: CBCentralManager!
    var peripheralManager : CBPeripheralManager?
    var nearbyPermission: GNSPermission!
    var messageMgr: GNSMessageManager?
    var publication: GNSPublication?
    var subscription: GNSSubscription?
    let notificationCenter = UNUserNotificationCenter.current()
    let userDefaults = UserDefaults.standard
    lazy var dateFormatter : DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm dd MMM yy"
        return formatter
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(UINib(nibName: cellIdentifier, bundle: nil), forCellReuseIdentifier: cellIdentifier)
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        
        
        let notificationCenter = NotificationCenter.default
           notificationCenter.addObserver(self, selector: #selector(appMovedToForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        
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
    
    @objc func appMovedToForeground() {
        print("App moved to background!")
//        retrieveLocal()
    }
    
    func addMessage(_ message: String!) {
        
        let msg = message.copy() as! String
        let nearby = Nearby(type: "Nearby API", title: msg, date: Date(), multiplier: "Multiplier not available", rssi: "RSSI not available")
        messages.append(nearby)
        tableView.reloadData()
    }
    
    func addNearby(_ nearby: Nearby) {
        
        messages.append(nearby)
        tableView.reloadData()
    }
    
    func removeMessage(_ message: String!) {
        
        if let index = messages.firstIndex(where: {$0.title.lowercased() == message.lowercased()})
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
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? NearbyCell else { return UITableViewCell() }
        cell.add(nearby: messages[indexPath.row])
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
        setupTimerToScan()
        let cbuuid = CBUUID(string: "E20A39F4-73F5-4BC4-A12F-17D1AD07A961")
        self.centralManager.scanForPeripherals(withServices: [cbuuid])
    }

    func setupTimerToScan() {
        _ = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { (timer) in
            print("scan around again")
//            self.centralManager.stopScan()
            let cbuuid = CBUUID(string: "E20A39F4-73F5-4BC4-A12F-17D1AD07A961")
            self.centralManager.scanForPeripherals(withServices: [cbuuid])
        }
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
            
            // Publish the name to nearby devices.
            let pubMessage: GNSMessage = GNSMessage(content: name.data(using: .utf8,
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
                    
//                    self.saveLocally(message: messageString)
                    
                    let localNotification = UNMutableNotificationContent()
                    localNotification.body = messageString
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
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
    
    func saveLocally(message : String) {
        let nearby = Nearby(type: "Nearby API", title: message, date: Date(), isBackground: true, multiplier: "Multiplier not available", rssi: "RSSI not available")
        let userDefaults = UserDefaults.standard
        let encodedData: Data = NSKeyedArchiver.archivedData(withRootObject: nearby)
        userDefaults.set(encodedData, forKey: "background")
        userDefaults.synchronize()
    }
    
    func retrieveLocal() {
        guard let decoded  = userDefaults.data(forKey: "background") else { return }
        guard let decodedNearby = NSKeyedUnarchiver.unarchiveObject(with: decoded) as? Nearby else { return }
        self.messages.append(decodedNearby)
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
        @unknown default:
            fatalError()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let power = advertisementData[CBAdvertisementDataTxPowerLevelKey] as? Double{
//        print("Distance for \(power), \(RSSI) is \(pow(10, ((power - Double(truncating: RSSI))/20)))")
            let id = peripheral.identifier
            let name = peripheral.name ?? String(describing: id)
            print("distance from \(peripheral) :\(calculateDistance(txCalibratedPower: power, rssi: RSSI))")
            
            let nearby = Nearby(type: "Bluetooth", title: name, date: Date(), isBackground: false, multiplier: "txCalibratedPower : \(power)", rssi: "RSSI : \(RSSI)")
            self.addNearby(nearby)
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

extension MessageViewController : CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        
    }
    
    
}
