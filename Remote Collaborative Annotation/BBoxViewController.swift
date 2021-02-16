//
//  BBoxViewController.swift
//  Remote Collaborative Annotation
//
//  Created by Zeju Qiu on 29.12.20.
//

import UIKit
import ARKit
import RealityKit
import AVFoundation
import Foundation
import MetalKit
import SceneKit.ModelIO
import ModelIO
import Metal
import simd

class BBoxViewController: UIViewController, ARSCNViewDelegate, UINavigationControllerDelegate {


    @IBOutlet weak var statusText: UILabel!
    @IBOutlet weak var sceneView: ARSCNView!
    
    let configuration = ARWorldTrackingConfiguration()
    
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var boundingBox: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
            
        configuration.planeDetection = [.horizontal, .vertical] // both plane detection
        configuration.environmentTexturing = .automatic // make it more realistic
        

        // Do any additional setup after loading the view.
        self.sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showWorldOrigin]
        self.sceneView.session.run(configuration)
        self.sceneView.delegate = self

    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    var currentPositionofCamera = SCNVector3()
    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        guard let pointOfView = sceneView.pointOfView else { return }
        let transform = pointOfView.transform
        let orientation = SCNVector3(-transform.m31, -transform.m32, -transform.m33)
        let location = SCNVector3(transform.m41, transform.m42, transform.m43)
        currentPositionofCamera = SCNVector3Make(orientation.x + location.x, orientation.y + location.y, orientation.z + location.z)
        DispatchQueue.main.async {
            let pointer = SCNNode()
            let sphere = SCNSphere(radius: 0.01)
            pointer.geometry = sphere
            pointer.position = self.currentPositionofCamera
            pointer.name = "Pointer"
            pointer.geometry?.firstMaterial?.diffuse.contents = UIColor.red
            self.sceneView.scene.rootNode.enumerateChildNodes { (node, _) in
                if node.name == "Pointer" {
                    node.removeFromParentNode()
                }
            }
            self.sceneView.scene.rootNode.addChildNode(pointer)
        }
    }
    
   
    var Bound = SCNVector3(0, 0, 0)
    var upperBound = SCNVector3(0, 0, 0)
    var lowerBound = SCNVector3(0, 0, 0)
    var maxBB = SCNVector3(0.0, 0.0, 0.0)
    var minBB = SCNVector3(0.0, 0.0, 0.0)
    var count = 0
    @IBAction func boundingBoxPressed(_ sender: Any) {
        count = count + 1
        let node = SCNNode(geometry: SCNSphere(radius: 0.01))
        node.position = self.currentPositionofCamera
        node.geometry?.firstMaterial?.diffuse.contents = UIColor.red
        node.name = "boundingboxpoint"
        self.sceneView.scene.rootNode.addChildNode(node)
        self.statusText.text = "Add vertex " + String(count)
        self.Bound = self.currentPositionofCamera
        if count == 1 {
            self.maxBB.x = self.Bound.x
            self.maxBB.y = self.Bound.y
            self.maxBB.z = self.Bound.z
            self.minBB.x = self.Bound.x
            self.minBB.y = self.Bound.y
            self.minBB.z = self.Bound.z
        }
        
        self.maxBB.x = max(self.maxBB.x, self.Bound.x)
        self.maxBB.y = max(self.maxBB.y, self.Bound.y)
        self.maxBB.z = max(self.maxBB.z, self.Bound.z)
        self.minBB.x = min(self.minBB.x, self.Bound.x)
        self.minBB.y = min(self.minBB.y, self.Bound.y)
        self.minBB.z = min(self.minBB.z, self.Bound.z)
        
        if count == 8 {
            self.boundingBox.isEnabled = false
            let x = CGFloat(self.maxBB.x - self.minBB.x)
            let z = CGFloat(self.maxBB.z - self.minBB.z)
            let y = CGFloat(self.maxBB.y - self.minBB.y)
            position.x = Float(self.maxBB.x - (self.maxBB.x - self.minBB.x)/2)
            position.y = Float(self.maxBB.y - (self.maxBB.y - self.minBB.y)/2)
            position.z = Float(self.maxBB.z - (self.maxBB.z - self.minBB.z)/2)
            /*
            let ax = CGFloat(self.maxBB.x - position.x)
            let az = CGFloat(self.maxBB.z - position.z)
            let bx = x / 2
            let bz = z / 2
            let cx = ax - bx
            let cz = az - bz
            let a = sqrt((ax)*(ax)+(az)*(az))
            let b = sqrt((bx)*(bx)+(bz)*(bz))
            let c = sqrt((cx)*(cx)+(cz)*(cz))
            let alpha = acos((a*a + b*b - c*c) / (2*a*b))*/

            
            let boundingBoxNode = BlackMirrorzBoundingBox(width: x, height: y, length: z)
            // Add It To The ARSCNView
            self.sceneView.scene.rootNode.enumerateChildNodes { (node, _) in
                if node.name == "boundingboxpoint" {
                    node.removeFromParentNode()
                }
            }
            
            self.sceneView.scene.rootNode.addChildNode(boundingBoxNode)
            boundingBoxNode.position = position
//            self.boundingBoxUpper.isEnabled = true
//            self.boundingBoxLower.isEnabled = true
            self.statusText.text = "Boundingbox show"
            count = 0
        }
    }
    
    @IBAction func loadColoredMesh(_ sender: Any) {
//        let boundingBoxNode = BlackMirrorzBoundingBox(width: 0.1, height: 0.1, length: 0.1)
        // Add It To The ARSCNView
//        boundingBoxNode.position = position
//        self.sceneView.scene.rootNode.addChildNode(boundingBoxNode)
        
        let geoScene = SCNScene(named: "art.scnassets/mesh_colored.dae")
        self.sceneView.scene = geoScene!
        self.sceneView.autoenablesDefaultLighting = true
        self.sceneView.allowsCameraControl = true
        self.sceneView.backgroundColor = UIColor.black
    }
    
    
    @IBAction func saveColoredMesh(_ sender: UIButton) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let urlCOL = documentsPath.appendingPathComponent("colorObj.txt")
        let urlPOS = documentsPath.appendingPathComponent("positionObj.txt")
        let urlMESH = documentsPath.appendingPathComponent("mesh_colored.obj")
        let colorFile = try! String(contentsOf: urlCOL, encoding: .utf8)
        let posFile = try! String(contentsOf: urlPOS, encoding: .utf8)
        let colorArray = colorFile.components(separatedBy: "\n")
        let posArray = posFile.components(separatedBy: "\n")
        var colorArrayFloat: [Float] = []
        var posArrayFloat: [Float] = []
        
        var xArrayFloat: [Float] = []
        var yArrayFloat: [Float] = []
        var zArrayFloat: [Float] = []
        
        for i in 0..<(posArray.count-1)/3 {
            colorArrayFloat.append(Float(colorArray[i*3]) ?? 0.0)
            colorArrayFloat.append(Float(colorArray[i*3+1]) ?? 0.0)
            colorArrayFloat.append(Float(colorArray[i*3+2]) ?? 0.0)
            posArrayFloat.append(Float(posArray[i*3]) ?? 0.0)
            posArrayFloat.append(Float(posArray[i*3+1]) ?? 0.0)
            posArrayFloat.append(Float(posArray[i*3+2]) ?? 0.0)
            xArrayFloat.append(Float(posArray[i*3]) ?? 0.0)
            yArrayFloat.append(Float(posArray[i*3+1]) ?? 0.0)
            zArrayFloat.append(Float(posArray[i*3+2]) ?? 0.0)
        }
        
        let minX = Float(xArrayFloat.min()!)
        let minY = Float(yArrayFloat.min()!)
        let minZ = Float(zArrayFloat.min()!)
        let maxX = Float(xArrayFloat.max()!)
        let maxY = Float(yArrayFloat.max()!)
        let maxZ = Float(zArrayFloat.max()!)
        
        /*
        let avgX = xArrayFloat.reduce(0, +) / Float(xArrayFloat.count)
        let avgY = yArrayFloat.reduce(0, +) / Float(xArrayFloat.count)
        let avgZ = zArrayFloat.reduce(0, +) / Float(xArrayFloat.count)
        
        for i in 0..<(posArray.count-1)/3 {
            posArrayFloat[i*3] = posArrayFloat[i*3] - avgX
            posArrayFloat[i*3+1] = posArrayFloat[i*3+1] - avgY
            posArrayFloat[i*3+2] = posArrayFloat[i*3+2] - avgZ
        }*/
        
        for i in 0..<(posArray.count-1)/3 {
            posArrayFloat[i*3] = (posArrayFloat[i*3] - minX) / (maxX - minX) - 0.5
            posArrayFloat[i*3+1] = (posArrayFloat[i*3+1] - minY) / (maxY - minY) - 0.5
            posArrayFloat[i*3+2] = (posArrayFloat[i*3+2] - minZ) / (maxZ - minZ) - 0.5
        }
        

        let urlOBJ = documentsPath.appendingPathComponent("obj_scan.obj")
        let asset = MDLAsset(url: urlOBJ)
