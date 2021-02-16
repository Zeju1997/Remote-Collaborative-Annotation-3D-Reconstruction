//
//  MeshViewController.swift
//  Remote Collaborative Annotation
//
//  Created by Zeju Qiu on 29.12.20.
//

import UIKit
import RealityKit
import ARKit
import AVFoundation
import Foundation
import MetalKit
import SceneKit.ModelIO
import ModelIO
import Metal
import simd

class MeshViewController: UIViewController, ARSessionDelegate {

    @IBOutlet weak var arView: ARView!
    @IBOutlet weak var statusText: UILabel!
    @IBOutlet weak var hideMeshButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var planeDetectionButton: UIButton!
    
    
    let session: AVCaptureSession = AVCaptureSession()
    
    let coachingOverlay = ARCoachingOverlayView()
    
    // Cache for 3D text geometries representing the classification values.
    var modelsForClassification: [ARMeshClassification: ModelEntity] = [:]

    /// - Tag: ViewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()

        arView.session.delegate = self
        
        setupCoachingOverlay()

        arView.environment.sceneUnderstanding.options = []
        
        // Turn on occlusion from the scene reconstruction's mesh.
        arView.environment.sceneUnderstanding.options.insert(.occlusion)
        
        // Turn on physics for the scene reconstruction's mesh.
        arView.environment.sceneUnderstanding.options.insert(.physics)

        // Display a debug visualization of the mesh.
//        arView.debugOptions.insert(.showSceneUnderstanding)
        
        // For performance, disable render options that are not required for this app.
        arView.renderOptions = [.disablePersonOcclusion, .disableDepthOfField, .disableMotionBlur]
        
        // Manually configure what kind of AR session to run since
        // ARView on its own does not turn on mesh classification.
        arView.automaticallyConfigureSession = false
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .meshWithClassification

