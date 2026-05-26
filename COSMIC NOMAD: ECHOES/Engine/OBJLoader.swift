//
//  OBJLoader.swift
//  COSMIC NOMAD: ECHOES
//
//  Loads Wavefront .OBJ models and produces Metal vertex/index buffers
//  compatible with the EntityVertex format used by the entity pipeline.
//

import Metal
import simd

/// Result of loading an OBJ file — ready-to-render Metal buffers
struct OBJMesh {
    let vertexBuffer: MTLBuffer
    let indexBuffer: MTLBuffer
    let indexCount: Int
    let vertexCount: Int
    /// Axis-aligned bounding box for scaling/centering
    let boundingBoxMin: SIMD3<Float>
    let boundingBoxMax: SIMD3<Float>
}

@MainActor
enum OBJLoader {
    
    /// Load an OBJ file from the app bundle and return Metal buffers
    /// - Parameters:
    ///   - filename: Name of the .obj file (without extension)
    ///   - device: The MTLDevice to create buffers on
    /// - Returns: An OBJMesh with vertex and index buffers, or nil on failure
    static func load(filename: String, device: MTLDevice) -> OBJMesh? {
        // Try to find the file in the main bundle
        guard let url = Bundle.main.url(forResource: filename, withExtension: "obj") else {
            print("⚠️ OBJLoader: Could not find '\(filename).obj' in bundle")
            return nil
        }
        
        return load(url: url, device: device)
    }
    
    /// Load an OBJ file from a URL and return Metal buffers
    static func load(url: URL, device: MTLDevice) -> OBJMesh? {
        guard let data = try? String(contentsOf: url, encoding: .utf8) else {
            print("⚠️ OBJLoader: Could not read file at \(url.path)")
            return nil
        }
        
        return parse(objString: data, device: device)
    }
    
    /// Parse OBJ text content into Metal buffers
    static func parse(objString: String, device: MTLDevice) -> OBJMesh? {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var texCoords: [SIMD2<Float>] = []
        
        // Unique vertex map: "posIdx/texIdx/normIdx" -> vertex index
        var vertexMap: [String: UInt32] = [:]
        var vertices: [EntityVertex] = []
        var indices: [UInt32] = []
        
        let lines = objString.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            
            let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard !parts.isEmpty else { continue }
            
            let keyword = String(parts[0])
            
            switch keyword {
            case "v":
                // Vertex position: v x y z
                guard parts.count >= 4,
                      let x = Float(parts[1]),
                      let y = Float(parts[2]),
                      let z = Float(parts[3]) else { continue }
                positions.append(SIMD3<Float>(x, y, z))
                
            case "vn":
                // Vertex normal: vn x y z
                guard parts.count >= 4,
                      let x = Float(parts[1]),
                      let y = Float(parts[2]),
                      let z = Float(parts[3]) else { continue }
                normals.append(SIMD3<Float>(x, y, z))
                
            case "vt":
                // Texture coordinate: vt u v
                guard parts.count >= 3,
                      let u = Float(parts[1]),
                      let v = Float(parts[2]) else { continue }
                texCoords.append(SIMD2<Float>(u, v))
                
            case "f":
                // Face: f v1/vt1/vn1 v2/vt2/vn2 v3/vt3/vn3 ...
                // Supports: f v, f v/vt, f v/vt/vn, f v//vn
                guard parts.count >= 4 else { continue }
                
                var faceIndices: [UInt32] = []
                
                for i in 1..<parts.count {
                    let vertStr = String(parts[i])
                    
                    if let existingIndex = vertexMap[vertStr] {
                        faceIndices.append(existingIndex)
                        continue
                    }
                    
                    let components = vertStr.split(separator: "/", omittingEmptySubsequences: false)
                    
                    var pos = SIMD3<Float>.zero
                    var norm = SIMD3<Float>(0, 1, 0)
                    var tex = SIMD2<Float>.zero
                    
                    // Position index (1-based)
                    if let posIdx = Int(components[0]), posIdx > 0, posIdx <= positions.count {
                        pos = positions[posIdx - 1]
                    }
                    
                    // Texture coordinate index
                    if components.count > 1, let texIdx = Int(components[1]), texIdx > 0, texIdx <= texCoords.count {
                        tex = texCoords[texIdx - 1]
                    }
                    
                    // Normal index
                    if components.count > 2, let normIdx = Int(components[2]), normIdx > 0, normIdx <= normals.count {
                        norm = normals[normIdx - 1]
                    }
                    
                    let vertex = EntityVertex(position: pos, normal: norm, texCoord: tex)
                    let newIndex = UInt32(vertices.count)
                    vertices.append(vertex)
                    vertexMap[vertStr] = newIndex
                    faceIndices.append(newIndex)
                }
                
                // Triangulate the face (fan triangulation for convex polygons)
                for i in 2..<faceIndices.count {
                    indices.append(faceIndices[0])
                    indices.append(faceIndices[i - 1])
                    indices.append(faceIndices[i])
                }
                
            default:
                // Ignore: mtllib, usemtl, o, g, s, etc.
                break
            }
        }
        