//        let scene = SCNScene(mdlAsset: asset)
        
        guard let object = asset.object(at: 0) as? MDLMesh else {
            fatalError("Failed to get mesh from asset.")
        }
        
        self.mdlMesh = object
        
        var vertexData: [Float] = []
        var indexData: [UInt32] = []
        
        var xVertexFloat: [Float] = []
        var yVertexFloat: [Float] = []
        var zVertexFloat: [Float] = []
        
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
            
            xVertexFloat.append(v.x)
            yVertexFloat.append(v.y)
            zVertexFloat.append(v.z)
//            validVertexData.append(i)
            
        }
        
//        let avgXV = xVertexFloat.reduce(0, +) / Float(xVertexFloat.count)
//        let avgYV = yVertexFloat.reduce(0, +) / Float(yVertexFloat.count)
//        let avgZV = zVertexFloat.reduce(0, +) / Float(zVertexFloat.count)
        
        
        let minXV = Float(xVertexFloat.min()!)
        let minYV = Float(yVertexFloat.min()!)
        let minZV = Float(zVertexFloat.min()!)
        let maxXV = Float(xVertexFloat.max()!)
        let maxYV = Float(yVertexFloat.max()!)
        let maxZV = Float(zVertexFloat.max()!)

        
        for i in 0..<vertexData.count/3 {
            vertexData[i*3] = (vertexData[i*3] - minXV) / (maxXV - minXV) - 0.5
            vertexData[i*3+1] = (vertexData[i*3+1] - minYV) / (maxYV - minYV) - 0.5
            vertexData[i*3+2] = (vertexData[i*3+2] - minZV) / (maxZV - minZV) - 0.5
            
            var minDist = Float(1000)
            var minDistIdx = 0
            for k in 0..<(posArrayFloat.count)/3 {
                let a = simd_float3(x: vertexData[i*3], y: vertexData[i*3+1], z: vertexData[i*3+2])
                let b = simd_float3(x: posArrayFloat[k*3], y: posArrayFloat[k*3+1], z: posArrayFloat[k*3+2])
                let dist = simd_distance(a, b)
                if dist < minDist {
                    minDist = dist
                    minDistIdx = k
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
            /*
            for i in 0..<indexCountObj/3 {
                if validVertexData.contains(Int(indexData[i*3])) && validVertexData.contains(Int(indexData[i*3+1])) && validVertexData.contains(Int(indexData[i*3+2])){
                    validIndexData.append(indexData[i*3])
                    validIndexData.append(indexData[i*3+1])
                    validIndexData.append(indexData[i*3+2])
                }
            }
            */
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
        }
        for i in 0..<(indexData.count)/3 {
            meshString = meshString + "f "
            meshString = meshString + String(indexData[i*3]+1)
            meshString = meshString + " "
            meshString = meshString + String(indexData[i*3+1]+1)
            meshString = meshString + " "
            meshString = meshString + String(indexData[i*3+2]+1)
            meshString = meshString + "\n"
        }
        do {
            try meshString.write(to: urlMESH, atomically: true, encoding: String.Encoding.utf8)
            let activityControllerSCN = UIActivityViewController(activityItems: [urlMESH], applicationActivities: nil)
            activityControllerSCN.popoverPresentationController?.sourceView = sender
            self.present(activityControllerSCN, animated: true, completion: nil)
        } catch {
            self.statusText.text = "Could not write to file"
        }
        meshString = ""
        self.statusText.text = "Write to file successfully"
    }
    
    

//        boundingBox(scale: 1, shiftx: 0.0, shifty: 0.0, shiftz: 0.0)

    
    func exportMesh(_ node: SCNNode){
    // export geometry
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = documentsPath.appendingPathComponent("PointCloud.obj")
        let mesh = MDLMesh(scnNode: node)
        let asset = MDLAsset()
        asset.add(mesh)
        do {
            try asset.export(to: url)
            print("Successfully save to obj")
        }
        catch{
            print("Can't write mesh to url")
        }
    }
    
    var size = CGFloat(0.3)
    var localMin = CGFloat(-0.15)
    var localMax = CGFloat(0.15)
    var position = SCNVector3(0, 0, 0)
    func boundingBox(width: CGFloat, height: CGFloat, length: CGFloat, shiftx: Float, shifty: Float, shiftz: Float) {
//        size = size*scale
//        localMin = localMin*scale
//        localMax = localMax*scale

        // Create A Bounding Box
        let boundingBoxNode = BlackMirrorzBoundingBox(width: size, height: size, length: size)

        // Add It To The ARSCNView
        self.sceneView.scene.rootNode.enumerateChildNodes { (node, stop) in
                node.removeFromParentNode()
            }
        self.sceneView.scene.rootNode.addChildNode(boundingBoxNode)
        
        // Position It 0.5m Away From The Camera
//        position.x = position.x + shiftx / 60000
//        position.y = position.y - shifty / 40000
//        position.z = position.z + shiftz
        
        position.x = position.x + shiftx
        position.y = position.y + shifty
        position.z = position.z + shiftz
        boundingBoxNode.position = position
//        getSizeOfModel(boundingBoxNode)
    }
    
    @IBAction func saveBoundingBox(_ sender: UIButton) {
        var jsonData: [String: Float]  = [
            "max_x": upperBound.x,
            "max_y": upperBound.y,
            "max_z": upperBound.z,
            "min_x": lowerBound.x,
            "min_y": lowerBound.y,
            "min_z": lowerBound.z,
            "width": widthOfNode,
            "heigh": heightOfNode,
            "depth": depthOfNode
        ]
        let saved = try!JSONSerialization.save(jsonObject: jsonData, toFilename: "BoundingBox")
        self.tabBarController?.selectedIndex = 0 // Index to select
    }
    
    var widthOfNode = Float()
    var heightOfNode = Float()
    var depthOfNode = Float()
    func getSizeOfModel(_ node: SCNNode){

        //1. Get The Bouding Box Of The Node
        let (min, max) = node.boundingBox

        //3. Get The Width & Height Of The Node
        widthOfNode = max.x - min.x
        heightOfNode = max.y - min.y
        depthOfNode = max.z - min.z

        //4. Get The Corners Of The Node
        upperBound = SCNVector3(max.x, max.y, max.z)
        lowerBound = SCNVector3(min.x, min.y, min.z)
    }
    
    func setupShaderOnGeometry(_ geometry: SCNBox) {
        guard let path = Bundle.main.path(forResource: "wireframe_shader", ofType: "metal", inDirectory: "art.scnassets"),
            let shader = try? String(contentsOfFile: path, encoding: .utf8) else {
                return
        }
        geometry.firstMaterial?.shaderModifiers = [.surface: shader]
    }
    
    @IBAction func resetButtonPressed(_ sender: Any) {
        if self.boundingBox.isEnabled == false {
            self.statusText.text = "Bounding box reset"
//            self.sceneView.session.pause()
            self.sceneView.scene.rootNode.enumerateChildNodes { (node, _) in
                if node.geometry is SCNBox {
                    node.removeFromParentNode()
                }
            }
            self.sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        } else {
            self.statusText.text = "Normal reset"
//            self.sceneView.session.pause()
            self.sceneView.scene.rootNode.enumerateChildNodes { (node, _) in
                if node.name == "PointCloud" {
                    node.removeFromParentNode()
                }
            }
            self.sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        }
    }
    
    func colorMesh() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let urlCOL = documentsPath.appendingPathComponent("color.txt")
        let urlPOS = documentsPath.appendingPathComponent("position.txt")
        let urlMESH = documentsPath.appendingPathComponent("mesh_colored.obj")
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

        let urlSCN = documentsPath.appendingPathComponent("scene_scan.obj")
        let asset = MDLAsset(url: urlSCN)
//        let scene = SCNScene(mdlAsset: asset)
        
        guard let object = asset.object(at: 0) as? MDLMesh else {
            fatalError("Failed to get mesh from asset.")
        }
        
        self.mdlMesh = object
        
        // Apply the texture to every submesh of the asset
        for submesh in object.submeshes!  {
            if let submesh = submesh as? MDLSubmesh {
                print("true")
            }
        }
        
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
                let dist = pow((posArrayFloat[i*3] - v.x), 2) + pow((posArrayFloat[i*3+1] - v.y), 2) + pow((posArrayFloat[i*3+2] - v.z), 2)
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
        for i in 0..<(posArrayFloat.count)/3 {
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
        }
        for i in 0..<(validIndexData.count)/3 {
            meshString = meshString + "f "
            meshString = meshString + String(validIndexData[i*3])
            meshString = meshString + " "
            meshString = meshString + String(validIndexData[i*3+1])
            meshString = meshString + " "
            meshString = meshString + String(validIndexData[i*3+2])
            meshString = meshString + "\n"
        }
        do {
            try meshString.write(to: urlMESH, atomically: true, encoding: String.Encoding.utf8)

        } catch {
            print("couldn't write to file")
        }
    }
    
    var mdlMesh = MDLMesh()
    @IBAction func saveObjectMesh(_ sender: UIButton) {
//        maxBB = SCNVector3(2.0, 2.0, 2.0)
//        minBB = SCNVector3(-2.0, -2.0, -2.0)

        var vertexData: [Float] = []
        var indexData: [UInt32] = []
        var validVertexData: [Int] = []
        var validIndexData: [UInt32] = []
        // print out the vertexes
        let vbuf = self.mdlMesh.vertexBuffers[0]
        let vbufmap = vbuf.map()
        let layout = self.mdlMesh.vertexDescriptor.layouts.firstObject as! MDLVertexBufferLayout
        let stride = layout.stride
        assert(vbuf.length == self.mdlMesh.vertexCount*stride)
        for i in 0..<self.mdlMesh.vertexCount {
            let v = (vbufmap.bytes+i*stride).bindMemory(to: SIMD3<Float>.self, capacity: 1).pointee
            
//            let x = (vbufmap.bytes+i*stride).bindMemory(to: Float.self, capacity: 1).pointee
//            let y = (vbufmap.bytes+i*stride+1/3*stride).bindMemory(to: Float.self, capacity: 1).pointee
//            let z = (vbufmap.bytes+i*stride+2/3*stride).bindMemory(to: Float.self, capacity: 1).pointee
            if self.maxBB.x >= v.x && self.maxBB.y >= v.y && self.maxBB.z >= v.z && self.minBB.x <= v.x && self.minBB.y <= v.y && self.minBB.z <= v.z {
                vertexData.append(v.x)
                vertexData.append(v.y)
                vertexData.append(v.z)
                validVertexData.append(i)
            }
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
        }
        for i in 0..<indexData.count/3 {
            if validVertexData.contains(Int(indexData[i*3])) && validVertexData.contains(Int(indexData[i*3+1])) && validVertexData.contains(Int(indexData[i*3+2])){
                let a = (validVertexData.firstIndex(of: Int(indexData[i*3])) ?? 0) as Int
                let b = (validVertexData.firstIndex(of: Int(indexData[i*3+1])) ?? 0) as Int
                let c = (validVertexData.firstIndex(of: Int(indexData[i*3+2])) ?? 0) as Int
                validIndexData.append(UInt32(a))
                validIndexData.append(UInt32(b))
                validIndexData.append(UInt32(c))
            }
        }

        // Setting the path to export the OBJ file to
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let urlOBJ = documentsPath.appendingPathComponent("obj_scan.obj")
        
        var meshString : String = ""
        for i in 0..<(vertexData.count)/3 {
            meshString = meshString + "v "
            meshString = meshString + String(vertexData[i*3])
            meshString = meshString + " "
            meshString = meshString + String(vertexData[i*3+1])
            meshString = meshString + " "
            meshString = meshString + String(vertexData[i*3+2])
            meshString = meshString + "\n"
        }
        for i in 0..<(validIndexData.count)/3 {
            meshString = meshString + "f "
            meshString = meshString + String(validIndexData[i*3]+1)
            meshString = meshString + " "
            meshString = meshString + String(validIndexData[i*3+1]+1)
            meshString = meshString + " "
            meshString = meshString + String(validIndexData[i*3+2]+1)
            meshString = meshString + "\n"
        }
        meshString = meshString + "s off"
        meshString = meshString + "\n"
        do {
            try meshString.write(to: urlOBJ, atomically: true, encoding: String.Encoding.utf8)
            // Sharing the OBJ file with airdrop
//            let activityControllerSCN = UIActivityViewController(activityItems: [urlOBJ], applicationActivities: nil)
//            activityControllerSCN.popoverPresentationController?.sourceView = sender
//            self.present(activityControllerSCN, animated: true, completion: nil)
        } catch {
            print("couldn't write to file")
        }
        meshString = ""
        print("write to file successed")
        
        self.boundingBox.isEnabled = true
        
//        self.sceneView.session.pause()
        self.sceneView.scene.rootNode.enumerateChildNodes { (node, _) in
            if node.name == "boundingboxpoint" {
                node.removeFromParentNode()
            }
            node.removeFromParentNode()
        }
        self.sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        /*
        let mdlMeshObj = self.createObjectMesh(vertexData: vertexData, indexData: validIndexData)
        let material = MDLMaterial(name: "baseMaterial", scatteringFunction: MDLPhysicallyPlausibleScatteringFunction())
        for submesh in mdlMeshObj.submeshes!  {
            if let submesh = submesh as? MDLSubmesh {
                submesh.material = material
            }
        }
        
        // Wrap the ModelIO object in a SceneKit object
        let node = SCNNode(mdlObject: mdlMeshObj)
        let scene = SCNScene()
        scene.rootNode.addChildNode(node)

        // Set up the SceneView
        self.sceneView.autoenablesDefaultLighting = true
        self.sceneView.allowsCameraControl = true
        self.sceneView.scene = scene
        self.sceneView.backgroundColor = UIColor.black
        
        let assetObj = MDLAsset()
        assetObj.add(mdlMeshObj)

        // Exporting the OBJ file
        if MDLAsset.canExportFileExtension("obj") {
            do {
                try assetObj.export(to: urlOBJ)

//                 Sharing the OBJ file with airdrop
//                let activityControllerSCN = UIActivityViewController(activityItems: [urlSCN], applicationActivities: nil)
//                activityControllerSCN.popoverPresentationController?.sourceView = sender
//                self.present(activityControllerSCN, animated: true, completion: nil)

                let activityControllerOBJ = UIActivityViewController(activityItems: [urlOBJ], applicationActivities: nil)
                activityControllerOBJ.popoverPresentationController?.sourceView = sender
                self.present(activityControllerOBJ, animated: true, completion: nil)
            } catch let error {
                fatalError(error.localizedDescription)
            }
        } else {
            fatalError("Can't export OBJ")
        }
        */
    }
    
    func createObjectMesh(vertexData: [Float], indexData: [UInt32]) -> MDLMesh {
        let device = MTLCreateSystemDefaultDevice()!

        let metalAllocator = MTKMeshBufferAllocator(device: device)
        let numIndices = indexData.count
        let numVertices = vertexData.count / 3
//        let lenBufferVertices = numVertices * MemoryLayout<SIMD3<Float>>.size
        let lenBufferVertices = numVertices * MemoryLayout<Float>.size * 3
        let mdlMeshBufferVertices = metalAllocator.newBuffer(lenBufferVertices, type: .vertex)
//        print(MemoryLayout<SIMD3<Float>>.size)
//        print(MemoryLayout<SIMD3<Float>>.stride)
//        print(MemoryLayout<Float>.size)

        // Now fill the Vertex buffers with vertices.

        let nsData = Data(bytes: vertexData, count: lenBufferVertices)
        mdlMeshBufferVertices.fill(nsData, offset: 0)

        let lenBufferIndices = numIndices * MemoryLayout<UInt32>.size
        let mdlMeshBufferIndices = metalAllocator.newBuffer(lenBufferIndices, type: .index)
        let nsData_indices = Data(bytes: indexData, count: lenBufferIndices)
        mdlMeshBufferIndices.fill(nsData_indices, offset: 0)

        let scatteringFunction = MDLPhysicallyPlausibleScatteringFunction()
        let material = MDLMaterial(name: "plausibleMaterial", scatteringFunction: scatteringFunction)

        // Not allowed to create an MTKSubmesh directly, so feed an MDLSubmesh to an MDLMesh, and then use that to load an MTKMesh, which makes the MTKSubmesh from it.
        let submesh = MDLSubmesh(
            indexBuffer: mdlMeshBufferIndices,
            indexCount: numIndices,
            indexType: .uInt32,
            geometryType: .triangles,
            material: material)

        let mdlVertexDescriptor = MDLVertexDescriptor()
        mdlVertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                                            format: .float3,
                                                            offset: 0,
                                                            bufferIndex: 0);