        configuration.environmentTexturing = .automatic
        arView.session.run(configuration)
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tapRecognizer)
        
        arView.debugOptions = [ARView.DebugOptions.showWorldOrigin]
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Prevent the screen from being dimmed to avoid interrupting the AR experience.
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
//    override var prefersHomeIndicatorAutoHidden: Bool {
//        return true
//    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    /// Places virtual-text of the classification at the touch-location's real-world intersection with a mesh.
    /// Note - because classification of the tapped-mesh is retrieved asynchronously, we visualize the intersection
    /// point immediately to give instant visual feedback of the tap.
    @objc
    
    @IBAction func handleTap(_ sender: UITapGestureRecognizer) {
        // 1. Perform a ray cast against the mesh.
        // Note: Ray-cast option ".estimatedPlane" with alignment ".any" also takes the mesh into account.
        let tapLocation = sender.location(in: arView)
        if let result = arView.raycast(from: tapLocation, allowing: .estimatedPlane, alignment: .any).first {
            // ...
            // 2. Visualize the intersection point of the ray with the real-world surface.
            let resultAnchor = AnchorEntity(world: result.worldTransform)
            resultAnchor.addChild(sphere(radius: 0.01, color: .lightGray))
            arView.scene.addAnchor(resultAnchor, removeAfter: 3)

            // 3. Try to get a classification near the tap location.
            //    Classifications are available per face (in the geometric sense, not human faces).
            nearbyFaceWithClassification(to: result.worldTransform.position) { (centerOfFace, classification) in
                // ...
                DispatchQueue.main.async {
                    // 4. Compute a position for the text which is near the result location, but offset 10 cm
                    // towards the camera (along the ray) to minimize unintentional occlusions of the text by the mesh.
                    let rayDirection = normalize(result.worldTransform.position - self.arView.cameraTransform.translation)
                    let textPositionInWorldCoordinates = result.worldTransform.position - (rayDirection * 0.1)
                    
                    // 5. Create a 3D text to visualize the classification result.
                    let textEntity = self.model(for: classification)

                    // 6. Scale the text depending on the distance, such that it always appears with
                    //    the same size on screen.
                    let raycastDistance = distance(result.worldTransform.position, self.arView.cameraTransform.translation)
                    textEntity.scale = .one * raycastDistance

                    // 7. Place the text, facing the camera.
                    var resultWithCameraOrientation = self.arView.cameraTransform
                    resultWithCameraOrientation.translation = textPositionInWorldCoordinates
                    let textAnchor = AnchorEntity(world: resultWithCameraOrientation.matrix)
                    textAnchor.addChild(textEntity)
                    self.arView.scene.addAnchor(textAnchor, removeAfter: 3)

                    // 8. Visualize the center of the face (if any was found) for three seconds.
                    //    It is possible that this is nil, e.g. if there was no face close enough to the tap location.
                    if let centerOfFace = centerOfFace {
                        let faceAnchor = AnchorEntity(world: centerOfFace)
                        faceAnchor.addChild(self.sphere(radius: 0.01, color: classification.color))
                        self.arView.scene.addAnchor(faceAnchor, removeAfter: 3)
                    }
                }
            }
        }
    }
    
    var maxBB = SIMD3<Float>()
    var minBB = SIMD3<Float>()
    func loadBoundingBox() {
        let jsonObject = try!JSONSerialization.loadJSON(withFilename: "BoundingBox")
            if let boundingBox = jsonObject as? Dictionary<String, AnyObject>{
                let maxPointx = boundingBox["max_x"] as! Double
                let maxPointy = boundingBox["max_y"] as! Double
                let maxPointz = boundingBox["max_z"] as! Double
                let minPointx = boundingBox["min_x"] as! Double
                let minPointy = boundingBox["min_y"] as! Double
                let minPointz = boundingBox["min_z"] as! Double
                maxBB = SIMD3<Float>(Float(maxPointx), Float(maxPointy), Float(maxPointz))
                minBB = SIMD3<Float>(Float(minPointx), Float(minPointy), Float(minPointz))
            }
    }
    
    @IBAction func resetButtonPressed(_ sender: Any) {
        if let configuration = arView.session.configuration {
            arView.session.run(configuration, options: .resetSceneReconstruction)
        }
    }
    
    func createObjectMesh(vertexData: [SIMD3<Float>], indexData: [UInt32]) -> MDLMesh {
        
        let device = MTLCreateSystemDefaultDevice()!

//        let equilateralTriangleVertexData = [
//            vector_float3(0.000000, 0.577350, 0.0),
//            vector_float3(-0.500000, -0.288675, 0.0),
//            vector_float3(0.500000, -0.288675, 0.0)
//        ]
//
//        let equilateralTriangleVertexNormalsData = [
//            vector_float3(0.0, 0.0, 1.0),
//            vector_float3(0.0, 0.0, 1.0),
//            vector_float3(0.0, 0.0, 1.0)
//        ]
//
//        let equilateralTriangleVertexTexData = [
//            vector_float2(0.50, 1.00),
//            vector_float2(0.00, 0.00),
//            vector_float2(1.00, 0.00)
//        ]
//
//        let indices = [0, 1, 2]
//
//        let numIndices = 3
//        let numVertices = 3
//
//        let metalAllocator = MTKMeshBufferAllocator(device: device);
//        let lenBufferForVertices_position = numVertices * MemoryLayout<vector_float3>.size
//        let lenBufferForVertices_normal = numVertices * MemoryLayout<vector_float3>.size
//        let lenBufferForVertices_textureCoordinate = numVertices * MemoryLayout<vector_float2>.size
//        let mtkMeshBufferForVertices_position = metalAllocator.newBuffer(lenBufferForVertices_position, type: .vertex)
//        let mtkMeshBufferForVertices_normal = metalAllocator.newBuffer(lenBufferForVertices_normal, type: .vertex)
//        let mtkMeshBufferForVertices_textureCoordinate = metalAllocator.newBuffer(lenBufferForVertices_textureCoordinate, type: .vertex)
        
        let metalAllocator = MTKMeshBufferAllocator(device: device)
        let numIndices = indexData.count
        let numVertices = vertexData.count
        let lenBufferVertices = numVertices * MemoryLayout<SIMD3<Float>>.size
        let mdlMeshBufferVertices = metalAllocator.newBuffer(lenBufferVertices, type: .vertex)

        // Now fill the Vertex buffers with vertices.
        
        let nsData = Data.init(bytes: vertexData, count: lenBufferVertices)
        mdlMeshBufferVertices.fill(nsData, offset: 0)

//        let nsData_position = Data.init(bytes: equilateralTriangleVertexData, count: lenBufferForVertices_position)
//        let nsData_normal = Data.init(bytes: equilateralTriangleVertexNormalsData, count: lenBufferForVertices_normal)
//        let nsData_textureCoordinate = Data.init(bytes: equilateralTriangleVertexTexData, count: lenBufferForVertices_textureCoordinate)
//        mtkMeshBufferForVertices_position.fill(nsData_position, offset: 0)
//        mtkMeshBufferForVertices_normal.fill(nsData_normal, offset: 0)
//        mtkMeshBufferForVertices_textureCoordinate.fill(nsData_textureCoordinate, offset: 0)
//        let arrayOfMeshBuffers = [mtkMeshBufferForVertices_position, mtkMeshBufferForVertices_normal, mtkMeshBufferForVertices_textureCoordinate]

//        let lenBufferForIndices = numIndices * MemoryLayout<UInt16>.size
//        let mtkMeshBufferForIndices = metalAllocator.newBuffer(lenBufferForIndices, type: .index)
    
//        let nsData_indices = Data.init(bytes: indices, count: lenBufferIndices)
//        mtkMeshBufferForIndices.fill(nsData_indices, offset: 0)
//
//        let scatteringFunction = MDLPhysicallyPlausibleScatteringFunction()
//        let material = MDLMaterial(name: "plausibleMaterial", scatteringFunction: scatteringFunction)
//
//        // Not allowed to create an MTKSubmesh directly, so feed an MDLSubmesh to an MDLMesh, and then use that to load an MTKMesh, which makes the MTKSubmesh from it.
//        let submesh = MDLSubmesh(
//            indexBuffer: mtkMeshBufferForIndices,
//            indexCount: numIndices,
//            indexType: .uInt16,
//            geometryType: .triangles,
//            material: nil)
//
//        let arrayOfSubmeshes = [submesh]
//
//        let mdlVertexDescriptor = MDLVertexDescriptor()
//        mdlVertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
//                                                            format: .float3,
//                                                            offset: 0,
//                                                            bufferIndex: 0);
//        mdlVertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<vector_float3>.size);
//
//        let mdlMesh = MDLMesh(
//            vertexBuffers: arrayOfMeshBuffers,
//            vertexCount: numVertices,
//            descriptor: mdlVertexDescriptor,
//            submeshes: arrayOfSubmeshes)
        
        let lenBufferIndices = numIndices * MemoryLayout<UInt32>.size
        let mdlMeshBufferIndices = metalAllocator.newBuffer(lenBufferIndices, type: .index)
        let nsData_indices = Data.init(bytes: indexData, count: lenBufferIndices)
        mdlMeshBufferIndices.fill(nsData_indices, offset: 0)
        
        let scatteringFunction = MDLPhysicallyPlausibleScatteringFunction()
        let material = MDLMaterial(name: "plausibleMaterial", scatteringFunction: scatteringFunction)

        // Not allowed to create an MTKSubmesh directly, so feed an MDLSubmesh to an MDLMesh, and then use that to load an MTKMesh, which makes the MTKSubmesh from it.
        let submesh = MDLSubmesh(
            indexBuffer: mdlMeshBufferIndices,
            indexCount: numIndices,
            indexType: .uInt32,
            geometryType: .triangles,
            material: nil)

        let mdlVertexDescriptor = MDLVertexDescriptor()
        mdlVertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                                            format: .float3,
                                                            offset: 0,
                                                            bufferIndex: 0);
        mdlVertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<SIMD3<Float>>.size);

        return MDLMesh(vertexBuffers: [mdlMeshBufferVertices],
                       vertexCount: numVertices,
                       descriptor: mdlVertexDescriptor,
                       submeshes: [submesh])
        