        guard !vertices.isEmpty, !indices.isEmpty else {
            print("⚠️ OBJLoader: No geometry found in OBJ file")
            return nil
        }
        
        // If no normals were provided in the file, compute face normals
        if normals.isEmpty {
            computeFlatNormals(vertices: &vertices, indices: indices)
        }
        
        // Compute bounding box
        var bMin = SIMD3<Float>(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
        var bMax = SIMD3<Float>(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)
        
        for v in vertices {
            bMin = min(bMin, v.position)
            bMax = max(bMax, v.position)
        }
        
        // Create Metal buffers
        guard let vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<EntityVertex>.stride * vertices.count,
            options: .storageModeShared
        ) else {
            print("⚠️ OBJLoader: Failed to create vertex buffer")
            return nil
        }
        vertexBuffer.label = "OBJ Vertex Buffer"
        
        guard let indexBuffer = device.makeBuffer(
            bytes: indices,
            length: MemoryLayout<UInt32>.stride * indices.count,
            options: .storageModeShared
        ) else {
            print("⚠️ OBJLoader: Failed to create index buffer")
            return nil
        }
        indexBuffer.label = "OBJ Index Buffer"
        
        print("✅ OBJLoader: Loaded \(vertices.count) vertices, \(indices.count / 3) triangles")
        print("   Bounds: min=\(bMin), max=\(bMax)")
        
        return OBJMesh(
            vertexBuffer: vertexBuffer,
            indexBuffer: indexBuffer,
            indexCount: indices.count,
            vertexCount: vertices.count,
            boundingBoxMin: bMin,
            boundingBoxMax: bMax
        )
    }
    
    /// Compute flat normals when the OBJ doesn't provide them
    private static func computeFlatNormals(vertices: inout [EntityVertex], indices: [UInt32]) {
        // Accumulate face normals per vertex
        var normalAccum = [SIMD3<Float>](repeating: .zero, count: vertices.count)
        
        for i in stride(from: 0, to: indices.count, by: 3) {
            let i0 = Int(indices[i])
            let i1 = Int(indices[i + 1])
            let i2 = Int(indices[i + 2])
            
            let v0 = vertices[i0].position
            let v1 = vertices[i1].position
            let v2 = vertices[i2].position
            
            let edge1 = v1 - v0
            let edge2 = v2 - v0
            let faceNormal = cross(edge1, edge2)
            
            normalAccum[i0] += faceNormal
            normalAccum[i1] += faceNormal
            normalAccum[i2] += faceNormal
        }
        
        for i in 0..<vertices.count {
            let n = normalAccum[i]
            vertices[i].normal = length(n) > 0 ? normalize(n) : SIMD3<Float>(0, 1, 0)
        }
    }
}