//        mdlVertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<SIMD3<Float>>.size);
        mdlVertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Float>.size * 3);

        return MDLMesh(vertexBuffers: [mdlMeshBufferVertices],
                       vertexCount: numVertices,
                       descriptor: mdlVertexDescriptor,
                       submeshes: [submesh])
        
    }
    
    @IBAction func saveObjectPointCloud(_ sender: UIButton) {
//        maxBB = SCNVector3(2.0, 2.0, 2.0)
//        minBB = SCNVector3(-2.0, -2.0, -2.0)

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let urlCOL = documentsPath.appendingPathComponent("color.txt")
        let urlPOS = documentsPath.appendingPathComponent("position.txt")
        let colorFile = try! String(contentsOf: urlCOL, encoding: .utf8)
        let posFile = try! String(contentsOf: urlPOS, encoding: .utf8)
        let colorArray = colorFile.components(separatedBy: "\n")
        let posArray = posFile.components(separatedBy: "\n")
        var colorString : String = ""
        var posString : String = ""
        
        var temp = 0
        
//        let pointCloud = SCNNode()
        for i in 0..<(posArray.count-1)/3 {
            let red = Float(colorArray[i*3]) ?? 0
            let green = Float(colorArray[i*3+1]) ?? 0
            let blue = Float(colorArray[i*3+2]) ?? 0
            let x = Float(posArray[i*3]) ?? 0.0
            let y = Float(posArray[i*3+1]) ?? 0.0
            let z = Float(posArray[i*3+2]) ?? 0.0
            if x <= self.maxBB.x && y <= self.maxBB.y && z <= self.maxBB.z && x >= self.minBB.x && y >= self.minBB.y && z >= self.minBB.z {
                colorString = colorString + String(red)
                colorString = colorString + "\n"
                colorString = colorString + String(green)
                colorString = colorString + "\n"
                colorString = colorString + String(blue)
                colorString = colorString + "\n"
                posString = posString + String(x)
                posString = posString + "\n"
                posString = posString + String(y)
                posString = posString + "\n"
                posString = posString + String(z)
                posString = posString + "\n"
                temp = temp + 3
            }
        }
        let urlCOLOBJ = documentsPath.appendingPathComponent("colorObj.txt")
        let urlPOSOBJ = documentsPath.appendingPathComponent("positionObj.txt")
        do {
            try colorString.write(to: urlCOLOBJ, atomically: true, encoding: String.Encoding.utf8)
            try posString.write(to: urlPOSOBJ, atomically: true, encoding: String.Encoding.utf8)
//            self.sceneView.scene.rootNode.addChildNode(pointCloud)
            self.statusText.text = "Save object point cloud successfully"
        } catch {
            self.statusText.text = "Could not write to file"
        }
        
        self.boundingBox.isEnabled = true
        
//        self.sceneView.session.pause()
        self.sceneView.scene.rootNode.enumerateChildNodes { (node, _) in
            if node.name == "PointCloud" {
                node.removeFromParentNode()
            }
            if node.name == "boundingboxpoint" {
                node.removeFromParentNode()
            }
            node.removeFromParentNode()
        }
        self.sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    @IBAction func loadMeshButtonPressed(_ sender: Any) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
//        let urlSCN = documentsPath.appendingPathComponent("scene_scan.obj")
        let urlSCN = documentsPath.appendingPathComponent("obj_scan.obj")
        let material = MDLMaterial(name: "baseMaterial", scatteringFunction: MDLPhysicallyPlausibleScatteringFunction())
        let asset = MDLAsset(url: urlSCN)
//        let scene = SCNScene(mdlAsset: asset)
        
        guard let object = asset.object(at: 0) as? MDLMesh else {
            fatalError("Failed to get mesh from asset.")
        }
        
        self.mdlMesh = object
        
        // Apply the texture to every submesh of the asset
        for submesh in object.submeshes!  {
            if let submesh = submesh as? MDLSubmesh {
                submesh.material = material
            }
        }
        
        // Wrap the ModelIO object in a SceneKit object
        let node = SCNNode(mdlObject: object)
        node.name = "SceneMesh"
        let scene = SCNScene()
        scene.rootNode.addChildNode(node)

        // Set up the SceneView
        self.sceneView.autoenablesDefaultLighting = true
        self.sceneView.allowsCameraControl = true
        self.sceneView.scene = scene
        self.sceneView.backgroundColor = UIColor.black
    }
    
    @IBAction func loadPointCloudPressed(_ sender: Any) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
