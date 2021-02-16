//
//  DepthViewController.swift
//  Remote Collaborative Annotation
//
//  Created by Zeju Qiu on 02.01.21.
//

import UIKit
import Metal
import MetalKit
import ARKit
import RealityKit
import AVFoundation
import Foundation
import SceneKit.ModelIO
import ModelIO
import Metal
import simd

final class DepthViewController: UIViewController, ARSessionDelegate {

    private let isUIEnabled = true
    @IBOutlet weak var statusText: UILabel!
    private let confidenceControl = UISegmentedControl(items: ["Low", "Medium", "High"])
    private let rgbRadiusSlider = UISlider()
    
    private let session = ARSession()
    private var renderer: Renderer!
    
    var pointCloudPos : [SIMD3<Float>] = []
    var pointCloudColor : [SIMD3<Int>] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }
        
        session.delegate = self
        
        // Set the view to use the default device
        if let view = view as? MTKView {
            view.device = device

            view.backgroundColor = UIColor.clear
            // we need this to enable depth test
            view.depthStencilPixelFormat = .depth32Float
            view.contentScaleFactor = 1
            view.delegate = self

            // Configure the renderer to draw to the view
            renderer = Renderer(session: session, metalDevice: device, renderDestination: view)
            renderer.drawRectResized(size: view.bounds.size)
        }
        
        // Confidence control
        confidenceControl.selectedSegmentIndex = renderer.confidenceThreshold
        confidenceControl.selectedSegmentIndex = 1
        confidenceControl.addTarget(self, action: #selector(viewValueChanged), for: .valueChanged)
        
        // RGB Radius control
        rgbRadiusSlider.minimumValue = 0
        rgbRadiusSlider.maximumValue = 1.5
        rgbRadiusSlider.isContinuous = true
        rgbRadiusSlider.value = renderer.rgbRadius
        rgbRadiusSlider.addTarget(self, action: #selector(viewValueChanged), for: .valueChanged)
        
        let stackView = UIStackView(arrangedSubviews: [confidenceControl, rgbRadiusSlider])
        stackView.isHidden = !isUIEnabled
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 20
        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -50)
        ])
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a world-tracking configuration, and
        // enable the scene depth frame-semantic.
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = .sceneDepth

        // Run the view's session
        session.run(configuration)
        
        // The screen shouldn't dim during AR experiences.
        UIApplication.shared.isIdleTimerDisabled = true
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    @objc
    private func viewValueChanged(view: UIView) {
        switch view {
            
        case confidenceControl:
            renderer.confidenceThreshold = confidenceControl.selectedSegmentIndex
            
        case rgbRadiusSlider:
            renderer.rgbRadius = rgbRadiusSlider.value
            
        default:
            break
        }
    }
    
    // Auto-hide the home indicator to maximize immersion in AR experiences.
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    // Hide the status bar to maximize immersion in AR experiences.
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user.
        guard error is ARError else { return }
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        DispatchQueue.main.async {
            // Present an alert informing about the error that has occurred.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                if let configuration = self.session.configuration {
                    self.session.run(configuration, options: .resetSceneReconstruction)
                }
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    @IBAction func frontalScan(_ sender: Any) {
        (self.pointCloudPos, self.pointCloudColor) = self.renderer.savePointsToFile()
        var colorString : String = ""
        var posString : String = ""
        print(pointCloudColor.count)
        print(pointCloudPos.count)
        for i in 0..<pointCloudColor.count {
            colorString = colorString + String(pointCloudColor[i].x)
            colorString = colorString + "\n"
            colorString = colorString + String(pointCloudColor[i].y)
            colorString = colorString + "\n"
            colorString = colorString + String(pointCloudColor[i].z)
            colorString = colorString + "\n"
            posString = posString + String(pointCloudPos[i].x)
            posString = posString + "\n"
            posString = posString + String(pointCloudPos[i].y)
            posString = posString + "\n"
            posString = posString + String(pointCloudPos[i].z)
            posString = posString + "\n"
        }
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let urlCOL = documentsPath.appendingPathComponent("color.txt")
        let urlPOS = documentsPath.appendingPathComponent("position.txt")
        
        do {
            try colorString.write(to: urlCOL, atomically: true, encoding: String.Encoding.utf8)
            try posString.write(to: urlPOS, atomically: true, encoding: String.Encoding.utf8)
            self.statusText.text = "Frontal scan successful"
        } catch {
            self.statusText.text = "Could not write to file"
        }
    }
    
    @IBAction func dorsalScan(_ sender: Any) {
//        self.pointCloudPos = []
//        self.pointCloudColor = []
        (self.pointCloudPos, self.pointCloudColor) = self.renderer.savePointsToFile()
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let urlCOL = documentsPath.appendingPathComponent("color.txt")
        let urlPOS = documentsPath.appendingPathComponent("position.txt")
        var colorString = try! String(contentsOf: urlCOL, encoding: .utf8)
        var posString = try! String(contentsOf: urlPOS, encoding: .utf8)
        print(pointCloudColor.count)
        print(pointCloudPos.count)
        for i in 0..<pointCloudColor.count {
            colorString = colorString + String(pointCloudColor[i].x)
            colorString = colorString + "\n"
            colorString = colorString + String(pointCloudColor[i].y)
            colorString = colorString + "\n"
            colorString = colorString + String(pointCloudColor[i].z)
            colorString = colorString + "\n"
            posString = posString + String(pointCloudPos[i].x)
            posString = posString + "\n"
            posString = posString + String(pointCloudPos[i].y)
            posString = posString + "\n"
            posString = posString + String(pointCloudPos[i].z)
            posString = posString + "\n"
        }
        do {
            try colorString.write(to: urlCOL, atomically: true, encoding: String.Encoding.utf8)
            try posString.write(to: urlPOS, atomically: true, encoding: String.Encoding.utf8)
            self.statusText.text = "Dorsal scan successful"
        } catch {
            self.statusText.text = "Could not write to file"
        }
    }
    
    var mdlMesh = MDLMesh()
    
    @IBAction func savePointCloudPressed(_ sender: Any) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let urlCOL = documentsPath.appendingPathComponent("color.txt")
        let urlPOS = documentsPath.appendingPathComponent("position.txt")
        let colorFile = try! String(contentsOf: urlCOL, encoding: .utf8)
        let posFile = try! String(contentsOf: urlPOS, encoding: .utf8)
        let colorArray = colorFile.components(separatedBy: "\n")
        let posArray = posFile.components(separatedBy: "\n")
        var colorArrayFloat: [Float] = []
        var posArrayFloat: [Float] = []
        for i in 0..<(posArray.count-1)/3 {
            colorArrayFloat.append(Float(colorArray[i*3]) ?? 0.0)
            colorArrayFloat.append(Float(colorArray[i*3+1]) ?? 0.0)
            colorArrayFloat.append(Float(colorArray[i*3+2]) ?? 0.0)
            posArrayFloat.append(Float(posArray[i*3]) ?? 0.0)
            posArrayFloat.append(Float(posArray[i*3+1]) ?? 0.0)
            posArrayFloat.append(Float(posArray[i*3+2]) ?? 0.0)
        }
        
        self.statusText.text = "Write to file successfully"
        /*
        let urlSCN = documentsPath.appendingPathComponent("scene_scan.obj")
        let asset = MDLAsset(url: urlSCN)
//        let scene = SCNScene(mdlAsset: asset)
        
        guard let object = asset.object(at: 0) as? MDLMesh else {
            fatalError("Failed to get mesh from asset.")
        }
        
        self.mdlMesh = object
        
        var vertexData: [Float] = []
        var indexData: [UInt32] = []
        var validVertexData: [Int] = []
        var validIndexData: [UInt32] = []
        var vertexColor: [Float] = []
        // print out the vertexes
        let vbuf = self.mdlMesh.vertexBuffers[0]
        let vbufmap = vbuf.map()
        let layout = self.mdlMesh.vertexDescriptor.layouts.firstObject as! MDLVertexBufferLayout
        let stride = layout.stride
        assert(vbuf.length == self.mdlMesh.vertexCount*stride)
        for i in 0..<self.mdlMesh.vertexCount {
            let v = (vbufmap.bytes+i*stride).bindMemory(to: SIMD3<Float>.self, capacity: 1).pointee
            vertexData.append(v.x)
            vertexData.append(v.y)
            vertexData.append(v.z)
            validVertexData.append(i)
//            if self.upperBound.x >= v.x && self.upperBound.y > v.y && self.upperBound.z > v.z && self.lowerBound.x <= v.x && self.lowerBound.y <= v.y && self.lowerBound.z <= v.z {
//                vertexData.append(v)
//                validVertexData.append(i)
//            }
//            vertexData.append(v)
//            validVertexData.append(i)
            var minDist = Float(1000)
            var minDistIdx = 0
            for i in 0..<(posArrayFloat.count)/3 {
                let a = simd_float3(x: v.x, y: v.y, z: v.z)
                let b = simd_float3(x: posArrayFloat[i*3], y: posArrayFloat[i*3+1], z: posArrayFloat[i*3+2])
                let dist = simd_distance(a, b)
//                let dist = pow((posArrayFloat[i*3] - v.x), 2) + pow((posArrayFloat[i*3+1] - v.y), 2) + pow((posArrayFloat[i*3+2] - v.z), 2)
                if dist < minDist {
                    minDist = dist
                    minDistIdx = i
                }
            }
            vertexColor.append(colorArrayFloat[minDistIdx*3])
            vertexColor.append(colorArrayFloat[minDistIdx*3+1])
            vertexColor.append(colorArrayFloat[minDistIdx*3+2])
        }
        let subMeshCount = (self.mdlMesh.submeshes?.count ?? 0) as Int
        for i in 0..<subMeshCount {
            let submeshObj = self.mdlMesh.submeshes?[i] as! MDLSubmesh
            let indexCountObj = submeshObj.indexCount
            let ibuf = submeshObj.indexBuffer
            let ibufmap = ibuf.map()
            let istride = 4
            for i in 0..<indexCountObj {
                let u = (ibufmap.bytes+i*istride).bindMemory(to: UInt32.self, capacity: 1).pointee
                indexData.append(u)
            }
            for i in 0..<indexCountObj/3 {
                if validVertexData.contains(Int(indexData[i*3])) && validVertexData.contains(Int(indexData[i*3+1])) && validVertexData.contains(Int(indexData[i*3+2])){
                    validIndexData.append(indexData[i*3])
                    validIndexData.append(indexData[i*3+1])
                    validIndexData.append(indexData[i*3+2])
                }
            }
        }
        var meshString : String = ""
        for i in 0..<(vertexData.count)/3 {
            meshString = meshString + "v "
            meshString = meshString + String(vertexData[i*3])
            meshString = meshString + " "
            meshString = meshString + String(vertexData[i*3+1])
            meshString = meshString + " "
            meshString = meshString + String(vertexData[i*3+2])
            meshString = meshString + " "
            meshString = meshString + String(vertexColor[i*3])
            meshString = meshString + " "
            meshString = meshString + String(vertexColor[i*3+1])
            meshString = meshString + " "
            meshString = meshString + String(vertexColor[i*3+2])
            meshString = meshString + "\n"
            print("vertex index", i)
        }
        for i in 0..<(validIndexData.count)/3 {
            meshString = meshString + "f "
            meshString = meshString + String(validIndexData[i*3]+1)
            meshString = meshString + " "
            meshString = meshString + String(validIndexData[i*3+1]+1)
            meshString = meshString + " "
            meshString = meshString + String(validIndexData[i*3+2]+1)
            meshString = meshString + "\n"
            print("data index", i)
        }
        do {
            try meshString.write(to: urlMESH, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            print("couldn't write to file")
        }
        meshString = ""
        print("write to file successed")
         */
    }
}

// MARK: - MTKViewDelegate

extension DepthViewController: MTKViewDelegate {
    // Called whenever view changes orientation or layout is changed
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        renderer.drawRectResized(size: size)
    }
    
    // Called whenever the view needs to render
    func draw(in view: MTKView) {
        renderer.draw()
    }
}

// MARK: - RenderDestinationProvider

protocol RenderDestinationProvider {
    var currentRenderPassDescriptor: MTLRenderPassDescriptor? { get }
    var currentDrawable: CAMetalDrawable? { get }
    var colorPixelFormat: MTLPixelFormat { get set }
    var depthStencilPixelFormat: MTLPixelFormat { get set }
    var sampleCount: Int { get set }
}

extension MTKView: RenderDestinationProvider {
    
}