//        // print out the vertexes
//        let vbuf = mdlMesh.vertexBuffers[0]
//        let vbufmap = vbuf.map()
//        let layout = mdlMesh.vertexDescriptor.layouts.firstObject as! MDLVertexBufferLayout
//        let stride = layout.stride
//        print(vbuf.length) //8
//        print(mdlMesh.vertexCount) //3
//        assert(vbuf.length == mdlMesh.vertexCount*stride) //12
//        print(mdlMesh.vertexCount)
//        for i in 0..<mdlMesh.vertexCount {
//            let v = (vbufmap.bytes+i*stride).bindMemory(to: float3.self, capacity: 1).pointee
//            print(v)
//        }

        
        
//        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0];
//        let filename = directory.appendingPathComponent("ObjectMesh.obj");
//        print(filename)
//
//        let asset = MDLAsset();
////            let scene = SCNScene(mdlAsset: asset)
//
//        asset.add(mdlMesh);
//
//        do {
//            try asset.export(to: filename)
//            print("succeeded to write to file")
//        } catch {
//            print("failed to write to file");
//        }
    }
    
    
    func unwrap(any:Any) -> Any {

        let mi = Mirror(reflecting: any)
        if mi.displayStyle != .optional {
            return any
        }

        if mi.children.count == 0 { return NSNull() }
        let (_, some) = mi.children.first!
        return some

    }

    
    @IBAction func toggleMeshButtonPressed(_ button: UIButton) {
        let isShowingMesh = arView.debugOptions.contains(.showSceneUnderstanding)
        if isShowingMesh {
            arView.debugOptions.remove(.showSceneUnderstanding)
            button.setTitle("Show Mesh", for: [])
        } else {
            arView.debugOptions.insert(.showSceneUnderstanding)
            button.setTitle("Hide Mesh", for: [])
        }
    }
    
    
    
    @IBAction func saveMeshButtonPressed(_ sender: UIButton) {
        guard let frame = arView.session.currentFrame else {
            fatalError("Couldn't get the current ARFrame")
        }
        
//        loadBoundingBox()
//        maxBB = [5, 5, 5]
//        minBB = [-5, -5, -5]
        
//        let meshAnchors = arView.session.currentFrame?.anchors.compactMap({ $0 as? ARMeshAnchor });
//        DispatchQueue.global().async {
//            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0];
//            let filename = directory.appendingPathComponent("MyFirstMesh.obj");
//            let filenameObj = directory.appendingPathComponent("ObjectMesh.obj");
//            print(filename)
//
//            // Fetch the default MTLDevice to initialize a MetalKit buffer allocator with
//            guard let device = MTLCreateSystemDefaultDevice() else {
//                fatalError("Failed to get the system's default Metal device!")
//                return;
//            };
//
//            let asset = MDLAsset();
//            let assetObj = MDLAsset();
//
//            let scene = SCNScene(mdlAsset: asset)
//
//            for anchor in meshAnchors! {
//                var vertexData: [SIMD3<Float>] = []
//                var indexData: [UInt32] = []
//                var validVertexData: [Int] = []
//                var validIndexData: [UInt32] = []
//
//                let mdlMesh = anchor.geometry.toMDLMesh(device: device);
//
//                // print out the vertexes
//                let vbuf = mdlMesh.vertexBuffers[0]
//                let vbufmap = vbuf.map()
//                let layout = mdlMesh.vertexDescriptor.layouts.firstObject as! MDLVertexBufferLayout
//                let stride = layout.stride
//                print(vbuf.length) //5196
//                print(mdlMesh.vertexCount) //433
//                print(stride) //12
//                assert(vbuf.length == mdlMesh.vertexCount*stride)
//                print(mdlMesh.vertexCount)
//                for i in 0..<mdlMesh.vertexCount {
//                    let v = (vbufmap.bytes+i*stride).bindMemory(to: SIMD3<Float>.self, capacity: 1).pointee
//                    if self.maxBB.x >= v.x && self.maxBB.y > v.y && self.maxBB.z > v.z && self.minBB.x <= v.x && self.minBB.y <= v.y && self.minBB.z <= v.z {
//                        vertexData.append(v)
//                        validVertexData.append(i)
//                    }
//                }
//                let submesh = mdlMesh.submeshes?[0] as! MDLSubmesh
//                let indexCount = submesh.indexCount
////                print(indexCount)
//                let ibuf = submesh.indexBuffer
//                let ibufmap = ibuf.map()
//                let istride = 4
//                for i in 0..<indexCount {
//                    let u = (ibufmap.bytes+i*istride).bindMemory(to: UInt32.self, capacity: 1).pointee
//                    indexData.append(u)
//                }
//                for i in 0..<indexCount/3 {
//                    if validVertexData.contains(Int(indexData[i*3])) && validVertexData.contains(Int(indexData[i*3+1])) && validVertexData.contains(Int(indexData[i*3+2])){
//                        validIndexData.append(indexData[i*3])
//                        validIndexData.append(indexData[i*3+1])
//                        validIndexData.append(indexData[i*3+2])
//                    }
//                }
//
//                let mdlObjMesh = self.createObjectMesh(vertexData: vertexData, indexData: validIndexData)
//
//                asset.add(mdlMesh)
//                assetObj.add(mdlObjMesh)
//                print("vertextdata", vertexData.count)
//                print("indexdata", indexData.count)
//            }
//            do {
//                try asset.export(to: filename)
//                try assetObj.export(to: filenameObj)
//                print("succeeded to write to file")
//            } catch {
//                print("failed to write to file");
//            }
//        }
        
//         Fetch the default MTLDevice to initialize a MetalKit buffer allocator with
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Failed to get the system's default Metal device!")
        }

        // Using the Model I/O framework to export the scan, so we're initialising an MDLAsset object,
        // which we can export to a file later, with a buffer allocator
        let allocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(bufferAllocator: allocator)

        // Fetch all ARMeshAncors
        let meshAnchors = frame.anchors.compactMap({ $0 as? ARMeshAnchor })

        // Convert the geometry of each ARMeshAnchor into a MDLMesh and add it to the MDLAsset
        for meshAncor in meshAnchors {
            // Some short handles, otherwise stuff will get pretty long in a few lines
            let geometry = meshAncor.geometry
            let vertices = geometry.vertices
            let faces = geometry.faces
            let verticesPointer = vertices.buffer.contents()
            let facesPointer = faces.buffer.contents()

            // Converting each vertex of the geometry from the local space of their ARMeshAnchor to world space
            for vertexIndex in 0..<vertices.count {

                // Extracting the current vertex with an extension method provided by Apple in Extensions.swift
                let vertex = geometry.vertex(at: UInt32(vertexIndex))

                // Building a transform matrix with only the vertex position
                // and apply the mesh anchors transform to convert into world space
                var vertexLocalTransform = matrix_identity_float4x4
                vertexLocalTransform.columns.3 = SIMD4<Float>(x: vertex.0, y: vertex.1, z: vertex.2, w: 1)
                let vertexWorldPosition = (meshAncor.transform * vertexLocalTransform).position

                // Writing the world space vertex back into it's position in the vertex buffer
                let vertexOffset = vertices.offset + vertices.stride * vertexIndex
                let componentStride = vertices.stride / 3
                verticesPointer.storeBytes(of: vertexWorldPosition.x, toByteOffset: vertexOffset, as: Float.self)
                verticesPointer.storeBytes(of: vertexWorldPosition.y, toByteOffset: vertexOffset + componentStride, as: Float.self)
                verticesPointer.storeBytes(of: vertexWorldPosition.z, toByteOffset: vertexOffset + (2 * componentStride), as: Float.self)
            }

            // Initializing MDLMeshBuffers with the content of the vertex and face MTLBuffers
            let byteCountVertices = vertices.count * vertices.stride
            let byteCountFaces = faces.count * faces.indexCountPerPrimitive * faces.bytesPerIndex
            let vertexBuffer = allocator.newBuffer(with: Data(bytesNoCopy: verticesPointer, count: byteCountVertices, deallocator: .none), type: .vertex)
            let indexBuffer = allocator.newBuffer(with: Data(bytesNoCopy: facesPointer, count: byteCountFaces, deallocator: .none), type: .index)

            // Creating a MDLSubMesh with the index buffer and a generic material
            let indexCount = faces.count * faces.indexCountPerPrimitive
            let material = MDLMaterial(name: "mat1", scatteringFunction: MDLPhysicallyPlausibleScatteringFunction())
            let submesh = MDLSubmesh(indexBuffer: indexBuffer, indexCount: indexCount, indexType: .uInt32, geometryType: .triangles, material: material)

            // Creating a MDLVertexDescriptor to describe the memory layout of the mesh
            let vertexFormat = MTKModelIOVertexFormatFromMetal(vertices.format)
            let vertexDescriptor = MDLVertexDescriptor()
            vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition, format: vertexFormat, offset: 0, bufferIndex: 0)
            vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: meshAncor.geometry.vertices.stride)

            // Finally creating the MDLMesh and adding it to the MDLAsset
            let mdlMesh = MDLMesh(vertexBuffer: vertexBuffer, vertexCount: meshAncor.geometry.vertices.count, descriptor: vertexDescriptor, submeshes: [submesh])