//        let urlCOL = documentsPath.appendingPathComponent("color.txt")
//        let urlPOS = documentsPath.appendingPathComponent("position.txt")
        let urlCOL = documentsPath.appendingPathComponent("colorObj.txt")
        let urlPOS = documentsPath.appendingPathComponent("positionObj.txt")
        let colorFile = try! String(contentsOf: urlCOL, encoding: .utf8)
        let posFile = try! String(contentsOf: urlPOS, encoding: .utf8)
        let colorArray = colorFile.components(separatedBy: "\n")
        let posArray = posFile.components(separatedBy: "\n")
        let pointCloud = SCNNode()
        pointCloud.name = "PointCloud"
        for i in 0..<(posArray.count-1)/3 {
            let red = Float(colorArray[i*3]) ?? 0.0
            let green = Float(colorArray[i*3+1]) ?? 0.0
            let blue = Float(colorArray[i*3+2]) ?? 0.0
            let x = Float(posArray[i*3]) ?? 0.0
            let y = Float(posArray[i*3+1]) ?? 0.0
            let z = Float(posArray[i*3+2]) ?? 0.0
            let node = SCNNode()
            node.geometry = SCNSphere(radius: 0.005)
            node.geometry?.firstMaterial?.diffuse.contents = UIColor(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1)
            node.position = SCNVector3(x, y, z)
            pointCloud.addChildNode(node)
        }
        let scene = SCNScene()
        scene.rootNode.addChildNode(pointCloud)
        // Set up the SceneView
        self.sceneView.autoenablesDefaultLighting = true
        self.sceneView.allowsCameraControl = true
        self.sceneView.scene = scene
        self.sceneView.backgroundColor = UIColor.black
        
