/*
* Copyright (c) 2020, Nordic Semiconductor
* All rights reserved.
*
* Redistribution and use in source and binary forms, with or without modification,
* are permitted provided that the following conditions are met:
*
* 1. Redistributions of source code must retain the above copyright notice, this
*    list of conditions and the following disclaimer.
*
* 2. Redistributions in binary form must reproduce the above copyright notice, this
*    list of conditions and the following disclaimer in the documentation and/or
*    other materials provided with the distribution.
*
* 3. Neither the name of the copyright holder nor the names of its contributors may
*    be used to endorse or promote products derived from this software without
*    specific prior written permission.
*
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
* ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
* IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
* INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
* NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
* PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
* WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
* ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
* POSSIBILITY OF SUCH DAMAGE.
*/



import UIKit
import CoreBluetooth
import AEXML

extension UIImage {
    convenience init?(name: String, systemName: String) {
        if #available(iOS 13, *) {
            self.init(systemName: systemName)
        } else {
            self.init(named: name)
        }
    }
}

class UARTViewController: UIViewController, AlertPresenter {

    let btManager: BluetoothManager!
    
    @IBOutlet private var disconnectBtn: NordicButton!
    @IBOutlet private var deviceNameLabel: UILabel!
    @IBOutlet private var saveLoadButton: UIButton!
    @IBOutlet private var presetName: UILabel!
    @IBOutlet private var pageControl: UIPageControl!
    
    @IBOutlet private var collectionView: UICollectionView!
    
    private var presets: [UARTPreset] = []
    private let coreDataUtil: UARTCoreDataUtil
    
    private weak var router: UARTRouter?
    private var activePresetView: UARTPresetCollectionView?
    
    var deviceName: String = "" {
        didSet {
            deviceNameLabel.text = "Connected to \(deviceName)"
        }
    }
    
    init(bluetoothManager: BluetoothManager, uartRouter: UARTRouter, coreDataUtil: UARTCoreDataUtil = UARTCoreDataUtil()) {
        btManager = bluetoothManager
        router = uartRouter
        self.coreDataUtil = coreDataUtil
        super.init(nibName: nil, bundle: .main)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = "UART"
        tabBarItem = UITabBarItem(title: "Preset", image: TabBarIcon.uartPreset.image, selectedImage: TabBarIcon.uartPreset.filledImage)
        
        disconnectBtn.style = .destructive
        
        collectionView.register(type: UARTPresetCollectionViewCell.self)
        collectionView.register(type: AddUARTPresetCell.self)
        
        self.presets = try! coreDataUtil.getPresets(options: .all)
        
        collectionView.decelerationRate = .fast
        
        pageControl.backgroundColor = .clear
        pageControl.tintColor = .nordicBlue
    }
    
    @IBAction func disconnect() {
        btManager.cancelPeripheralConnection()
    }
    
    @IBAction func recordMacros() {
        
    }
}

extension UARTViewController: UARTNewCommandDelegate {
    func createdNewCommand(_ viewController: UARTNewCommandViewController, command: UARTCommandModel, index: Int) {
        viewController.dismsiss()
        
        activePresetView?.preset.commands[index] = command
        activePresetView?.reloadData()
        try! CoreDataStack.uart.viewContext.save()
    }
    
}

extension UARTViewController: UARTPresetCollectionViewDelegate {
    func selectedCommand(_ presetView: UARTPresetCollectionView, command: UARTCommandModel, at index: Int) {
        activePresetView = presetView
        
        guard !(command is EmptyModel) else {
            openPresetEditor(with: command, index: index)
            return
        }
        
        btManager.send(command: command)
    }
    
    func longTapAtCommand(_ presetView: UARTPresetCollectionView, command: UARTCommandModel, at index: Int) {
        openPresetEditor(with: command, index: index)
        
        activePresetView = presetView
    }
}

extension UARTViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        pageControl.numberOfPages = presets.count
        return presets.count + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        guard indexPath.row != presets.count else {
            return collectionView.dequeueCell(ofType: AddUARTPresetCell.self, for: indexPath)
        }
        
        let cell = collectionView.dequeueCell(ofType: UARTPresetCollectionViewCell.self, for: indexPath)
        cell.viewController = self
        cell.presetCollectionView.presetDelegate = self
        cell.preset = presets[indexPath.row]
        
        return cell
    }
    
}

extension UARTViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        var side = min(collectionView.frame.size.width, collectionView.frame.size.height)
        let lineSpacing = (collectionView.collectionViewLayout as! UICollectionViewFlowLayout).minimumLineSpacing
        
        side -= lineSpacing / 2
        
        return CGSize(width: side, height: side + 40)
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        
        let lineSpacing = (collectionView.collectionViewLayout as! UICollectionViewFlowLayout).minimumLineSpacing
        
        let pageWidth = scrollView.frame.width + lineSpacing / 2
        
        let currentPageNumber = round(scrollView.contentOffset.x / pageWidth)
        let maxPageNumber = CGFloat(collectionView?.numberOfItems(inSection: 0) ?? 0)
        
        var pageNumber = round(targetContentOffset.pointee.x / pageWidth)
        pageNumber = max(0, currentPageNumber - 1, pageNumber)
        pageNumber = min(maxPageNumber, currentPageNumber + 1, pageNumber)
        
        pageControl.currentPage = Int(pageNumber)
        
        targetContentOffset.pointee.x = pageNumber * pageWidth
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        presets += [UARTPreset.empty]
        
        collectionView.reloadData()
    }
}