//            // print out the vertexes
//            let vbuf = mdlMesh.vertexBuffers[0]
//            let vbufmap = vbuf.map()
//            let layout = mdlMesh.vertexDescriptor.layouts.firstObject as! MDLVertexBufferLayout
//            let stride = layout.stride
//            assert(vbuf.length == mdlMesh.vertexCount*stride)
//            for i in 0..<mdlMesh.vertexCount {
//                let v = (vbufmap.bytes+i*stride).bindMemory(to: SIMD3<Float>.self, capacity: 1).pointee
//                if self.maxBB.x >= v.x && self.maxBB.y > v.y && self.maxBB.z > v.z && self.minBB.x <= v.x && self.minBB.y <= v.y && self.minBB.z <= v.z {
//                    vertexData.append(v)
//                    validVertexData.append(i)
//                }
//            }
//            let submeshObj = mdlMesh.submeshes?[0] as! MDLSubmesh
//            let indexCountObj = submeshObj.indexCount
//            let ibuf = submeshObj.indexBuffer
//            let ibufmap = ibuf.map()
//            let istride = 4
//            for i in 0..<indexCountObj {
//                let u = (ibufmap.bytes+i*istride).bindMemory(to: UInt32.self, capacity: 1).pointee
//                indexData.append(u)
//            }
//            for i in 0..<indexCountObj/3 {
//                if validVertexData.contains(Int(indexData[i*3])) && validVertexData.contains(Int(indexData[i*3+1])) && validVertexData.contains(Int(indexData[i*3+2])){
//                    validIndexData.append(indexData[i*3])
//                    validIndexData.append(indexData[i*3+1])
//                    validIndexData.append(indexData[i*3+2])
//                }
//            }
//            let mdlMeshObj = self.createObjectMesh(vertexData: vertexData, indexData: validIndexData)

            asset.add(mdlMesh)