//        self.sceneView.scene.rootNode.addChildNode(pointCloud)
    }
    
    /*
    func loadPointCloud() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let urlCOL = documentsPath.appendingPathComponent("color.txt")
        let urlPOS = documentsPath.appendingPathComponent("position.txt")
        let colorFile = try! String(contentsOf: urlCOL, encoding: .utf8)
        let posFile = try! String(contentsOf: urlPOS, encoding: .utf8)
        let colorArray = colorFile.components(separatedBy: "\n")
        let posArray = posFile.components(separatedBy: "\n")
        let pointCloud = SCNNode()
        for i in 0..<(posArray.count-1)/3 {
            let red = Float(colorArray[i*3]) ?? 0.0
            let green = Float(colorArray[i*3+1]) ?? 0.0
            let blue = Float(colorArray[i*3+2]) ?? 0.0
            let x = Float(posArray[i*3]) ?? 0.0
            let y = Float(posArray[i*3+1]) ?? 0.0
            let z = Float(posArray[i*3+2]) ?? 0.0
            let node = SCNNode()
            node.geometry = SCNSphere(radius: 0.003)
            node.geometry?.firstMaterial?.diffuse.contents = UIColor(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1)
            node.position = SCNVector3(x, y, z)
            pointCloud.addChildNode(node)
        }
        self.sceneView.scene.rootNode.addChildNode(pointCloud)

    }*/
    
    /*
    func export_obj(vertices: Float, triangles: Float, fileneme: String) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let urlCOL = documentsPath.appendingPathComponent("color.txt")
        let urlPOS = documentsPath.appendingPathComponent("position.txt")
        let colorFile = try! String(contentsOf: urlCOL, encoding: .utf8)
        let posFile = try! String(contentsOf: urlPOS, encoding: .utf8)
        let colorArray = colorFile.components(separatedBy: "\n")
        let posArray = posFile.components(separatedBy: "\n")
        
        
        print('export mesh: ', vertices.shape)
        
        with open(filename, 'w') as fh:
            if (vertices.shape[1]==6):
                for v in vertices:
                    fh.write("v {} {} {} {} {} {}\n".format(*v))
            else:
                for v in vertices:
                    fh.write("v {} {} {}\n".format(*v))
                
            for f in triangles:
                fh.write("f {} {} {}\n".format(*(f + 1)))
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let urlMESH = documentsPath.appendingPathComponent("mesh.obj")
        
        var meshString : String = ""
        for i in 0..<vertices.count {
            meshString = meshString + "v"
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
        } catch {
            print("couldn't write to file")
        }
    }
    */
    
    
    
    @IBAction func pinchDetected(_ gestureRecognizer : UIPinchGestureRecognizer) {
        guard gestureRecognizer.view != nil else { return }
        if gestureRecognizer.state == .began || gestureRecognizer.state == .changed {
           //gestureRecognizer.view?.transform = (gestureRecognizer.view?.transform.scaledBy(x: gestureRecognizer.scale, y: gestureRecognizer.scale))!
//            boundingBox(scale: gestureRecognizer.scale, shiftx: 0.0, shifty: 0.0, shiftz: 0.0)
           gestureRecognizer.scale = 1.0
        }
    }
    
    var initialCenter = CGPoint()  // The initial center point of the view.
    @IBAction func panDetected(_ gestureRecognizer : UIPanGestureRecognizer) {
        
        /*
        print("pan")
        guard gestureRecognizer.view != nil else {return}
        let piece = gestureRecognizer.view!
        // Get the changes in the X and Y directions relative to
        // the superview's coordinate space.
        let translation = gestureRecognizer.translation(in: piece.superview)
        if gestureRecognizer.state == .began {
        // Save the view's original position.
            self.initialCenter = piece.center
//            boundingBox(scale: CGFloat(1), shiftx: Float(0), shifty: Float(0), shiftz: 0.0)
        }
        // Update the position for the .began, .changed, and .ended states
        if gestureRecognizer.state != .cancelled {
        // Add the X and Y translation to the view's original position.
            let newCenter = CGPoint(x: initialCenter.x + translation.x, y: initialCenter.y + translation.y)
            //            let shiftx = newCenter.x / initialCenter.x
            //            let shifty = newCenter.y / initialCenter.y
            //piece.center = newCenter
//            boundingBox(scale: CGFloat(1), shiftx: Float(translation.x), shifty: Float(translation.y), shiftz: 0.0)
        }
        else {
        // On cancellation, return the piece to its original location.
            piece.center = initialCenter
//            boundingBox(scale: CGFloat(1), shiftx: Float(0), shifty: Float(0), shiftz: 0.0)
        }
         */
    }
    
    @IBAction func pressDetected(_ gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state == .began {
//            boundingBox(scale: CGFloat(1), shiftx: Float(0), shifty: Float(0), shiftz: 0.05)
//           self.becomeFirstResponder()
//           self.viewForReset = gestureRecognizer.view
//
//           // Configure the menu item to display
//           let menuItemTitle = NSLocalizedString("Reset", comment: "Reset menu item title")
//           let action = #selector(ViewController.resetPiece(controller:))
//           let resetMenuItem = UIMenuItem(title: menuItemTitle, action: action)
//
//           // Configure the shared menu controller
//           let menuController = UIMenuController.shared
//           menuController.menuItems = [resetMenuItem]
//
//           // Set the location of the menu in the view.
//           let location = gestureRecognizer.location(in: gestureRecognizer.view)
//           let menuLocation = CGRect(x: location.x, y: location.y, width: 0, height: 0)
//           menuController.setTargetRect(menuLocation, in: gestureRecognizer.view!)
//
//           // Show the menu.
//           menuController.setMenuVisible(true, animated: true)
        }
     }
    
    @IBAction func tapDetected(_ gestureRecognizer : UITapGestureRecognizer ){
        /*
        guard gestureRecognizer.view != nil else { return }
             
        if gestureRecognizer.state == .ended {      // Move the view down and to the right when tapped.
            boundingBox(scale: CGFloat(1), shiftx: Float(0), shifty: Float(0), shiftz: -0.01)
           let animator = UIViewPropertyAnimator(duration: 0.2, curve: .easeInOut, animations: {
              gestureRecognizer.view!.center.x += 100
              gestureRecognizer.view!.center.y += 100
           })
           animator.startAnimation()
        }
 */
    }
    
    
    class BlackMirrorzBoundingBox: SCNNode {
        init(width: CGFloat, height: CGFloat, length: CGFloat, color: UIColor = .cyan) {
            super.init()
            let wireFrame = SCNNode()
            let box = SCNBox(width: width, height: height, length: length, chamferRadius: 0)
            box.firstMaterial?.diffuse.contents = color
            box.firstMaterial?.isDoubleSided = true
            wireFrame.geometry = box
            setupShaderOnGeometry(box)
            /*
            let orientation = wireFrame.orientation
            var glQuaternion = GLKQuaternionMake(orientation.x, orientation.y, orientation.z, orientation.w)
            // Rotate around Z axis
            let multiplier = GLKQuaternionMakeWithAngleAndAxis(-Float(angle), 0, 1, 0)
            glQuaternion = GLKQuaternionMultiply(glQuaternion, multiplier)
            wireFrame.orientation = SCNQuaternion(x: glQuaternion.x, y: glQuaternion.y, z: glQuaternion.z, w: glQuaternion.w)
            */
            self.addChildNode(wireFrame)
        }

        required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) Has Not Been Implemented") }

        func setupShaderOnGeometry(_ geometry: SCNBox) {
            guard let path = Bundle.main.path(forResource: "wireframe_shader", ofType: "metal", inDirectory: "art.scnassets"),
                let shader = try? String(contentsOfFile: path, encoding: .utf8) else {
                    return
            }
            geometry.firstMaterial?.shaderModifiers = [.surface: shader]
        }

    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension JSONSerialization {
    
    static func loadJSON(withFilename filename: String) throws -> Any? {
        let fm = FileManager.default
        let urls = fm.urls(for: .documentDirectory, in: .userDomainMask)
        if let url = urls.first {
            var fileURL = url.appendingPathComponent(filename)
            fileURL = fileURL.appendingPathExtension("json")
            let data = try Data(contentsOf: fileURL)
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [.mutableContainers, .mutableLeaves])
            return jsonObject
        }
        return nil
    }
    
    static func save(jsonObject: Any, toFilename filename: String) throws -> Bool{
        let fm = FileManager.default
        let urls = fm.urls(for: .documentDirectory, in: .userDomainMask)
        if let url = urls.first {
            var fileURL = url.appendingPathComponent(filename)
            fileURL = fileURL.appendingPathExtension("json")
            print(fileURL)
            let data = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted])
            try data.write(to: fileURL, options: [.atomicWrite])
            return true
        }
        
        return false
    }
}