//            assetObj.add(mdlMeshObj)
        }

        // Setting the path to export the OBJ file to
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let urlSCN = documentsPath.appendingPathComponent("scene_scan.obj")
//        let urlOBJ = documentsPath.appendingPathComponent("obj_scan.obj")

        // Exporting the OBJ file
        if MDLAsset.canExportFileExtension("obj") {
            do {
                try asset.export(to: urlSCN)
//                 Sharing the OBJ file with airdrop
                let activityControllerSCN = UIActivityViewController(activityItems: [urlSCN], applicationActivities: nil)
                activityControllerSCN.popoverPresentationController?.sourceView = sender
                self.present(activityControllerSCN, animated: true, completion: nil)
                
            } catch let error {
                fatalError(error.localizedDescription)
            }
        } else {
            self.statusText.text = "Could not write to file"
        }
        
        self.statusText.text = "Write to file successfully"
        
//        guard let device = MTLCreateSystemDefaultDevice() else {
//            print("Unable to create MTLDevice")
//            return
//        }
//
//        guard let meshAnchors = arView.session.currentFrame?.anchors.compactMap({ $0 as? ARMeshAnchor }) else { return }
//
//        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0];
//        let filename = directory.appendingPathComponent("scene_scan.obj");
//
//        do {
//            try meshAnchors.save(to: filename, device: device)
//            let activityControllerSCN = UIActivityViewController(activityItems: [filename], applicationActivities: nil)
//            activityControllerSCN.popoverPresentationController?.sourceView = sender
//            self.present(activityControllerSCN, animated: true, completion: nil)
//        } catch {
//            print("Unable to save mesh")
//        }
    }
  
    
    @IBAction func togglePlaneDetectionButtonPressed(_ button: UIButton) {
        guard let configuration = arView.session.configuration as? ARWorldTrackingConfiguration else {
            return
        }
        if configuration.planeDetection == [] {
            configuration.planeDetection = [.horizontal, .vertical]
            button.setTitle("Stop Plane Detection", for: [])
        } else {
            configuration.planeDetection = []
            button.setTitle("Start Plane Detection", for: [])
        }
        arView.session.run(configuration)
    }
    
    func nearbyFaceWithClassification(to location: SIMD3<Float>, completionBlock: @escaping (SIMD3<Float>?, ARMeshClassification) -> Void) {
        guard let frame = arView.session.currentFrame else {
            completionBlock(nil, .none)
            return
        }
    
        var meshAnchors = frame.anchors.compactMap({ $0 as? ARMeshAnchor })
        
        // Sort the mesh anchors by distance to the given location and filter out
        // any anchors that are too far away (4 meters is a safe upper limit).
        let cutoffDistance: Float = 4.0
        meshAnchors.removeAll { distance($0.transform.position, location) > cutoffDistance }
        meshAnchors.sort { distance($0.transform.position, location) < distance($1.transform.position, location) }

        // Perform the search asynchronously in order not to stall rendering.
        DispatchQueue.global().async {
            for anchor in meshAnchors {
                for index in 0..<anchor.geometry.faces.count {
                    // Get the center of the face so that we can compare it to the given location.
                    let geometricCenterOfFace = anchor.geometry.centerOf(faceWithIndex: index)
                    
                    // Convert the face's center to world coordinates.
                    var centerLocalTransform = matrix_identity_float4x4
                    centerLocalTransform.columns.3 = SIMD4<Float>(geometricCenterOfFace.0, geometricCenterOfFace.1, geometricCenterOfFace.2, 1)
                    let centerWorldPosition = (anchor.transform * centerLocalTransform).position
                     
                    // We're interested in a classification that is sufficiently close to the given location––within 5 cm.
                    let distanceToFace = distance(centerWorldPosition, location)
                    if distanceToFace <= 0.05 {
                        // Get the semantic classification of the face and finish the search.
                        let classification: ARMeshClassification = anchor.geometry.classificationOf(faceWithIndex: index)
                        completionBlock(centerWorldPosition, classification)
                        return
                    }
                }
            }
            
            // Let the completion block know that no result was found.
            completionBlock(nil, .none)
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
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
                self.resetButtonPressed(self)
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
        
    func model(for classification: ARMeshClassification) -> ModelEntity {
        // Return cached model if available
        if let model = modelsForClassification[classification] {
            model.transform = .identity
            return model.clone(recursive: true)
        }
        
        // Generate 3D text for the classification
        let lineHeight: CGFloat = 0.05
        let font = MeshResource.Font.systemFont(ofSize: lineHeight)
        let textMesh = MeshResource.generateText(classification.description, extrusionDepth: Float(lineHeight * 0.1), font: font)
        let textMaterial = SimpleMaterial(color: classification.color, isMetallic: true)
        let model = ModelEntity(mesh: textMesh, materials: [textMaterial])
        // Move text geometry to the left so that its local origin is in the center
        model.position.x -= model.visualBounds(relativeTo: nil).extents.x / 2
        // Add model to cache
        modelsForClassification[classification] = model
        return model
    }
    
    func sphere(radius: Float, color: UIColor) -> ModelEntity {
        let sphere = ModelEntity(mesh: .generateSphere(radius: radius), materials: [SimpleMaterial(color: color, isMetallic: false)])
        // Move sphere up by half its diameter so that it does not intersect with the mesh
        sphere.position.y = radius
        return sphere
    }
    
}

//extension ARMeshGeometry {
//    func toMDLMesh(device: MTLDevice) -> MDLMesh {
//        let allocator = MTKMeshBufferAllocator(device: device);
//
//        let data = Data.init(bytes: vertices.buffer.contents(), count: vertices.stride * vertices.count);
//        let vertexBuffer = allocator.newBuffer(with: data, type: .vertex);
//
//        let indexData = Data.init(bytes: faces.buffer.contents(), count: faces.bytesPerIndex * faces.count * faces.indexCountPerPrimitive);
//        let indexBuffer = allocator.newBuffer(with: indexData, type: .index);
//        print(faces.count)
//        print(faces.bytesPerIndex) // 4
//        let submesh = MDLSubmesh(indexBuffer: indexBuffer,
//                                 indexCount: faces.count * faces.indexCountPerPrimitive,
//                                 indexType: .uInt32,
//                                 geometryType: .triangles,
//                                 material: nil);
//
//        let vertexDescriptor = MDLVertexDescriptor();
//        vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
//                                                            format: .float3,
//                                                            offset: 0,
//                                                            bufferIndex: 0);
//        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: vertices.stride);
//        print("index count", submesh.indexCount) // 6054
//        print(vertices.count) // 1286
//        print(vertices.stride) // 12
//
//        return MDLMesh(vertexBuffer: vertexBuffer,
//                       vertexCount: vertices.count,
//                       descriptor: vertexDescriptor,
//                       submeshes: [submesh]);
//    }
//}

    
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */



//extension simd_float4x4 {
//    var position: SIMD3<Float> {
//        get {
//            return SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
//        }
//        set {
//            columns.3 = [newValue.x, newValue.y, newValue.z, columns.3.w]
//        }
//    }
//}

//extension ARMeshGeometry {
//    func toMDLMesh(device: MTLDevice, transform: simd_float4x4) -> MDLMesh {
//        let allocator = MTKMeshBufferAllocator(device: device)
//
//        let data = Data.init(bytes: transformedVertexBuffer(transform), count: vertices.stride * vertices.count)
//        let vertexBuffer = allocator.newBuffer(with: data, type: .vertex)
//
//        let indexData = Data.init(bytes: faces.buffer.contents(), count: faces.bytesPerIndex * faces.count * faces.indexCountPerPrimitive)
//        let indexBuffer = allocator.newBuffer(with: indexData, type: .index)
//
//        let submesh = MDLSubmesh(indexBuffer: indexBuffer,
//                                 indexCount: faces.count * faces.indexCountPerPrimitive,
//                                 indexType: .uInt32,
//                                 geometryType: .triangles,
//                                 material: nil)
//
//        let vertexDescriptor = MDLVertexDescriptor()
//        vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
//                                                            format: .float3,
//                                                            offset: 0,
//                                                            bufferIndex: 0);
//        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: vertices.stride)
//
//        return MDLMesh(vertexBuffer: vertexBuffer,
//                       vertexCount: vertices.count,
//                       descriptor: vertexDescriptor,
//                       submeshes: [submesh])
//    }
//
//    func transformedVertexBuffer(_ transform: simd_float4x4) -> [Float] {
//        var result = [Float]()
//        for index in 0..<vertices.count {
//            let vertexPointer = vertices.buffer.contents().advanced(by: vertices.offset + vertices.stride * index)
//            let vertex = vertexPointer.assumingMemoryBound(to: (Float, Float, Float).self).pointee
//            var vertextTransform = matrix_identity_float4x4
//            vertextTransform.columns.3 = SIMD4<Float>(vertex.0, vertex.1, vertex.2, 1)
//            let position = (transform * vertextTransform).position
//            result.append(position.x)
//            result.append(position.y)
//            result.append(position.z)
//        }
//        return result
//    }
//}
//
//extension Array where Element == ARMeshAnchor {
//    func save(to fileURL: URL, device: MTLDevice) throws {
//        let asset = MDLAsset()
//        self.forEach {
//            let mesh = $0.geometry.toMDLMesh(device: device, transform: $0.transform)
//            asset.add(mesh)
//        }
//        try asset.export(to: fileURL)
//    }
//}
